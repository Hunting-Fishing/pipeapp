"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  dispatchBillingPortalAvailable,
} = require("./dispatch_billing_portal_policy");
const {
  dispatchSubscriptionPublicStatus,
} = require("./dispatch_subscription_status_policy");

const DISPATCH_SUBSCRIPTIONS_COLLECTION = "dispatch_subscriptions";

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function dispatchSubscriptionCatalog(config = stripeMarketplaceConfig) {
  const monthly = config.products.dispatchMonthlyCad;
  const yearly = config.products.dispatchYearlyCad;
  return Object.freeze({
    monthly: Object.freeze({
      currency: String(monthly.currency || "CAD").toUpperCase(),
      unitAmountMinor: Number(monthly.unitAmountMinor),
      interval: "month",
    }),
    yearly: Object.freeze({
      currency: String(yearly.currency || "CAD").toUpperCase(),
      unitAmountMinor: Number(yearly.unitAmountMinor),
      interval: "year",
    }),
  });
}

function createDispatchSubscriptionStatusCommands(admin, options = {}) {
  const db = admin.firestore();
  const authUid = options.authUid || requireAuth;
  const rateLimit = options.rateLimit || enforceUserRateLimit;
  const catalog = options.catalog || (() => dispatchSubscriptionCatalog());

  const getDispatchSubscriptionStatus = async (request) => {
    try {
      const uid = authUid(request);
      await rateLimit({db, admin, request, scope: "account"});
      const [subscriptionSnapshot, portalSnapshot] = await Promise.all([
        db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION).doc(uid).get(),
        db.collection("platform_configuration").doc("dispatch_billing_portal").get(),
      ]);
      const state = subscriptionSnapshot.exists ? subscriptionSnapshot.data() : {};
      const portalConfig = portalSnapshot.exists ? portalSnapshot.data() : {};
      return {
        ...dispatchSubscriptionPublicStatus(state),
        canManageBilling: dispatchBillingPortalAvailable(portalConfig, state),
        plans: catalog(),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription status lookup failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch subscription status could not be loaded.",
      );
    }
  };

  return {getDispatchSubscriptionStatus};
}

module.exports = {
  DISPATCH_SUBSCRIPTIONS_COLLECTION,
  createDispatchSubscriptionStatusCommands,
  dispatchSubscriptionCatalog,
};
