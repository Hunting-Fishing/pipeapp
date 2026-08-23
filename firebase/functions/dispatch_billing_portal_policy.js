"use strict";

const DISPATCH_BILLING_PORTAL_PROVIDER_REVISION =
  "2026-08-23-p2-v1-provider-features";

function validStripeCustomerId(value) {
  return /^cus_[A-Za-z0-9]+$/u.test(String(value || "").trim());
}

function validStripeSubscriptionId(value) {
  return /^sub_[A-Za-z0-9]+$/u.test(String(value || "").trim());
}

function validStripeBillingPortalConfigurationId(value) {
  return /^bpc_[A-Za-z0-9]+$/u.test(String(value || "").trim());
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

function dispatchBillingPortalStoredFeaturesReady(features = {}) {
  const data = features && typeof features === "object" ? features : {};
  return data.paymentMethodUpdate === true &&
    data.invoiceHistory === true &&
    data.subscriptionCancel === true &&
    String(data.subscriptionCancelMode || "") === "at_period_end" &&
    String(data.subscriptionCancelProration || "") === "none" &&
    data.subscriptionUpdate === false;
}

function dispatchBillingPortalProviderAssessment(configuration = {}) {
  const features = configuration && typeof configuration.features === "object" ?
    configuration.features : {};
  const paymentMethodUpdate = features.payment_method_update || {};
  const invoiceHistory = features.invoice_history || {};
  const subscriptionCancel = features.subscription_cancel || {};
  const subscriptionUpdate = features.subscription_update || {};
  const failedChecks = [];
  const configurationId = String(configuration.id || "").trim();

  if (!validStripeBillingPortalConfigurationId(configurationId)) {
    failedChecks.push("configuration_id");
  }
  if (configuration.livemode !== true) failedChecks.push("livemode");
  if (configuration.active !== true) failedChecks.push("active");
  if (paymentMethodUpdate.enabled !== true) {
    failedChecks.push("payment_method_update");
  }
  if (invoiceHistory.enabled !== true) {
    failedChecks.push("invoice_history");
  }
  if (subscriptionCancel.enabled !== true) {
    failedChecks.push("subscription_cancel");
  }
  if (String(subscriptionCancel.mode || "") !== "at_period_end") {
    failedChecks.push("subscription_cancel_mode");
  }
  if (String(subscriptionCancel.proration_behavior || "none") !== "none") {
    failedChecks.push("subscription_cancel_proration");
  }
  if (subscriptionUpdate.enabled !== false) {
    failedChecks.push("subscription_update_disabled");
  }

  return Object.freeze({
    ready: failedChecks.length === 0,
    configurationId,
    revision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    failedChecks: Object.freeze(failedChecks),
    features: Object.freeze({
      paymentMethodUpdate: paymentMethodUpdate.enabled === true,
      invoiceHistory: invoiceHistory.enabled === true,
      subscriptionCancel: subscriptionCancel.enabled === true,
      subscriptionCancelMode: String(subscriptionCancel.mode || ""),
      subscriptionCancelProration:
        String(subscriptionCancel.proration_behavior || "none"),
      subscriptionUpdate: subscriptionUpdate.enabled === true,
    }),
  });
}

function dispatchBillingPortalProviderRecordReady(config = {}) {
  const configurationId = String(config.stripePortalConfigurationId || "").trim();
  return config.providerVerified === true &&
    config.providerVerificationRevision ===
      DISPATCH_BILLING_PORTAL_PROVIDER_REVISION &&
    config.providerVerifiedConfigurationId === configurationId &&
    validStripeBillingPortalConfigurationId(configurationId) &&
    dispatchBillingPortalStoredFeaturesReady(config.providerVerifiedFeatures);
}

function dispatchBillingPortalAvailable(config = {}, state = {}) {
  return config.enabled === true &&
    dispatchBillingPortalProviderRecordReady(config) &&
    state.reviewRequired !== true &&
    validStripeCustomerId(state.stripeCustomerId) &&
    validStripeSubscriptionId(state.stripeSubscriptionId);
}

module.exports = {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  dispatchBillingPortalAvailable,
  dispatchBillingPortalProviderAssessment,
  dispatchBillingPortalProviderRecordReady,
  dispatchBillingPortalStoredFeaturesReady,
  validStripeBillingPortalConfigurationId,
  validStripeBillingPortalUrl,
  validStripeCustomerId,
  validStripeSubscriptionId,
};
