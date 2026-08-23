"use strict";

function validStripeCustomerId(value) {
  return /^cus_[A-Za-z0-9]+$/u.test(String(value || "").trim());
}

function validStripeSubscriptionId(value) {
  return /^sub_[A-Za-z0-9]+$/u.test(String(value || "").trim());
}

function validStripeBillingPortalUrl(value) {
  try {
    const url = new URL(String(value || "").trim());
    return url.protocol === "https:" &&
      url.hostname === "billing.stripe.com" &&
      !url.username &&
      !url.password;
  } catch (_) {
    return false;
  }
}

function dispatchBillingPortalAvailable(config = {}, state = {}) {
  return config.enabled === true &&
    state.reviewRequired !== true &&
    validStripeCustomerId(state.stripeCustomerId) &&
    validStripeSubscriptionId(state.stripeSubscriptionId);
}

module.exports = {
  dispatchBillingPortalAvailable,
  validStripeBillingPortalUrl,
  validStripeCustomerId,
  validStripeSubscriptionId,
};
