"use strict";

const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

const DISPATCH_SUBSCRIPTION_CATALOG_REVISION =
  "2026-08-23-p2-v1-provider-price-plan";
const DISPATCH_PRODUCT_ID =
  stripeMarketplaceConfig.products.dispatchMonthlyCad.productId;

function objectId(value) {
  if (typeof value === "string") return value.trim();
  return String(value && value.id || "").trim();
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

function catalogAssessment({priceId = "", productId = "", quantity = null} = {}) {
  const failedChecks = [];
  const plan = dispatchPlanForPriceId(priceId);
  if (!plan) failedChecks.push("dispatch_price");
  if (productId && productId !== DISPATCH_PRODUCT_ID) {
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

function dispatchSubscriptionCatalogAssessment(subscription) {
  const items = subscriptionItems(subscription);
  if (items.length !== 1) {
    const assessment = catalogAssessment();
    return Object.freeze({
      ...assessment,
      failedChecks: Object.freeze([
        "subscription_item_count",
        ...assessment.failedChecks,
      ]),
      ready: false,
    });
  }
  const item = items[0];
  return catalogAssessment({
    priceId: subscriptionItemPriceId(item),
    productId: subscriptionItemProductId(item),
    quantity: Number(item && item.quantity),
  });
}

function invoiceLines(invoice) {
  const data = invoice && invoice.lines && invoice.lines.data;
  return Array.isArray(data) ? data : [];
}

function invoiceLinePriceId(line) {
  const direct = objectId(line && (line.price || line.plan));
  if (direct) return direct;
  const priceDetails = line && line.pricing && line.pricing.price_details;
  return objectId(priceDetails && priceDetails.price);
}

function invoiceLineProductId(line) {
  const price = line && line.price;
  if (price && typeof price === "object") {
    const product = objectId(price.product);
    if (product) return product;
  }
  const plan = line && line.plan;
  if (plan && typeof plan === "object") {
    const product = objectId(plan.product);
    if (product) return product;
  }
  const priceDetails = line && line.pricing && line.pricing.price_details;
  return objectId(priceDetails && priceDetails.product);
}

function dispatchInvoiceCatalogAssessment(invoice) {
  const lines = invoiceLines(invoice);
  const dispatchLines = lines.filter((line) =>
    Boolean(dispatchPlanForPriceId(invoiceLinePriceId(line))));
  if (dispatchLines.length !== 1) {
    return Object.freeze({
      ready: false,
      revision: DISPATCH_SUBSCRIPTION_CATALOG_REVISION,
      failedChecks: Object.freeze(["dispatch_invoice_line_count"]),
      plan: "",
      priceId: "",
      productId: "",
      quantity: null,
    });
  }
  const line = dispatchLines[0];
  const assessment = catalogAssessment({
    priceId: invoiceLinePriceId(line),
    productId: invoiceLineProductId(line),
    quantity: Number(line && line.quantity),
  });
  return Object.freeze({
    ...assessment,
    failedChecks: assessment.failedChecks,
  });
}

module.exports = {
  DISPATCH_PRODUCT_ID,
  DISPATCH_SUBSCRIPTION_CATALOG_REVISION,
  catalogAssessment,
  dispatchInvoiceCatalogAssessment,
  dispatchPlanForPriceId,
  dispatchSubscriptionCatalogAssessment,
  invoiceLinePriceId,
  invoiceLineProductId,
  invoiceLines,
  objectId,
  subscriptionItemPriceId,
  subscriptionItemProductId,
  subscriptionItems,
};
