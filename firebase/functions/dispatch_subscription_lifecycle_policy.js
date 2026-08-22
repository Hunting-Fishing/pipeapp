"use strict";

const ENTITLEMENT_ON_STATUSES = Object.freeze(new Set([
  "active",
  "trialing",
]));
const ENTITLEMENT_OFF_STATUSES = Object.freeze(new Set([
  "canceled",
  "unpaid",
  "incomplete",
  "incomplete_expired",
  "paused",
]));

function dispatchSubscriptionLifecycleDecision(
    providerStatus,
    currentEntitlementActive = false,
) {
  const status = String(providerStatus || "").trim();
  if (ENTITLEMENT_ON_STATUSES.has(status)) {
    return Object.freeze({
      status,
      entitlementActive: true,
      paymentIssue: false,
      reviewRequired: false,
    });
  }
  if (status === "past_due") {
    return Object.freeze({
      status,
      entitlementActive: currentEntitlementActive === true,
      paymentIssue: true,
      reviewRequired: false,
    });
  }
  if (ENTITLEMENT_OFF_STATUSES.has(status)) {
    return Object.freeze({
      status,
      entitlementActive: false,
      paymentIssue: status === "unpaid",
      reviewRequired: false,
    });
  }
  return Object.freeze({
    status: status || "unknown",
    entitlementActive: currentEntitlementActive === true,
    paymentIssue: false,
    reviewRequired: true,
  });
}

function dispatchCheckoutWebhookDecision(current = {}, session = {}) {
  const currentSubscriptionId = String(current.stripeSubscriptionId || "");
  const eventSubscriptionId = typeof session.subscription === "string" ?
    session.subscription :
    String(session.subscription && session.subscription.id || "");
  if (current.entitlementActive === true &&
      currentSubscriptionId.startsWith("sub_") &&
      (!eventSubscriptionId || eventSubscriptionId === currentSubscriptionId)) {
    return Object.freeze({action: "preserve_active"});
  }
  if (currentSubscriptionId.startsWith("sub_") &&
      eventSubscriptionId && currentSubscriptionId !== eventSubscriptionId) {
    return Object.freeze({action: "review", reason: "subscription_conflict"});
  }
  return Object.freeze({
    action: "processing",
    stripeSubscriptionId: eventSubscriptionId.startsWith("sub_") ?
      eventSubscriptionId : "",
  });
}

module.exports = {
  ENTITLEMENT_OFF_STATUSES,
  ENTITLEMENT_ON_STATUSES,
  dispatchCheckoutWebhookDecision,
  dispatchSubscriptionLifecycleDecision,
};
