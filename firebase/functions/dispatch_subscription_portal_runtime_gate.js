"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  dispatchBillingPortalProviderAssessment,
  dispatchBillingPortalProviderRecordReady,
} = require("./dispatch_billing_portal_policy");
const {
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {stripeSecretKey} = require("./stripe_marketplace_commands");

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
  return Object.freeze({
    ready: true,
    reason: "stored_proof_ready",
    configurationId: String(portal.stripePortalConfigurationId || "").trim(),
  });
}

function createDispatchSubscriptionPortalRuntimeGate(
    admin,
    innerHandler,
    options = {},
) {
  const db = admin.firestore();
  if (typeof innerHandler !== "function") {
    throw new TypeError("Dispatch billing inner handler is required.");
  }
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());
  const actionLabel = String(options.actionLabel || "Dispatch billing").trim();

  return async (request) => {
    const snapshot = await db.collection(CONFIG_COLLECTION).doc(PORTAL_DOC).get();
    const portal = snapshot.exists ? snapshot.data() : {};
    const decision = dispatchBillingPortalRuntimeDecision(portal);
    if (!decision.ready) {
      throw new HttpsError(
          "failed-precondition",
          `${actionLabel} requires the provider-verified Billing Portal configuration.`,
      );
    }

    let providerConfiguration;
    try {
      providerConfiguration = await stripeRequest({
        secretKey: secretProvider(),
        path: `/v1/billing_portal/configurations/${encodeURIComponent(decision.configurationId)}`,
        method: "GET",
      });
    } catch (_) {
      throw new HttpsError(
          "failed-precondition",
          `${actionLabel} is blocked until the live Billing Portal configuration can be re-verified.`,
      );
    }
    const assessment = dispatchBillingPortalProviderAssessment(
        providerConfiguration,
    );
    if (!assessment.ready ||
        assessment.configurationId !== decision.configurationId) {
      throw new HttpsError(
          "failed-precondition",
          `${actionLabel} is blocked because the live Billing Portal configuration no longer matches the approved launch policy.`,
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
