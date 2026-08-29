"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {
  loadProviderReadiness,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {taxBillingPrepared} = require("./pending_tax_policy");

const MAX_PROMOTION_CODE_LENGTH = 64;

function normalizePromotionCode(value, {required = false} = {}) {
  const code = String(value || "").trim();
  if (!code) {
    if (required) {
      throw new HttpsError("invalid-argument", "Enter a promo code first.");
    }
    return "";
  }
  if (code.length > MAX_PROMOTION_CODE_LENGTH || !/^[A-Za-z0-9-]+$/.test(code)) {
    throw new HttpsError(
        "invalid-argument",
        "That promo code format is not valid.",
    );
  }
  return code;
}

function couponFromPromotionCode(promotionCode) {
  const promotion = promotionCode && promotionCode.promotion || {};
  const expanded = promotion && promotion.coupon;
  if (expanded && typeof expanded === "object") return expanded;
  if (promotionCode && promotionCode.coupon &&
      typeof promotionCode.coupon === "object") {
    return promotionCode.coupon;
  }
  return null;
}

function promotionCodeSummary(promotionCode) {
  const coupon = couponFromPromotionCode(promotionCode);
  if (!coupon) return "Promo code accepted";

  let discount = "Discount";
  const percentOff = Number(coupon.percent_off);
  const amountOff = Number(coupon.amount_off);
  if (Number.isFinite(percentOff) && percentOff > 0) {
    discount = `${percentOff % 1 === 0 ? percentOff.toFixed(0) : percentOff}% off`;
  } else if (Number.isSafeInteger(amountOff) && amountOff > 0) {
    const currency = String(coupon.currency || "").toUpperCase();
    discount = `${currency ? `${currency} ` : ""}${(amountOff / 100).toFixed(2)} off`;
  }

  const duration = String(coupon.duration || "");
  const durationMonths = Number(coupon.duration_in_months);
  if (duration === "repeating" && Number.isSafeInteger(durationMonths) &&
      durationMonths > 0) {
    return `${discount} for ${durationMonths} month${durationMonths === 1 ? "" : "s"}`;
  }
  if (duration === "forever") return `${discount} while the subscription remains eligible`;
  if (duration === "once") return `${discount} on the next eligible invoice`;
  return discount;
}

function promotionCodeTargetsDispatchProduct(promotionCode) {
  const coupon = couponFromPromotionCode(promotionCode);
  const products = coupon && coupon.applies_to && coupon.applies_to.products;
  if (!Array.isArray(products) || products.length === 0) return true;
  return products.includes(stripeMarketplaceConfig.products.dispatchMonthlyCad.productId);
}

function selectPromotionCode(data, requestedCode, stripeCustomerId = "") {
  const normalized = String(requestedCode || "").trim().toLowerCase();
  const customerId = String(stripeCustomerId || "").trim();
  const matches = (Array.isArray(data) ? data : []).filter((entry) =>
    entry &&
    entry.active === true &&
    String(entry.code || "").trim().toLowerCase() === normalized,
  );
  const exactCustomer = customerId ?
    matches.find((entry) => String(entry.customer || "") === customerId) : null;
  if (exactCustomer) return exactCustomer;
  return matches.find((entry) => !String(entry.customer || "").trim()) || null;
}

async function resolveDispatchPromotionCode({
  secretKey,
  code,
  stripeCustomerId = "",
  existingSubscriber = false,
}) {
  const normalizedCode = normalizePromotionCode(code, {required: true});
  const path = "/v1/promotion_codes" +
    `?active=true&limit=10&code=${encodeURIComponent(normalizedCode)}` +
    "&expand%5B%5D=data.promotion.coupon";
  const list = await stripeFormRequest({secretKey, path, method: "GET"});
  const promotionCode = selectPromotionCode(
      list && list.data,
      normalizedCode,
      stripeCustomerId,
  );
  if (!promotionCode) {
    throw new HttpsError(
        "invalid-argument",
        "That promo code is not active or is not available for this account.",
    );
  }
  if (!String(promotionCode.id || "").startsWith("promo_")) {
    throw new HttpsError("failed-precondition", "Stripe returned an invalid promo code.");
  }
  const coupon = couponFromPromotionCode(promotionCode);
  if (coupon && coupon.valid === false) {
    throw new HttpsError("failed-precondition", "That promo code has expired.");
  }
  if (!promotionCodeTargetsDispatchProduct(promotionCode)) {
    throw new HttpsError(
        "failed-precondition",
        "That promo code is not valid for Dispatch membership.",
    );
  }
  if (existingSubscriber &&
      promotionCode.restrictions &&
      promotionCode.restrictions.first_time_transaction === true) {
    throw new HttpsError(
        "failed-precondition",
        "This promo code is for new customers and must be used before the first purchase.",
    );
  }
  return {
    id: String(promotionCode.id),
    code: String(promotionCode.code || normalizedCode),
    couponId: String(coupon && coupon.id || ""),
    summary: promotionCodeSummary(promotionCode),
    firstTimeTransaction: Boolean(
        promotionCode.restrictions &&
        promotionCode.restrictions.first_time_transaction === true,
    ),
  };
}

