"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");

function billingType(object) {
  return String(object && object.metadata && object.metadata.billingType || "")
      .trim();
}

function createDispatchSubscriptionWebhookWrapper(admin, options = {}) {
  const db = admin.firestore();
  const innerHandler = options.innerHandler;
  const dispatchState = options.dispatchState;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());
  if (typeof innerHandler !== "function" || !dispatchState) {
    throw new TypeError("Dispatch subscription webhook dependencies are required.");
  }

  return async (request, response) => {
    let event = null;
    try {
      event = JSON.parse(request.rawBody.toString("utf8"));
    } catch (_) {
      await innerHandler(request, response);
      return;
    }
    const eventId = String(event && event.id || "");
    const type = String(event && event.type || "");
    const object = event && event.data && event.data.object || null;
    try {
      if (object && [
        "checkout.session.completed",
        "checkout.session.async_payment_succeeded",
      ].includes(type) && billingType(object) === "dispatch_subscription") {
        await dispatchState.handleCheckoutSession(object);
      } else if (object && type === "invoice.paid") {
        await dispatchState.handleInvoicePaid(object, secretProvider());
      } else if (object && type === "invoice.payment_failed") {
        await dispatchState.handleInvoicePaymentFailed(object, secretProvider());
      } else if (object && [
        "customer.subscription.updated",
        "customer.subscription.deleted",
      ].includes(type)) {
        await dispatchState.handleSubscriptionEvent(
            object,
            type,
            secretProvider(),
        );
      }
    } catch (error) {
      console.error("Dispatch subscription webhook state update failed", {
        eventId,
        type,
        error,
      });
      if (eventId.startsWith("evt_")) {
        await db.collection("stripe_webhook_events").doc(eventId).set({
          eventId,
          type,
          status: "failed",
          failureScope: "dispatch_subscription_state",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      response.status(500).send("Dispatch subscription state processing failed");
      return;
    }
    await innerHandler(request, response);
  };
}

module.exports = {
  billingType,
  createDispatchSubscriptionWebhookWrapper,
};
