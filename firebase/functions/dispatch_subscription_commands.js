"use strict";

const crypto = require("node:crypto");
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
const {
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  automaticTaxEnabled,
  taxCollectionStatus,
} = require("./pending_tax_policy");

const CHECKOUT_IDEMPOTENCY_WINDOW_MS = 5 * 60 * 1000;
const CHECKOUT_SESSION_LIFETIME_MS = 30 * 60 * 1000;

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function selectedPlan(value) {
  const plan = String(value || "monthly").trim().toLowerCase();
  if (!new Set(["monthly", "yearly"]).has(plan)) {
    throw new HttpsError("invalid-argument", "The Dispatch subscription plan is invalid.");
  }
  return plan;
}

function subscriptionReady(readiness) {
  const taxPrepared = readiness.stripeTaxReady === true ||
    readiness.stripeTaxRegistrationPending === true;
  return readiness.stripeSubscriptionsEnabled === true &&
    readiness.stripeMode === "production" &&
    readiness.stripeWebhookVerified === true &&
    readiness.stripeReconciliationReady === true &&
    taxPrepared;
}

function requireSubscriptionReady(readiness) {
  if (!subscriptionReady(readiness)) {
    throw new HttpsError(
        "failed-precondition",
        "Dispatch subscription checkout is not enabled yet.",
    );
  }
}

function couponFromEntitlement(entitlement) {
  if (!entitlement || entitlement.active !== true) return null;
  const type = String(entitlement.type || "");
  if (type === "dispatch_1_year_free") {
    return stripeMarketplaceConfig.coupons.oneYearFree;
  }
  if (type === "dispatch_5_years_free") {
    return stripeMarketplaceConfig.coupons.fiveYearsFree;
  }
  return null;
}

function subscriptionPlanCatalog() {
  const products = stripeMarketplaceConfig.products;
  const plan = (product) => Object.freeze({
    currency: String(product.currency),
    amountMinor: Number(product.unitAmountMinor),
    amount: Number((Number(product.unitAmountMinor) / 100).toFixed(2)),
    interval: String(product.billingInterval),
  });
  return Object.freeze({
    monthly: plan(products.dispatchMonthlyCad),
    yearly: plan(products.dispatchYearlyCad),
  });
}

function checkoutIdempotencyKey(uid, plan, nowMs = Date.now()) {
  const bucket = Math.floor(Number(nowMs) / CHECKOUT_IDEMPOTENCY_WINDOW_MS);
  return `pipebuyer-dispatch-${uid}-${plan}-${bucket}`;
}

