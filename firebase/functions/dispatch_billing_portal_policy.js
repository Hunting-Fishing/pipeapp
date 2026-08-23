"use strict";

const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

const DISPATCH_BILLING_PORTAL_PROVIDER_REVISION =
  "2026-08-23-p2-v2-dispatch-plan-switching";
const DISPATCH_PORTAL_PRODUCT_ID =
  stripeMarketplaceConfig.products.dispatchMonthlyCad.productId;
const DISPATCH_PORTAL_PRICE_IDS = Object.freeze([
  stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId,
  stripeMarketplaceConfig.products.dispatchYearlyCad.priceId,
].sort());
const DISPATCH_PORTAL_CUSTOMER_UPDATES = Object.freeze([
  "address",
  "email",
  "name",
  "phone",
  "tax_id",
].sort());
const DISPATCH_PORTAL_SUBSCRIPTION_UPDATES = Object.freeze(["price"]);

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

function stripeObjectId(value) {
  if (typeof value === "string") return value.trim();
  return String(value && value.id || "").trim();
}

function normalizedStringArray(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map((item) => String(item || "").trim())
      .filter(Boolean))].sort();
}

function sameStringSet(actual, expected) {
  const left = normalizedStringArray(actual);
  const right = normalizedStringArray(expected);
  return left.length === right.length &&
    left.every((value, index) => value === right[index]);
}

function dispatchPortalProductsReady(products) {
  if (!Array.isArray(products) || products.length !== 1) return false;
  const entry = products[0] && typeof products[0] === "object" ? products[0] : {};
  return stripeObjectId(entry.product) === DISPATCH_PORTAL_PRODUCT_ID &&
    sameStringSet(entry.prices, DISPATCH_PORTAL_PRICE_IDS);
}

function dispatchBillingPortalStoredFeaturesReady(features = {}) {
  const data = features && typeof features === "object" ? features : {};
  return data.paymentMethodUpdate === true &&
    data.customerUpdate === true &&
    sameStringSet(
        data.customerUpdateAllowedUpdates,
        DISPATCH_PORTAL_CUSTOMER_UPDATES,
    ) &&
    data.invoiceHistory === true &&
    data.subscriptionCancel === true &&
    String(data.subscriptionCancelMode || "") === "at_period_end" &&
    String(data.subscriptionCancelProration || "") === "none" &&
    data.subscriptionUpdate === true &&
    sameStringSet(
        data.subscriptionUpdateAllowedUpdates,
        DISPATCH_PORTAL_SUBSCRIPTION_UPDATES,
    ) &&
    String(data.subscriptionUpdateProration || "") === "none" &&
    String(data.subscriptionUpdateProductId || "") ===
      DISPATCH_PORTAL_PRODUCT_ID &&
    sameStringSet(
        data.subscriptionUpdatePriceIds,
        DISPATCH_PORTAL_PRICE_IDS,
    );
}

function dispatchBillingPortalProviderAssessment(configuration = {}) {
  const features = configuration && typeof configuration.features === "object" ?
    configuration.features : {};
  const paymentMethodUpdate = features.payment_method_update || {};
  const customerUpdate = features.customer_update || {};
  const invoiceHistory = features.invoice_history || {};
  const subscriptionCancel = features.subscription_cancel || {};
  const subscriptionUpdate = features.subscription_update || {};
  const failedChecks = [];
  const configurationId = String(configuration.id || "").trim();
  const customerAllowedUpdates = normalizedStringArray(
      customerUpdate.allowed_updates,
  );
  const subscriptionAllowedUpdates = normalizedStringArray(
      subscriptionUpdate.default_allowed_updates,
  );
  const subscriptionProducts = Array.isArray(subscriptionUpdate.products) ?
    subscriptionUpdate.products : [];

  if (!validStripeBillingPortalConfigurationId(configurationId)) {
    failedChecks.push("configuration_id");
  }
  if (configuration.livemode !== true) failedChecks.push("livemode");
  if (configuration.active !== true) failedChecks.push("active");
  if (paymentMethodUpdate.enabled !== true) {
    failedChecks.push("payment_method_update");
  }
  if (customerUpdate.enabled !== true) {
    failedChecks.push("customer_update");
  }
  if (!sameStringSet(customerAllowedUpdates, DISPATCH_PORTAL_CUSTOMER_UPDATES)) {
    failedChecks.push("customer_update_fields");
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
  if (subscriptionUpdate.enabled !== true) {
    failedChecks.push("subscription_update");
  }
  if (!sameStringSet(
      subscriptionAllowedUpdates,
      DISPATCH_PORTAL_SUBSCRIPTION_UPDATES,
  )) {
    failedChecks.push("subscription_update_fields");
  }
  if (String(subscriptionUpdate.proration_behavior || "") !== "none") {
    failedChecks.push("subscription_update_proration");
  }
  if (!dispatchPortalProductsReady(subscriptionProducts)) {
    failedChecks.push("subscription_update_products");
  }

  const reviewedProduct = subscriptionProducts.length === 1 ?
    subscriptionProducts[0] : {};
  return Object.freeze({
    ready: failedChecks.length === 0,
    configurationId,
    revision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    failedChecks: Object.freeze(failedChecks),
    features: Object.freeze({
      paymentMethodUpdate: paymentMethodUpdate.enabled === true,
      customerUpdate: customerUpdate.enabled === true,
      customerUpdateAllowedUpdates: Object.freeze(customerAllowedUpdates),
      invoiceHistory: invoiceHistory.enabled === true,
      subscriptionCancel: subscriptionCancel.enabled === true,
      subscriptionCancelMode: String(subscriptionCancel.mode || ""),
      subscriptionCancelProration:
        String(subscriptionCancel.proration_behavior || "none"),
      subscriptionUpdate: subscriptionUpdate.enabled === true,
      subscriptionUpdateAllowedUpdates:
        Object.freeze(subscriptionAllowedUpdates),
      subscriptionUpdateProration:
        String(subscriptionUpdate.proration_behavior || ""),
      subscriptionUpdateProductId: stripeObjectId(reviewedProduct.product),
      subscriptionUpdatePriceIds: Object.freeze(
          normalizedStringArray(reviewedProduct.prices),
      ),
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
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
  DISPATCH_PORTAL_SUBSCRIPTION_UPDATES,
  dispatchBillingPortalAvailable,
  dispatchBillingPortalProviderAssessment,
  dispatchBillingPortalProviderRecordReady,
  dispatchBillingPortalStoredFeaturesReady,
  dispatchPortalProductsReady,
  validStripeBillingPortalConfigurationId,
  validStripeBillingPortalUrl,
  validStripeCustomerId,
  validStripeSubscriptionId,
};
