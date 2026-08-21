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

function validPortalConfigurationId(value) {
  return /^bpc_[A-Za-z0-9]+$/.test(String(value || "").trim());
}

function providerStateSupportsPortal(providerState, uid) {
  if (!providerState || providerState.ownerUid !== uid) return false;
  return String(providerState.stripeCustomerId || "").startsWith("cus_") &&
    String(providerState.subscriptionId || "").startsWith("sub_");
}

function portalReady(readiness) {
  return Boolean(
      readiness &&
      readiness.stripeMode === "production" &&
      readiness.stripeWebhookVerified === true &&
      readiness.stripeDispatchPortalEnabled === true &&
      validPortalConfigurationId(readiness.stripeDispatchPortalConfigurationId) &&
      String(readiness.dispatchPortalReturnUrl || "").trim(),
  );
}

function requirePortalReady(readiness) {
  if (!portalReady(readiness)) {
    throw new HttpsError(
        "failed-precondition",
        "Dispatch subscription management is not enabled yet.",
    );
  }
}

function createDispatchSubscriptionPortal(admin) {
  const db = admin.firestore();

  const createDispatchSubscriptionPortalSession = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "dispatch");

      const [readinessSnapshot, providerSnapshot] = await Promise.all([
        db.collection("platform_configuration")
            .doc("payment_provider_readiness")
            .get(),
        db.collection("dispatch_subscription_provider_state")
            .doc(identity.uid)
            .get(),
      ]);
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeDispatchPortalEnabled:
          readinessData.stripeDispatchPortalEnabled === true,
        stripeDispatchPortalConfigurationId: String(
            readinessData.stripeDispatchPortalConfigurationId || "",
        ).trim(),
        dispatchPortalReturnUrl: String(
            readinessData.dispatchPortalReturnUrl || "",
        ).trim(),
      };
      requirePortalReady(readiness);

      const providerState = providerSnapshot.exists ? providerSnapshot.data() : null;
      if (!providerStateSupportsPortal(providerState, identity.uid)) {
        throw new HttpsError(
            "failed-precondition",
            "No Stripe Dispatch subscription is available to manage.",
        );
      }

      const returnUrl = safeConfiguredUrl(
          readiness.dispatchPortalReturnUrl,
          "Dispatch subscription portal return URL",
      );
      const portal = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/billing_portal/sessions",
        fields: {
          customer: String(providerState.stripeCustomerId),
          configuration: readiness.stripeDispatchPortalConfigurationId,
          return_url: returnUrl,
        },
      });
      const portalUrl = String(portal.url || "");
      if (!portalUrl.startsWith("https://billing.stripe.com/")) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid subscription management link.",
        );
      }

      // Customer Portal links are short-lived authenticated URLs. Return only to
      // the current authenticated caller; never persist the URL in Firestore.
      return {portalUrl};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription portal session failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch subscription management could not be opened.",
      );
    }
  };

  return {createDispatchSubscriptionPortalSession};
}

module.exports = {
  createDispatchSubscriptionPortal,
  portalReady,
  providerStateSupportsPortal,
  requirePortalReady,
  validPortalConfigurationId,
};
