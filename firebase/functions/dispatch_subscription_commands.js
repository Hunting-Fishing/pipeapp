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
  validStripeBillingPortalConfigurationId,
} = require("./dispatch_billing_portal_policy");
const {
  automaticTaxEnabled,
  taxBillingPrepared,
  taxCollectionStatus,
} = require("./pending_tax_policy");
const {
  requireCanadaSmallSupplierRuntimeEvidence,
} = require("./canada_small_supplier_runtime_gate");
const {
  dispatchCheckoutIdempotencyKey,
  dispatchCheckoutSessionId,
  dispatchPostProviderPersistenceDecision,
  dispatchStripeSubscriptionId,
  dispatchSubscriptionCheckoutState,
  existingDispatchCheckoutDecision,
  nextDispatchCheckoutAttempt,
  nextDispatchRetiredSubscriptionIds,
} = require("./dispatch_subscription_checkout_policy");

const DISPATCH_SUBSCRIPTIONS_COLLECTION = "dispatch_subscriptions";
const SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION =
  "subscription_checkout_sessions";
const DISPATCH_BILLING_PORTAL_DOC = "dispatch_billing_portal";

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

function validStripeCheckoutUrl(value) {
  try {
    const url = new URL(String(value || ""));
    return url.protocol === "https:" && url.hostname === "checkout.stripe.com";
  } catch (_) {
    return false;
  }
}

function dispatchBillingPortalRuntimeReady(portalConfig) {
  const data = portalConfig && typeof portalConfig === "object" ? portalConfig : {};
  if (data.enabled !== true ||
      !validStripeBillingPortalConfigurationId(
          data.stripePortalConfigurationId,
      )) {
    return false;
  }
  try {
    safeConfiguredUrl(data.returnUrl, "Dispatch Billing Portal return URL");
    return true;
  } catch (_) {
    return false;
  }
}

