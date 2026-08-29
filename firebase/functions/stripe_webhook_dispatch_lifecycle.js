"use strict";

const {verifyStripeSignature} = require("./stripe_webhook");

const DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS = new Set([
  "customer.subscription.created",
  "customer.subscription.updated",
  "customer.subscription.deleted",
  "customer.subscription.paused",
  "customer.subscription.resumed",
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

function isDispatchCheckoutCompletedEvent(event) {
  const session = event && event.data && event.data.object;
  return Boolean(event &&
    event.type === "checkout.session.completed" &&
    session &&
    session.metadata &&
    session.metadata.billingType === "dispatch_subscription");
}

function isVipCheckoutCompletedEvent(event) {
  const session = event && event.data && event.data.object;
  return Boolean(event &&
    event.type === "checkout.session.completed" &&
    session &&
    session.metadata &&
    session.metadata.billingType === "vip_subscription");
}

function isDispatchProviderStateEvent(event) {
  return isDispatchSubscriptionLifecycleEvent(event) ||
    isDispatchCheckoutCompletedEvent(event);
}

function createStripeWebhookDispatchLifecycleWrapper({
  admin,
  baseHandler,
  dispatchSubscriptionLifecycle,
  vipSubscriptionLifecycle,
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
    if (!isDispatchProviderStateEvent(event) &&
        !isVipCheckoutCompletedEvent(event)) {
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
      const object = event.data.object;
      const billing = String(object && object.metadata &&
        object.metadata.billingType || "");
      const vip = billing === "vip_subscription";
      if (event.type === "checkout.session.completed") {
        if (vip) {
          await vipSubscriptionLifecycle.handleVipCheckoutCompleted(object);
        } else {
          await dispatchSubscriptionLifecycle
              .handleDispatchCheckoutCompleted(object);
        }
      } else if (event.type === "customer.subscription.created") {
        if (vip) {
          await vipSubscriptionLifecycle.handleVipSubscriptionCreated(object);
        } else {
          await dispatchSubscriptionLifecycle
              .handleDispatchSubscriptionCreated(object);
        }
      } else if (event.type === "customer.subscription.deleted") {
        if (vip) {
          await vipSubscriptionLifecycle.handleVipSubscriptionDeleted(object);
        } else {
          await dispatchSubscriptionLifecycle
              .handleDispatchSubscriptionDeleted(object);
        }
      } else if ([
        "customer.subscription.updated",
        "customer.subscription.paused",
        "customer.subscription.resumed",
      ].includes(event.type)) {
        if (vip) {
          await vipSubscriptionLifecycle.handleVipSubscriptionUpdated(object);
        } else {
          await dispatchSubscriptionLifecycle
              .handleDispatchSubscriptionUpdated(object);
        }
      }
    } catch (error) {
      console.error("Subscription provider-state webhook failed", {
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

    // The established handler remains the single owner of the processed event
    // ledger and of all existing checkout/refund/dispute behavior.
    return baseHandler(request, response);
  };
}

module.exports = {
  DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS,
  createStripeWebhookDispatchLifecycleWrapper,
  isDispatchCheckoutCompletedEvent,
  isDispatchProviderStateEvent,
  isDispatchSubscriptionLifecycleEvent,
  isVipCheckoutCompletedEvent,
  stripeEventFromRawBody,
};
