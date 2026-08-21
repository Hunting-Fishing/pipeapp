"use strict";

const {verifyStripeSignature} = require("./stripe_webhook");

const DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS = new Set([
  "customer.subscription.updated",
  "customer.subscription.deleted",
]);

function stripeEventFromRawBody(rawBody) {
  if (!Buffer.isBuffer(rawBody) || rawBody.length === 0) return null;
  try {
    const event = JSON.parse(rawBody.toString("utf8"));
    return event && typeof event === "object" ? event : null;
  } catch (_) {
    return null;
  }
}

function isDispatchSubscriptionLifecycleEvent(event) {
  return Boolean(event &&
    DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS.has(String(event.type || "")) &&
    event.data &&
    event.data.object);
}

function createStripeWebhookDispatchLifecycleWrapper({
  admin,
  baseHandler,
  dispatchSubscriptionLifecycle,
  stripeWebhookSecret,
}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  return async (request, response) => {
    const rawBody = request.rawBody;
    const signature = request.get("stripe-signature");
    if (!verifyStripeSignature(
        rawBody,
        signature,
        stripeWebhookSecret.value(),
    )) {
      // Delegate so the established handler remains authoritative for the
      // exact HTTP error contract and audit behavior.
      return baseHandler(request, response);
    }

    const event = stripeEventFromRawBody(rawBody);
    if (!isDispatchSubscriptionLifecycleEvent(event)) {
      return baseHandler(request, response);
    }

    const eventId = String(event.id || "");
    const eventRef = eventId.startsWith("evt_") ?
      db.collection("stripe_webhook_events").doc(eventId) : null;
    if (eventRef) {
      const existing = await eventRef.get();
      if (existing.exists && existing.data().status === "processed") {
        return baseHandler(request, response);
      }
    }

    try {
      const subscription = event.data.object;
      if (event.type === "customer.subscription.updated") {
        await dispatchSubscriptionLifecycle
            .handleDispatchSubscriptionUpdated(subscription);
      } else if (event.type === "customer.subscription.deleted") {
        await dispatchSubscriptionLifecycle
            .handleDispatchSubscriptionDeleted(subscription);
      }
    } catch (error) {
      console.error("Dispatch subscription lifecycle webhook failed", {
        eventId,
        type: event.type,
        error,
      });
      if (eventRef) {
        await eventRef.set({
          eventId,
          type: String(event.type || ""),
          status: "failed",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      response.status(500).send("Webhook processing failed");
      return;
    }

    // The established handler intentionally ignores unknown event types but
    // still records the Stripe event ID as processed. This preserves one
    // shared idempotency/audit ledger instead of creating a second webhook log.
    return baseHandler(request, response);
  };
}

module.exports = {
  DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS,
  createStripeWebhookDispatchLifecycleWrapper,
  isDispatchSubscriptionLifecycleEvent,
  stripeEventFromRawBody,
};
