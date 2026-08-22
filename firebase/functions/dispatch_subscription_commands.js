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
  automaticTaxEnabled,
  taxBillingPrepared,
  taxCollectionStatus,
} = require("./pending_tax_policy");

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

function createDispatchSubscriptionCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

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
        idempotencyKey: `pipebuyer-dispatch-${uid}-${plan}-${Date.now()}`,
        fields: {
          mode: "subscription",
          success_url: successUrl,
          cancel_url: cancelUrl,
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
      await db.collection("subscription_checkout_sessions").doc(sessionId).set({
        uid,
        plan,
        priceId,
        couponId: couponId || null,
        referrerUid: referrerUid || null,
        taxCollectionStatus: collectionStatus,
        taxExposureReviewRequired: collectionStatus === "registration_pending",
        automaticTaxEnabled: automaticTaxEnabled(readiness),
        status: "created",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
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

  return {createDispatchSubscriptionCheckout};
}

module.exports = {
  couponFromEntitlement,
  createDispatchSubscriptionCommands,
  requireSubscriptionReady,
  selectedPlan,
};
