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
const {
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  resolveDispatchPromotionCode,
} = require("./dispatch_subscription_promotions");
const {
  automaticTaxEnabled,
  taxBillingPrepared,
  taxCollectionStatus,
} = require("./pending_tax_policy");

const CHECKOUT_CREATION_LEASE_MS = 2 * 60 * 1000;
const CHECKOUT_FALLBACK_EXPIRY_MS = 24 * 60 * 60 * 1000;
const CHECKOUT_CONFIGURATION_VERSION = 3;

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function selectedPlan(value) {
  const plan = String(value || "").trim().toLowerCase();
  if (!new Set(["monthly", "yearly"]).has(plan)) {
    throw new HttpsError("invalid-argument", "The Dispatch subscription plan is invalid.");
  }
  return plan;
}

function requireSubscriptionReady(readiness) {
  if (!readiness.stripeSubscriptionsEnabled ||
      readiness.stripeMode !== "production" ||
      readiness.stripeWebhookVerified !== true ||
      readiness.stripeReconciliationReady !== true ||
      !taxBillingPrepared(readiness)) {
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

function promotionCodeEntryAllowed(plan, couponId) {
  return plan === "monthly" && !String(couponId || "").trim();
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function dispatchMembershipIsCurrent(membership, nowMillis = Date.now()) {
  if (!membership || membership.active !== true) return false;
  return timestampMillis(membership.currentPeriodEnd) > nowMillis;
}

function reusableCheckoutState(
    state,
    plan,
    nowMillis = Date.now(),
    promotionCodeId = "",
) {
  if (!state || state.plan !== plan) return false;
  if (state.checkoutConfigurationVersion !== CHECKOUT_CONFIGURATION_VERSION) {
    return false;
  }
  if (String(state.promotionCodeId || "") !== String(promotionCodeId || "")) {
    return false;
  }
  if (state.status !== "created") return false;
  if (timestampMillis(state.expiresAt) <= nowMillis) return false;
  return String(state.checkoutSessionId || "").startsWith("cs_") &&
    String(state.checkoutUrl || "").startsWith("https://");
}

function createdCheckoutBlocksPlanChange(state, plan, nowMillis = Date.now()) {
  if (!state || state.status !== "created") return false;
  if (timestampMillis(state.expiresAt) <= nowMillis) return false;
  return Boolean(state.plan && state.plan !== plan);
}

function checkoutAttemptKey(uid, attemptNumber) {
  return `pipebuyer-dispatch-${uid}-attempt-${attemptNumber}`;
}

function createDispatchSubscriptionCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

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
        stripeTaxPendingBillingApproved:
          readinessData.stripeTaxPendingBillingApproved === true,
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
      const [entitlementSnapshot, relationshipSnapshot, providerSnapshot] =
        await Promise.all([
          db.collection("promotion_entitlements").doc(uid).get(),
          db.collection("affiliate_relationships").doc(uid).get(),
          db.collection("dispatch_subscription_provider_state").doc(uid).get(),
        ]);
      const entitlement = entitlementSnapshot.exists ? entitlementSnapshot.data() : null;
      const couponId = couponFromEntitlement(entitlement);
      const requestedPromotionCode = String(
          request.data && request.data.promotionCode || "",
      ).trim();
      if (requestedPromotionCode && !promotionCodeEntryAllowed(plan, couponId)) {
        throw new HttpsError(
            "failed-precondition",
            "Promo codes can currently be applied to monthly Dispatch memberships without another automatic promotion.",
        );
      }
      const providerState = providerSnapshot.exists ? providerSnapshot.data() : null;
      const stripeCustomerId = providerState && providerState.ownerUid === uid &&
          String(providerState.stripeCustomerId || "").startsWith("cus_") ?
        String(providerState.stripeCustomerId) : "";
      const secretKey = stripeSecretKey.value();
      const promotion = requestedPromotionCode ?
        await resolveDispatchPromotionCode({
          secretKey,
          code: requestedPromotionCode,
          stripeCustomerId,
          existingSubscriber: false,
        }) : null;
      const promotionCodeId = promotion ? promotion.id : "";
      const allowPromotionCodes =
        promotionCodeEntryAllowed(plan, couponId) && !promotionCodeId;
      const referrerUid = relationshipSnapshot.exists ?
        String(relationshipSnapshot.data().referrerUid || "").trim() : "";

      const stateRef = db.collection("dispatch_subscription_checkout_state").doc(uid);
      const membershipRef = db.collection("dispatch_memberships").doc(uid);
      const nowMillis = Date.now();
      const reservation = await db.runTransaction(async (transaction) => {
        const [stateSnapshot, membershipSnapshot] = await Promise.all([
          transaction.get(stateRef),
          transaction.get(membershipRef),
        ]);
        const state = stateSnapshot.exists ? stateSnapshot.data() : {};
        const membership = membershipSnapshot.exists ? membershipSnapshot.data() : null;

        if (dispatchMembershipIsCurrent(membership, nowMillis)) {
          throw new HttpsError(
              "failed-precondition",
              "Your Dispatch membership is already active.",
          );
        }

        if (reusableCheckoutState(
            state,
            plan,
            nowMillis,
            promotionCodeId,
        )) {
          return {
            reuse: true,
            checkoutSessionId: String(state.checkoutSessionId),
            checkoutUrl: String(state.checkoutUrl),
            attemptNumber: Number(state.attemptNumber || 1),
            promotionCodeEntryAllowed: state.promotionCodeEntryAllowed === true,
          };
        }

        const stateExpiry = timestampMillis(state.expiresAt);
        const stateLeaseExpiry = timestampMillis(state.leaseExpiresAt);
        if (state.status === "creating" && stateExpiry > nowMillis) {
          if (state.plan !== plan ||
              String(state.promotionCodeId || "") !== promotionCodeId) {
            throw new HttpsError(
                "failed-precondition",
                "A different Dispatch membership checkout is already being prepared. Finish or retry that checkout before changing the plan or promo code.",
            );
          }
          const attemptNumber = Math.max(1, Number(state.attemptNumber || 1));
          if (stateLeaseExpiry > nowMillis) {
            return {busy: true, attemptNumber};
          }
          transaction.set(stateRef, {
            leaseExpiresAt: Timestamp.fromMillis(nowMillis + CHECKOUT_CREATION_LEASE_MS),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          return {attemptNumber};
        }

        if (createdCheckoutBlocksPlanChange(state, plan, nowMillis)) {
          throw new HttpsError(
              "failed-precondition",
              "A different Dispatch membership checkout is already open. Finish or let that checkout expire before changing plans.",
          );
        }
        // An open Checkout Session for this same plan is allowed to be replaced
        // only when its promotion differs from the user's current request. This
        // makes applying/changing a promo work without relaxing the plan guard.

        const previousAttempt = Number(state.attemptNumber || 0);
        const attemptNumber = Number.isSafeInteger(previousAttempt) && previousAttempt >= 0 ?
          previousAttempt + 1 : 1;
        transaction.set(stateRef, {
          ownerUid: uid,
          plan,
          priceId,
          status: "creating",
          checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION,
          promotionCodeEntryAllowed: allowPromotionCodes,
          promotionCodeId: promotionCodeId || null,
          attemptNumber,
          checkoutSessionId: FieldValue.delete(),
          checkoutUrl: FieldValue.delete(),
          leaseExpiresAt: Timestamp.fromMillis(nowMillis + CHECKOUT_CREATION_LEASE_MS),
          expiresAt: Timestamp.fromMillis(nowMillis + CHECKOUT_FALLBACK_EXPIRY_MS),
          updatedAt: FieldValue.serverTimestamp(),
          ...(stateSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        }, {merge: true});
        return {attemptNumber};
      });

      if (reservation.reuse) {
        return {
          checkoutSessionId: reservation.checkoutSessionId,
          checkoutUrl: reservation.checkoutUrl,
          plan,
          promotionApplied: Boolean(couponId || promotionCodeId),
          promotionCodeApplied: Boolean(promotionCodeId),
          promotionCode: promotion ? promotion.code : "",
          promotionCodeSummary: promotion ? promotion.summary : "",
          promotionCodeEntryAllowed: reservation.promotionCodeEntryAllowed,
          taxCollectionStatus: collectionStatus,
          alreadyCreated: true,
        };
      }
      if (reservation.busy) {
        throw new HttpsError(
            "resource-exhausted",
            "Dispatch membership checkout is already being started. Retry shortly.",
        );
      }

      let checkout;
      try {
        checkout = await stripeFormRequest({
          secretKey,
          path: "/v1/checkout/sessions",
          idempotencyKey: checkoutAttemptKey(uid, reservation.attemptNumber),
          fields: {
            mode: "subscription",
            success_url: successUrl,
            cancel_url: cancelUrl,
            client_reference_id: uid,
            ...(stripeCustomerId ? {customer: stripeCustomerId} : {}),
            billing_address_collection: "required",
            allow_promotion_codes: allowPromotionCodes ? "true" : "false",
            "automatic_tax[enabled]": automaticTaxEnabled(readiness) ? "true" : "false",
            "line_items[0][price]": priceId,
            "line_items[0][quantity]": 1,
            ...(promotionCodeId ? {
              "discounts[0][promotion_code]": promotionCodeId,
            } : couponId ? {"discounts[0][coupon]": couponId} : {}),
            "metadata[billingType]": "dispatch_subscription",
            "metadata[pipeBuyerUid]": uid,
            "metadata[dispatchPlan]": plan,
            "metadata[taxCollectionStatus]": collectionStatus,
            "metadata[checkoutAttempt]": String(reservation.attemptNumber),
            ...(couponId ? {"metadata[promotionCouponId]": couponId} : {}),
            ...(promotionCodeId ? {
              "metadata[promotionCodeId]": promotionCodeId,
            } : {}),
            ...(referrerUid ? {"metadata[affiliateReferrerUid]": referrerUid} : {}),
            "subscription_data[metadata][billingType]": "dispatch_subscription",
            "subscription_data[metadata][pipeBuyerUid]": uid,
            "subscription_data[metadata][dispatchPlan]": plan,
            "subscription_data[metadata][taxCollectionStatus]": collectionStatus,
            ...(promotionCodeId ? {
              "subscription_data[metadata][promotionCodeId]": promotionCodeId,
            } : {}),
            ...(referrerUid ? {
              "subscription_data[metadata][affiliateReferrerUid]": referrerUid,
            } : {}),
          },
        });
      } catch (error) {
        if (promotionCodeId && error instanceof HttpsError) {
          throw new HttpsError(
              error.code,
              "That promo code could not be applied to this checkout. Check its eligibility and try again.",
          );
        }
        throw error;
      }
      const sessionId = String(checkout.id || "");
      const checkoutUrl = String(checkout.url || "");
      if (!sessionId.startsWith("cs_") || !checkoutUrl.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return a valid subscription checkout.");
      }
      const providerExpiryMillis = Number(checkout.expires_at || 0) * 1000;
      const expiresAtMillis = Number.isFinite(providerExpiryMillis) &&
        providerExpiryMillis > nowMillis ? providerExpiryMillis :
        nowMillis + CHECKOUT_FALLBACK_EXPIRY_MS;
      const sessionData = {
        uid,
        plan,
        priceId,
        couponId: couponId || null,
        promotionCodeId: promotionCodeId || null,
        promotionCodeEntryAllowed: allowPromotionCodes,
        checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION,
        referrerUid: referrerUid || null,
        taxCollectionStatus: collectionStatus,
        taxExposureReviewRequired: collectionStatus === "registration_pending",
        automaticTaxEnabled: automaticTaxEnabled(readiness),
        checkoutAttempt: reservation.attemptNumber,
        status: "created",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      await Promise.all([
        db.collection("subscription_checkout_sessions").doc(sessionId).set(sessionData),
        stateRef.set({
          ownerUid: uid,
          plan,
          priceId,
          status: "created",
          checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION,
          promotionCodeEntryAllowed: allowPromotionCodes,
          promotionCodeId: promotionCodeId || null,
          attemptNumber: reservation.attemptNumber,
          checkoutSessionId: sessionId,
          checkoutUrl,
          leaseExpiresAt: FieldValue.delete(),
          expiresAt: Timestamp.fromMillis(expiresAtMillis),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);
      return {
        checkoutSessionId: sessionId,
        checkoutUrl,
        plan,
        promotionApplied: Boolean(couponId || promotionCodeId),
        promotionCodeApplied: Boolean(promotionCodeId),
        promotionCode: promotion ? promotion.code : "",
        promotionCodeSummary: promotion ? promotion.summary : "",
        promotionCodeEntryAllowed: allowPromotionCodes,
        taxCollectionStatus: collectionStatus,
        alreadyCreated: false,
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

  return {createDispatchSubscriptionCheckout};
}

module.exports = {
  CHECKOUT_CONFIGURATION_VERSION,
  CHECKOUT_CREATION_LEASE_MS,
  CHECKOUT_FALLBACK_EXPIRY_MS,
  checkoutAttemptKey,
  couponFromEntitlement,
  createDispatchSubscriptionCommands,
  createdCheckoutBlocksPlanChange,
  dispatchMembershipIsCurrent,
  promotionCodeEntryAllowed,
  requireSubscriptionReady,
  reusableCheckoutState,
  selectedPlan,
  timestampMillis,
};