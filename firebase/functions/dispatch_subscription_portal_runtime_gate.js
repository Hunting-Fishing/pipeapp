"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  dispatchBillingPortalProviderRecordReady,
} = require("./dispatch_billing_portal_policy");
const {safeConfiguredUrl} = require("./stripe_checkout_commands");

const CONFIG_COLLECTION = "platform_configuration";
const PORTAL_DOC = "dispatch_billing_portal";

function dispatchBillingPortalRuntimeDecision(portal = {}) {
  if (portal.enabled !== true) {
    return Object.freeze({ready: false, reason: "portal_disabled"});
  }
  if (!dispatchBillingPortalProviderRecordReady(portal)) {
    return Object.freeze({ready: false, reason: "provider_verification_missing"});
  }
  try {
    safeConfiguredUrl(portal.returnUrl, "Dispatch Billing Portal return URL");
  } catch (_) {
    return Object.freeze({ready: false, reason: "return_url_invalid"});
  }
  return Object.freeze({ready: true, reason: "ready"});
}

function createDispatchSubscriptionPortalRuntimeGate(admin, innerHandler) {
  const db = admin.firestore();
  if (typeof innerHandler !== "function") {
    throw new TypeError("Dispatch Checkout inner handler is required.");
  }

  return async (request) => {
    const snapshot = await db.collection(CONFIG_COLLECTION).doc(PORTAL_DOC).get();
    const portal = snapshot.exists ? snapshot.data() : {};
    const decision = dispatchBillingPortalRuntimeDecision(portal);
    if (!decision.ready) {
      throw new HttpsError(
          "failed-precondition",
          "Dispatch subscription checkout requires the provider-verified Billing Portal configuration.",
      );
    }
    return innerHandler(request);
  };
}

module.exports = {
  CONFIG_COLLECTION,
  PORTAL_DOC,
  createDispatchSubscriptionPortalRuntimeGate,
  dispatchBillingPortalRuntimeDecision,
};