function requireSubscriptionReady(readiness) {
  if (!readiness.stripeSubscriptionsEnabled ||
      readiness.stripeMode !== "production" ||
      readiness.stripeWebhookVerified !== true ||
      readiness.stripeSubscriptionLifecycleWebhookVerified !== true ||
      readiness.stripeSubscriptionRecoveryVerified !== true ||
      readiness.dispatchBillingPortalReady !== true ||
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

function createDispatchSubscriptionCommands(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const authUid = options.authUid || requireAuth;
  const rateLimit = options.rateLimit || enforceUserRateLimit;
  const loadFeatureFlags = options.loadFeatureFlags || loadPhase1FeatureFlags;
  const requireFeature = options.requireFeature || requirePhase1Feature;
  const providerReadiness = options.loadProviderReadiness || loadProviderReadiness;
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());
  const runtimeTaxEvidence = options.runtimeTaxEvidence ||
    requireCanadaSmallSupplierRuntimeEvidence;

  const createDispatchSubscriptionCheckout = async (request) => {
    try {
      const uid = authUid(request);
      await rateLimit({db, admin, request, scope: "account"});
      const flags = await loadFeatureFlags(db);
      requireFeature(flags, "dispatch");
      requireFeature(flags, "paidFeatures");
      const [readinessSnapshot, portalSnapshot] = await Promise.all([
        db.collection("platform_configuration")
            .doc("payment_provider_readiness").get(),
        db.collection("platform_configuration")
            .doc(DISPATCH_BILLING_PORTAL_DOC).get(),
      ]);
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const portalData = portalSnapshot.exists ? portalSnapshot.data() : {};
      const readiness = {
        ...(await providerReadiness(db)),
        stripeSubscriptionsEnabled: readinessData.stripeSubscriptionsEnabled === true,
        stripeSubscriptionRecoveryVerified:
          readinessData.stripeSubscriptionRecoveryVerified === true,
        stripeSubscriptionLifecycleWebhookVerified:
          readinessData.stripeSubscriptionLifecycleWebhookVerified === true,
        dispatchBillingPortalReady: dispatchBillingPortalRuntimeReady(portalData),
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved:
          readinessData.stripeTaxPendingBillingApproved === true,
        canadaGstHstSmallSupplier:
          readinessData.canadaGstHstSmallSupplier === true,
        canadaGstHstSmallSupplierAssessmentRevision:
          readinessData.canadaGstHstSmallSupplierAssessmentRevision,
        checkoutSuccessUrl: String(readinessData.checkoutSuccessUrl || ""),
        checkoutCancelUrl: String(readinessData.checkoutCancelUrl || ""),
      };
      await runtimeTaxEvidence(db, readiness);
      requireSubscriptionReady(readiness);

      const plan = selectedPlan(request.data && request.data.plan);
      const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION).doc(uid);
      const stateSnapshot = await stateRef.get();
      const state = stateSnapshot.exists ? stateSnapshot.data() : {};
      const localState = dispatchSubscriptionCheckoutState(state);

      if (localState === "existing_subscription") {
        return {
          alreadySubscribed: true,
          processing: false,
          plan: String(state.plan || ""),
          subscriptionStatus: String(state.status || ""),
        };
      }
      if (localState === "inconsistent") {
        throw new HttpsError(
            "failed-precondition",
            "The current Dispatch subscription payment state needs review before another Checkout can start.",
        );
      }
      if (localState === "active_checkout") {
        const existingPlan = String(state.plan || "");
        if (existingPlan && existingPlan !== plan) {
          throw new HttpsError(
              "failed-precondition",
              `A ${existingPlan} Dispatch Checkout is already open. Complete it or let it expire before switching plans.`,
          );
        }
        const existingSessionId = dispatchCheckoutSessionId(state);
        const existingSession = await stripeRequest({
          secretKey: secretProvider(),
          path: `/v1/checkout/sessions/${encodeURIComponent(existingSessionId)}`,
          method: "GET",
        });
        const existingUrl = String(existingSession.url || "");
        const decision = existingDispatchCheckoutDecision({
          localStatus: state.status,
          providerStatus: existingSession.status,
          paymentStatus: existingSession.payment_status,
          checkoutUrlValid: validStripeCheckoutUrl(existingUrl),
        });
        if (decision.action === "processing") {
          return {
            alreadySubscribed: false,
            alreadyCreated: true,
            processing: true,
            plan,
            checkoutSessionId: existingSessionId,
            taxCollectionStatus: taxCollectionStatus(readiness),
          };
        }
        if (decision.action === "reuse") {
          return {
            alreadySubscribed: false,
            alreadyCreated: true,
            processing: false,
            plan,
            checkoutSessionId: existingSessionId,
            checkoutUrl: existingUrl,
            taxCollectionStatus: taxCollectionStatus(readiness),
          };
        }
        if (decision.action === "invalid_url") {
          throw new HttpsError(
              "failed-precondition",
              "The existing Stripe Dispatch Checkout link is unavailable.",
          );
        }
        if (decision.action === "review") {
          throw new HttpsError(
              "failed-precondition",
              "The existing Dispatch subscription Checkout needs review before another Checkout can start.",
          );
        }
      }

      const collectionStatus = taxCollectionStatus(readiness);
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
      const attempt = nextDispatchCheckoutAttempt(state);
      const checkout = await stripeRequest({
        secretKey: secretProvider(),
        path: "/v1/checkout/sessions",
        idempotencyKey: dispatchCheckoutIdempotencyKey(uid, attempt),
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
          "metadata[checkoutAttempt]": attempt,
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
      if (!sessionId.startsWith("cs_") || !validStripeCheckoutUrl(checkoutUrl)) {
        throw new HttpsError("internal", "Stripe did not return a valid subscription Checkout.");
      }

      const sessionRef = db.collection(SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION)
          .doc(sessionId);
      const persistence = await db.runTransaction(async (transaction) => {
        const currentSnapshot = await transaction.get(stateRef);
        const current = currentSnapshot.exists ? currentSnapshot.data() : {};
        const decision = dispatchPostProviderPersistenceDecision({
          currentStatus: current.status,
          currentSessionId: dispatchCheckoutSessionId(current),
          currentAttempt: current.checkoutAttempt,
          createdSessionId: sessionId,
          createdAttempt: attempt,
          currentSubscriptionId: dispatchStripeSubscriptionId(current),
        });

        transaction.set(sessionRef, {
          uid,
          plan,
          priceId,
          checkoutAttempt: attempt,
          couponId: couponId || null,
          referrerUid: referrerUid || null,
          taxCollectionStatus: collectionStatus,
          taxExposureReviewRequired: collectionStatus === "registration_pending",
          automaticTaxEnabled: automaticTaxEnabled(readiness),
          status: "created",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        if (decision !== "checkout_created") {
          return {decision};
        }
        const retiredStripeSubscriptionIds =
          nextDispatchRetiredSubscriptionIds(current);
        transaction.set(stateRef, {
          uid,
          plan,
          priceId,
          status: "checkout_created",
          checkoutAttempt: attempt,
          stripeCheckoutSessionId: sessionId,
          // A new Checkout is only allowed when no unresolved subscription is
          // active. Move a restartable prior subscription into a bounded
          // retired-id ledger before clearing the live provider identity. Late
          // webhooks for that old subscription can then be ignored safely.
          stripeSubscriptionId: null,
          retiredStripeSubscriptionIds,
          entitlementActive: false,
          paymentIssue: false,
          reviewRequired: false,
          reviewReason: null,
          conflictingStripeSubscriptionId: null,
          taxCollectionStatus: collectionStatus,
          promotionCouponId: couponId || null,
          affiliateReferrerUid: referrerUid || null,
          updatedAt: FieldValue.serverTimestamp(),
          ...(currentSnapshot.exists ? {} : {
            createdAt: FieldValue.serverTimestamp(),
          }),
        }, {merge: true});
        return {decision: "checkout_created"};
      });

      if (persistence.decision === "existing_subscription") {
        return {
          alreadySubscribed: true,
          processing: false,
          plan,
        };
      }
      if (persistence.decision === "processing") {
        return {
          alreadySubscribed: false,
          alreadyCreated: true,
          processing: true,
          plan,
          checkoutSessionId: sessionId,
          taxCollectionStatus: collectionStatus,
        };
      }
      if (persistence.decision === "superseded") {
        throw new HttpsError(
            "failed-precondition",
            "A newer Dispatch subscription Checkout already exists. Refresh and try again.",
        );
      }

      return {
        checkoutSessionId: sessionId,
        checkoutUrl,
        plan,
        checkoutAttempt: attempt,
        alreadyCreated: false,
        alreadySubscribed: false,
        processing: false,
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
  DISPATCH_BILLING_PORTAL_DOC,
  DISPATCH_SUBSCRIPTIONS_COLLECTION,
  SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION,
  couponFromEntitlement,
  createDispatchSubscriptionCommands,
  dispatchBillingPortalRuntimeReady,
  requireSubscriptionReady,
  selectedPlan,
  validStripeCheckoutUrl,
};