function millisFromTimestamp(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function checkoutLockActive(lock, nowMs = Date.now()) {
  if (!lock) return false;
  const status = String(lock.status || "");
  const expiresAt = millisFromTimestamp(lock.expiresAt);
  return new Set(["creating", "open", "processing"]).has(status) &&
    expiresAt > Number(nowMs);
}

function createDispatchSubscriptionCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  const getDispatchSubscriptionCatalog = async (request) => {
    try {
      requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "dispatch");
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: readinessData.stripeSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
      };
      return {
        plans: subscriptionPlanCatalog(),
        checkoutAvailable: subscriptionReady(readiness),
        taxCollectionStatus: taxCollectionStatus(readiness),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription catalog failed", error);
      throw new HttpsError("internal", "Dispatch subscription pricing could not be loaded.");
    }
  };

  const createDispatchSubscriptionCheckout = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "dispatch");
      requirePhase1Feature(flags, "paidFeatures");
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness").get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: readinessData.stripeSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        checkoutSuccessUrl: String(readinessData.checkoutSuccessUrl || ""),
        checkoutCancelUrl: String(readinessData.checkoutCancelUrl || ""),
      };
      requireSubscriptionReady(readiness);
      const collectionStatus = taxCollectionStatus(readiness);
      const plan = selectedPlan(request.data && request.data.plan);
      const priceId = plan === "monthly" ?
        stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId :
        stripeMarketplaceConfig.products.dispatchYearlyCad.priceId;
      const successUrl = safeConfiguredUrl(
          readiness.checkoutSuccessUrl,
          "Stripe Checkout success URL",
      );
      const cancelUrl = safeConfiguredUrl(
          readiness.checkoutCancelUrl,
          "Stripe Checkout cancel URL",
      );

      const nowMs = Date.now();
      const checkoutExpiresAtMs = nowMs + CHECKOUT_SESSION_LIFETIME_MS;
      const requestToken = crypto.randomBytes(16).toString("hex");
      const userRef = db.collection("users").doc(uid);
      const lockRef = db.collection("dispatch_subscription_checkout_locks").doc(uid);
      await db.runTransaction(async (transaction) => {
        const [userSnapshot, lockSnapshot] = await Promise.all([
          transaction.get(userRef),
          transaction.get(lockRef),
        ]);
        const user = userSnapshot.exists ? userSnapshot.data() : {};
        if (user.dispatchSubscriptionActive === true) {
          throw new HttpsError(
              "already-exists",
              "Your existing Dispatch subscription must be resolved before starting another checkout.",
          );
        }
        if (lockSnapshot.exists && checkoutLockActive(lockSnapshot.data(), nowMs)) {
          throw new HttpsError(
              "already-exists",
              "A secure Dispatch checkout is already open for this account.",
          );
        }
        transaction.set(lockRef, {
          uid,
          plan,
          status: "creating",
          requestToken,
          expiresAt: Timestamp.fromMillis(checkoutExpiresAtMs),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      const [entitlementSnapshot, relationshipSnapshot] = await Promise.all([
        db.collection("promotion_entitlements").doc(uid).get(),
        db.collection("affiliate_relationships").doc(uid).get(),
      ]);
      const entitlement = entitlementSnapshot.exists ? entitlementSnapshot.data() : null;
      const couponId = couponFromEntitlement(entitlement);
      const referrerUid = relationshipSnapshot.exists ?
        String(relationshipSnapshot.data().referrerUid || "").trim() : "";
      const checkout = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/checkout/sessions",
        idempotencyKey: checkoutIdempotencyKey(uid, plan, nowMs),
        fields: {
          mode: "subscription",
          success_url: successUrl,
          cancel_url: cancelUrl,
          expires_at: Math.floor(checkoutExpiresAtMs / 1000),
          client_reference_id: uid,
          billing_address_collection: "required",
          allow_promotion_codes: "false",
          "automatic_tax[enabled]": automaticTaxEnabled(readiness) ? "true" : "false",
          "line_items[0][price]": priceId,
          "line_items[0][quantity]": 1,
          ...(couponId ? {"discounts[0][coupon]": couponId} : {}),
          "metadata[billingType]": "dispatch_subscription",
          "metadata[pipeBuyerUid]": uid,
          "metadata[dispatchPlan]": plan,
          "metadata[taxCollectionStatus]": collectionStatus,
          ...(couponId ? {"metadata[promotionCouponId]": couponId} : {}),
          ...(referrerUid ? {"metadata[affiliateReferrerUid]": referrerUid} : {}),
          "subscription_data[metadata][billingType]": "dispatch_subscription",
          "subscription_data[metadata][pipeBuyerUid]": uid,
          "subscription_data[metadata][dispatchPlan]": plan,
          "subscription_data[metadata][taxCollectionStatus]": collectionStatus,
          ...(referrerUid ? {
            "subscription_data[metadata][affiliateReferrerUid]": referrerUid,
          } : {}),
        },
      });
      const sessionId = String(checkout.id || "");
      const checkoutUrl = String(checkout.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return a valid subscription checkout.");
      }
      const sessionRef = db.collection("subscription_checkout_sessions").doc(sessionId);
      await db.runTransaction(async (transaction) => {
        const lockSnapshot = await transaction.get(lockRef);
        if (!lockSnapshot.exists ||
            String(lockSnapshot.data().requestToken || "") !== requestToken) {
          throw new HttpsError(
              "aborted",
              "The Dispatch checkout lock changed before the secure session was recorded.",
          );
        }
        transaction.set(sessionRef, {
          uid,
          plan,
          priceId,
          couponId: couponId || null,
          referrerUid: referrerUid || null,
          taxCollectionStatus: collectionStatus,
          taxExposureReviewRequired: collectionStatus === "registration_pending",
          automaticTaxEnabled: automaticTaxEnabled(readiness),
          status: "created",
          expiresAt: Timestamp.fromMillis(checkoutExpiresAtMs),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(lockRef, {
          status: "open",
          sessionId,
          checkoutUrl,
          expiresAt: Timestamp.fromMillis(checkoutExpiresAtMs),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      return {
        checkoutSessionId: sessionId,
        checkoutUrl,
        plan,
        promotionApplied: Boolean(couponId),
        taxCollectionStatus: collectionStatus,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription checkout failed", error);
      throw new HttpsError("internal", "Dispatch subscription checkout could not be started.");
    }
  };

  return {
    createDispatchSubscriptionCheckout,
    getDispatchSubscriptionCatalog,
  };
}

module.exports = {
  CHECKOUT_IDEMPOTENCY_WINDOW_MS,
  CHECKOUT_SESSION_LIFETIME_MS,
  checkoutIdempotencyKey,
  checkoutLockActive,
  couponFromEntitlement,
  createDispatchSubscriptionCommands,
  millisFromTimestamp,
  requireSubscriptionReady,
  selectedPlan,
  subscriptionPlanCatalog,
  subscriptionReady,
};
