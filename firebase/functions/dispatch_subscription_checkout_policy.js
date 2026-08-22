"use strict";

const ACTIVE_SUBSCRIPTION_STATUSES = Object.freeze(new Set([
  "trialing",
  "active",
  "past_due",
  "unpaid",
  "paused",
  "incomplete",
]));
const ACTIVE_CHECKOUT_STATUSES = Object.freeze(new Set([
  "checkout_created",
  "processing",
]));

function dispatchCheckoutAttempt(state) {
  const value = Number(state && state.checkoutAttempt);
  return Number.isSafeInteger(value) && value >= 0 ? value : 0;
}

function nextDispatchCheckoutAttempt(state) {
  return dispatchCheckoutAttempt(state) + 1;
}

function dispatchCheckoutSessionId(state) {
  const value = String(state && state.stripeCheckoutSessionId || "").trim();
  return value.startsWith("cs_") ? value : "";
}

function dispatchStripeSubscriptionId(state) {
  const value = String(state && state.stripeSubscriptionId || "").trim();
  return value.startsWith("sub_") ? value : "";
}

function dispatchSubscriptionCheckoutState(state = {}) {
  const status = String(state.status || "").trim();
  const subscriptionId = dispatchStripeSubscriptionId(state);
  const sessionId = dispatchCheckoutSessionId(state);
  if (subscriptionId && ACTIVE_SUBSCRIPTION_STATUSES.has(status)) {
    return "existing_subscription";
  }
  if (ACTIVE_CHECKOUT_STATUSES.has(status)) {
    return sessionId ? "active_checkout" : "inconsistent";
  }
  if (subscriptionId && !new Set(["canceled", "incomplete_expired"]).has(status)) {
    return "existing_subscription";
  }
  return "create";
}

function dispatchCheckoutIdempotencyKey(uid, attempt) {
  const normalizedUid = String(uid || "").trim();
  const normalizedAttempt = Number(attempt);
  if (!normalizedUid || normalizedUid.includes("/") || normalizedUid.length > 180 ||
      !Number.isSafeInteger(normalizedAttempt) || normalizedAttempt < 1) {
    throw new Error("Invalid Dispatch Checkout idempotency input.");
  }
  return `pipebuyer-dispatch-${normalizedUid}-attempt-${normalizedAttempt}`;
}

function existingDispatchCheckoutDecision({
  localStatus = "",
  providerStatus = "",
  paymentStatus = "",
  checkoutUrlValid = false,
} = {}) {
  if (localStatus === "processing" ||
      providerStatus === "complete" ||
      paymentStatus === "paid" ||
      paymentStatus === "no_payment_required") {
    return Object.freeze({action: "processing"});
  }
  if (providerStatus === "open") {
    return Object.freeze({action: checkoutUrlValid ? "reuse" : "invalid_url"});
  }
  if (providerStatus === "expired") {
    return Object.freeze({action: "create_new"});
  }
  return Object.freeze({action: "review"});
}

function dispatchPostProviderPersistenceDecision({
  currentStatus = "",
  currentSessionId = "",
  currentAttempt = 0,
  createdSessionId = "",
  createdAttempt = 0,
  currentSubscriptionId = "",
} = {}) {
  if (String(currentSubscriptionId || "").startsWith("sub_") &&
      ACTIVE_SUBSCRIPTION_STATUSES.has(String(currentStatus || ""))) {
    return "existing_subscription";
  }
  if (currentSessionId === createdSessionId && currentStatus === "processing") {
    return "processing";
  }
  if (Number(currentAttempt) > Number(createdAttempt)) return "superseded";
  return "checkout_created";
}

module.exports = {
  ACTIVE_CHECKOUT_STATUSES,
  ACTIVE_SUBSCRIPTION_STATUSES,
  dispatchCheckoutAttempt,
  dispatchCheckoutIdempotencyKey,
  dispatchCheckoutSessionId,
  dispatchPostProviderPersistenceDecision,
  dispatchStripeSubscriptionId,
  dispatchSubscriptionCheckoutState,
  existingDispatchCheckoutDecision,
  nextDispatchCheckoutAttempt,
};
