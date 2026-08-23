"use strict";

const {
  dispatchSubscriptionCheckoutState,
} = require("./dispatch_subscription_checkout_policy");

const PUBLIC_PROVIDER_STATUSES = Object.freeze(new Set([
  "checkout_created",
  "processing",
  "active",
  "trialing",
  "past_due",
  "unpaid",
  "canceled",
  "incomplete",
  "incomplete_expired",
  "paused",
]));

function safePublicStatus(value) {
  const status = String(value || "").trim().toLowerCase();
  return PUBLIC_PROVIDER_STATUSES.has(status) ? status : "not_subscribed";
}

function safePlan(value) {
  const plan = String(value || "").trim().toLowerCase();
  return plan === "monthly" || plan === "yearly" ? plan : "";
}

function dispatchSubscriptionPublicStatus(state) {
  const data = state && typeof state === "object" ? state : {};
  const checkoutState = dispatchSubscriptionCheckoutState(data);
  const providerStatus = safePublicStatus(data.status);
  const entitlementActive = data.entitlementActive === true;
  const paymentIssue = data.paymentIssue === true;
  const reviewRequired = data.reviewRequired === true;
  const checkoutOpen = checkoutState === "active_checkout";
  const processing = providerStatus === "processing" ||
    (checkoutOpen && String(data.billingStatus || "") === "checkout_complete");
  const alreadySubscribed = checkoutState === "existing_subscription" ||
    entitlementActive;

  return Object.freeze({
    hasRecord: Object.keys(data).length > 0,
    plan: safePlan(data.plan),
    providerStatus,
    billingStatus: String(data.billingStatus || "").trim().slice(0, 80),
    entitlementActive,
    paymentIssue,
    reviewRequired,
    checkoutOpen,
    processing,
    alreadySubscribed,
    canStartCheckout: !alreadySubscribed && !checkoutOpen &&
      !processing && !reviewRequired && checkoutState !== "inconsistent",
  });
}

module.exports = {
  PUBLIC_PROVIDER_STATUSES,
  dispatchSubscriptionPublicStatus,
  safePlan,
  safePublicStatus,
};
