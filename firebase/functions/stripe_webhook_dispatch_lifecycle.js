"use strict";

const {
  subscriptionMembershipPlan,
} = require("./membership_plan_policy");

const DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS = new Set([
  "customer.subscription.created",
  "customer.subscription.updated",
  "customer.subscription.deleted",
  "customer.subscription.paused",
  "customer.subscription.resumed",
]);
const SUBSCRIPTION_BILLING_EVENTS = new Set([
  "invoice.paid",
  "invoice.payment_failed",
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

function subscriptionLifecyclePlan(event) {
  if (!event ||
      !DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS.has(String(event.type || "")) ||
      !event.data || !event.data.object) {
    return null;
  }
  return subscriptionMembershipPlan(event.data.object);
}

function isDispatchSubscriptionLifecycleEvent(event) {
  return Boolean(subscriptionLifecyclePlan(event));
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
  baseHandler,
  dispatchSubscriptionLifecycle,
  vipSubscriptionLifecycle,
}) {
  const webhookEventStore = baseHandler.webhookEventStore;
  if (!webhookEventStore) {
    throw new TypeError("The Stripe webhook event store is unavailable.");
  }
  if (typeof baseHandler.verifyRequest !== "function") {
    throw new TypeError("The Stripe webhook verifier is unavailable.");
  }

  return async (request, response) => {
    const verification = await baseHandler.verifyRequest(request);
    if (!verification.ok) {
      response.status(verification.statusCode).send(verification.message);
      return;
    }
    const event = verification.event;
    const subscriptionProviderEvent = isDispatchProviderStateEvent(event) ||
      isVipCheckoutCompletedEvent(event) ||
      SUBSCRIPTION_BILLING_EVENTS.has(String(event && event.type || ""));
    if (!subscriptionProviderEvent) {
      return baseHandler(request, response, {
        event,
        stripeMode: verification.stripeMode,
        signatureVerified: true,
      });
    }
    if (verification.stripeMode !== "production") {
      response.status(409).send(
          "Stripe subscription events require the production environment",
      );
      return;
    }

    const eventId = String(event.id || "");
    if (!eventId.startsWith("evt_")) {
      return baseHandler(request, response);
    }
    let claim;
    try {
      claim = await webhookEventStore.begin({eventId, type: event.type});
    } catch (error) {
      console.error("Subscription webhook claim failed", {
        eventId,
        type: event.type,
        error,
      });
      response.status(500).send("Webhook claim failed");
      return;
    }
    if (claim.state === "duplicate") {
      response.status(200).send("Already processed");
      return;
    }
    if (claim.state !== "acquired") {
      response.status(409).send("Webhook processing in progress");
      return;
    }

    try {
      const object = event.data.object;
      const plan = event.type === "checkout.session.completed" ?
        null : subscriptionMembershipPlan(object);
      const billing = String(object && object.metadata &&
        object.metadata.billingType || "");
      // Checkout metadata is used only before Stripe has a subscription item to
      // inspect. Every subscription lifecycle event is routed by its approved
      // Stripe price, so stale metadata cannot grant the wrong Pipe Buyer tier.
      const vip = plan ? plan.tier === "vip" : billing === "vip_subscription";
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
      await webhookEventStore.fail(eventId, error, claim);
      response.status(500).send("Webhook processing failed");
      return;
    }

    // The established handler remains the single owner of the processed event
    // ledger and of all existing checkout/refund/dispute behavior.
    return baseHandler(request, response, {
      claim,
      event,
      stripeMode: verification.stripeMode,
      signatureVerified: true,
      webhookEventStore,
    });
  };
}

module.exports = {
  DISPATCH_SUBSCRIPTION_LIFECYCLE_EVENTS,
  SUBSCRIPTION_BILLING_EVENTS,
  createStripeWebhookDispatchLifecycleWrapper,
  isDispatchCheckoutCompletedEvent,
  isDispatchProviderStateEvent,
  isDispatchSubscriptionLifecycleEvent,
  isVipCheckoutCompletedEvent,
  stripeEventFromRawBody,
  subscriptionLifecyclePlan,
};
