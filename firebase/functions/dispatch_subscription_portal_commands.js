"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {safeConfiguredUrl, stripeFormRequest} = require("./stripe_checkout_commands");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  dispatchBillingPortalAvailable,
  validStripeBillingPortalUrl,
} = require("./dispatch_billing_portal_policy");

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function createDispatchSubscriptionPortalCommands(admin, options = {}) {
  const db = admin.firestore();
  const authUid = options.authUid || requireAuth;
  const rateLimit = options.rateLimit || enforceUserRateLimit;
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());

  const createDispatchBillingPortalSession = async (request) => {
    try {
      const uid = authUid(request);
      await rateLimit({db, admin, request, scope: "account"});
      const [configSnapshot, stateSnapshot] = await Promise.all([
        db.collection("platform_configuration").doc("dispatch_billing_portal").get(),
        db.collection("dispatch_subscriptions").doc(uid).get(),
      ]);
      const config = configSnapshot.exists ? configSnapshot.data() : {};
      const state = stateSnapshot.exists ? stateSnapshot.data() : {};
      if (!dispatchBillingPortalAvailable(config, state)) {
        throw new HttpsError(
            "failed-precondition",
            "Dispatch billing management is not available for this account yet.",
        );
      }
      const returnUrl = safeConfiguredUrl(
          config.returnUrl,
          "Dispatch Billing Portal return URL",
      );
      const portal = await stripeRequest({
        secretKey: secretProvider(),
        path: "/v1/billing_portal/sessions",
        fields: {
          customer: String(state.stripeCustomerId),
          return_url: returnUrl,
        },
      });
      const portalUrl = String(portal.url || "").trim();
      if (!validStripeBillingPortalUrl(portalUrl)) {
        throw new HttpsError(
            "internal",
            "Stripe did not return a valid billing management link.",
        );
      }
      return {portalUrl};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch Billing Portal session failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch billing management could not be opened.",
      );
    }
  };

  return {createDispatchBillingPortalSession};
}

module.exports = {
  createDispatchSubscriptionPortalCommands,
};
