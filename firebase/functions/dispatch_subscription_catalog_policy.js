"use strict";

const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

const DISPATCH_SUBSCRIPTION_CATALOG_REVISION =
  "2026-08-23-p2-v1-provider-price-plan";

function objectId(value) {
  if (typeof value === "string") return value.trim();
  return String(value && value.id || "").trim();
}

function subscriptionItems(subscription) {
  const data = subscription && subscription.items && subscription.items.data;
  return Array.isArray(data) ? data : [];
}

function subscriptionItemPriceId(item) {
  return objectId(item && (item.price || item.plan));
}

function subscriptionItemProductId(item) {
  const price = item && item.price;
  if (price && typeof price === "object") {
    return objectId(price.product);
  }
  const plan = item && item.plan;
  if (plan && typeof plan === "object") {
    return objectId(plan.product);
  }
  return "";
}

function dispatchPlanForPriceId(priceId) {
  const id = String(priceId || "").trim();
  if (id === stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId) {
    return "monthly";
  }
  if (id === stripeMarketplaceConfig.products.dispatchYearlyCad.priceId) {
    return "yearly";
  }
  return "";
}

function dispatchSubscriptionCatalogAssessment(subscription) {
  const items = subscriptionItems(subscription);
  const failedChecks = [];
  if (items.length !== 1) failedChecks.push("subscription_item_count");
  const item = items.length === 1 ? items[0] : {};
  const priceId = subscriptionItemPriceId(item);
  const productId = subscriptionItemProductId(item);
  const plan = dispatchPlanForPriceId(priceId);
  const quantity = Number(item && item.quantity);
  const expectedProductId =
    stripeMarketplaceConfig.products.dispatchMonthlyCad.productId;

  if (!plan) failedChecks.push("dispatch_price");
  // Stripe can return the Price as only an ID in some fixture/provider shapes.
  // When the expanded Price exposes its Product, require the exact canonical
  // Dispatch Product. A conflicting product is never accepted.
  if (productId && productId !== expectedProductId) {
    failedChecks.push("dispatch_product");
  }
  if (!Number.isSafeInteger(quantity) || quantity !== 1) {
    failedChecks.push("subscription_quantity");
  }

  return Object.freeze({
    ready: failedChecks.length === 0,
    revision: DISPATCH_SUBSCRIPTION_CATALOG_REVISION,
    failedChecks: Object.freeze(failedChecks),
    plan,
    priceId,
    productId,
    quantity: Number.isSafeInteger(quantity) ? quantity : null,
  });
}

module.exports = {
  DISPATCH_SUBSCRIPTION_CATALOG_REVISION,
  dispatchPlanForPriceId,
  dispatchSubscriptionCatalogAssessment,
  objectId,
  subscriptionItemPriceId,
  subscriptionItemProductId,
  subscriptionItems,
};
