"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {
  stripeFormRequest,
} = require("./stripe_checkout_commands");

const CONFIG_COLLECTION = "platform_configuration";
const READINESS_DOC = "payment_provider_readiness";
const PRODUCTION_WEBHOOK_URL =
  "https://us-central1-flutter-flow-pipe.cloudfunctions.net/stripeMarketplaceWebhook";
const REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS = Object.freeze([
  "invoice.paid",
  "invoice.payment_failed",
  "customer.subscription.updated",
  "customer.subscription.deleted",
]);

function dispatchSubscriptionLifecycleWebhookAssessment(
    payload,
    webhookUrl = PRODUCTION_WEBHOOK_URL,
) {
  const endpoints = payload && Array.isArray(payload.data) ? payload.data : [];
  const endpoint = endpoints.find((item) =>
    item &&
    String(item.url || "") === webhookUrl &&
    String(item.status || "") === "enabled" &&
    item.livemode === true,
  );
  if (!endpoint) {
    return Object.freeze({
      verified: false,
      endpointId: "",
      missingEvents: [...REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS],
    });
  }
  const enabledEvents = new Set(
      Array.isArray(endpoint.enabled_events) ? endpoint.enabled_events : [],
  );
  const missingEvents = enabledEvents.has("*") ? [] :
    REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS.filter(
        (event) => !enabledEvents.has(event),
    );
  return Object.freeze({
    verified: missingEvents.length === 0,
    endpointId: String(endpoint.id || ""),
    missingEvents,
  });
}

function createDispatchSubscriptionLaunchReadinessCommands(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const authorize = options.requireAdministrator || requireAdministrator;
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());
  const webhookUrl = options.webhookUrl || PRODUCTION_WEBHOOK_URL;

  const verifyDispatchSubscriptionLifecycleWebhook = async (request) => {
    try {
      const administratorUid = authorize(request);
      const endpoints = await stripeRequest({
        secretKey: secretProvider(),
        path: "/v1/webhook_endpoints?limit=100",
        method: "GET",
      });
      const assessment = dispatchSubscriptionLifecycleWebhookAssessment(
          endpoints,
          webhookUrl,
      );
      const readinessRef = db.collection(CONFIG_COLLECTION).doc(READINESS_DOC);
      const result = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(readinessRef);
        const current = snapshot.exists ? snapshot.data() : {};
        const revision = Math.max(0, Number(current.revision || 0)) + 1;
        const next = {
          ...current,
          stripeSubscriptionLifecycleWebhookVerified: assessment.verified,
          revision,
          lastChangedByUid: administratorUid,
          lastChangeReason: assessment.verified ?
            "Verified required Dispatch subscription lifecycle events directly against the live Stripe webhook endpoint." :
            "Dispatch subscription lifecycle webhook verification failed against the live Stripe endpoint.",
          updatedAt: FieldValue.serverTimestamp(),
        };
        transaction.set(readinessRef, next, {merge: false});
        transaction.create(db.collection("payment_readiness_audit").doc(), {
          administratorUid,
          reason: next.lastChangeReason,
          revision,
          previous: current,
          next,
          stripeWebhookEndpointId: assessment.endpointId || null,
          missingSubscriptionLifecycleEvents: assessment.missingEvents,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {revision};
      });
      return {
        verified: assessment.verified,
        stripeWebhookEndpointId: assessment.endpointId,
        missingEvents: assessment.missingEvents,
        revision: result.revision,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription lifecycle webhook verification failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch subscription lifecycle webhook verification could not be completed.",
      );
    }
  };

  return {verifyDispatchSubscriptionLifecycleWebhook};
}

module.exports = {
  CONFIG_COLLECTION,
  PRODUCTION_WEBHOOK_URL,
  READINESS_DOC,
  REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS,
  createDispatchSubscriptionLaunchReadinessCommands,
  dispatchSubscriptionLifecycleWebhookAssessment,
};