function requirePromotionUpdateReady(readiness) {
  if (!readiness ||
      readiness.stripeMode !== "production" ||
      readiness.stripeSubscriptionsEnabled !== true ||
      readiness.stripeWebhookVerified !== true ||
      readiness.stripeReconciliationReady !== true ||
      !taxBillingPrepared(readiness)) {
    throw new HttpsError(
        "failed-precondition",
        "Dispatch promotion updates are temporarily unavailable.",
    );
  }
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function activeDiscounts(subscription) {
  return Array.isArray(subscription && subscription.discounts) ?
    subscription.discounts.filter(Boolean) : [];
}

function discountPromotionCodeId(discount) {
  if (!discount || typeof discount !== "object") return "";
  const value = discount.promotion_code;
  if (typeof value === "string") return value;
  if (value && typeof value === "object") return String(value.id || "");
  return "";
}

function createDispatchSubscriptionPromotionCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const applyDispatchSubscriptionPromotionCode = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "dispatch");
      requirePhase1Feature(flags, "paidFeatures");

      const [readinessSnapshot, providerSnapshot, membershipSnapshot] =
        await Promise.all([
          db.collection("platform_configuration")
              .doc("payment_provider_readiness").get(),
          db.collection("dispatch_subscription_provider_state")
              .doc(identity.uid).get(),
          db.collection("dispatch_memberships").doc(identity.uid).get(),
        ]);
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: readinessData.stripeSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved:
          readinessData.stripeTaxPendingBillingApproved === true,
      };
      requirePromotionUpdateReady(readiness);

      const membership = membershipSnapshot.exists ? membershipSnapshot.data() : null;
      if (!membership || membership.active !== true ||
          timestampMillis(membership.currentPeriodEnd) <= Date.now()) {
        throw new HttpsError(
            "failed-precondition",
            "An active Dispatch membership is required before applying a post-purchase promo code.",
        );
      }
      if (String(membership.plan || "").trim().toLowerCase() !== "monthly") {
        throw new HttpsError(
            "failed-precondition",
            "Post-purchase promo codes are currently supported for monthly Dispatch memberships only.",
        );
      }

      const providerState = providerSnapshot.exists ? providerSnapshot.data() : null;
      if (!providerState || providerState.ownerUid !== identity.uid ||
          !String(providerState.stripeCustomerId || "").startsWith("cus_") ||
          !String(providerState.subscriptionId || "").startsWith("sub_")) {
        throw new HttpsError(
            "failed-precondition",
            "No Stripe Dispatch subscription is available to update.",
        );
      }

      const secretKey = stripeSecretKey.value();
      const promotion = await resolveDispatchPromotionCode({
        secretKey,
        code: request.data && request.data.promotionCode,
        stripeCustomerId: String(providerState.stripeCustomerId),
        existingSubscriber: true,
      });

      const subscriptionId = String(providerState.subscriptionId);
      const subscription = await stripeFormRequest({
        secretKey,
        path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}` +
          "?expand%5B%5D=discounts",
        method: "GET",
      });
      if (String(subscription.id || "") !== subscriptionId ||
          String(subscription.customer || "") !== String(providerState.stripeCustomerId)) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe subscription ownership could not be verified.",
        );
      }

      const discounts = activeDiscounts(subscription);
      if (discounts.some((discount) =>
        discountPromotionCodeId(discount) === promotion.id)) {
        return {
          applied: true,
          alreadyApplied: true,
          promotionCode: promotion.code,
          promotionSummary: promotion.summary,
          effective: "next_invoice",
        };
      }
      if (discounts.length > 0) {
        throw new HttpsError(
            "failed-precondition",
            "A discount is already active on this subscription. Pipe Buyer will not stack or replace it automatically.",
        );
      }

      let updated;
      try {
        updated = await stripeFormRequest({
          secretKey,
          path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
          idempotencyKey:
            `pipebuyer-dispatch-promo-${identity.uid}-${promotion.id}`,
          fields: {
            "discounts[0][promotion_code]": promotion.id,
          },
        });
      } catch (error) {
        if (error instanceof HttpsError) {
          throw new HttpsError(
              error.code,
              "Stripe could not apply that promo code to this subscription. Check the code eligibility and try again.",
          );
        }
        throw error;
      }
      if (String(updated.id || "") !== subscriptionId) {
        throw new HttpsError(
            "internal",
            "Stripe did not confirm the subscription promotion update.",
        );
      }

      await db.collection("dispatch_subscription_promotion_state")
          .doc(identity.uid).set({
            ownerUid: identity.uid,
            subscriptionId,
            promotionCodeId: promotion.id,
            couponId: promotion.couponId || null,
            promotionSummary: promotion.summary,
            status: "applied",
            source: "user_entered_post_purchase",
            appliedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});

      return {
        applied: true,
        alreadyApplied: false,
        promotionCode: promotion.code,
        promotionSummary: promotion.summary,
        effective: "next_invoice",
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription promotion update failed", {
        code: String(error && error.code || "").slice(0, 80),
      });
      throw new HttpsError(
          "internal",
          "Dispatch promo code could not be applied.",
      );
    }
  };

  return {applyDispatchSubscriptionPromotionCode};
}

module.exports = {
  MAX_PROMOTION_CODE_LENGTH,
  activeDiscounts,
  couponFromPromotionCode,
  createDispatchSubscriptionPromotionCommands,
  discountPromotionCodeId,
  normalizePromotionCode,
  promotionCodeSummary,
  promotionCodeTargetsDispatchProduct,
  requirePromotionUpdateReady,
  resolveDispatchPromotionCode,
  selectPromotionCode,
  timestampMillis,
};
