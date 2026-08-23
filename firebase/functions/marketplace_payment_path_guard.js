"use strict";

const STRIPE_MARKETPLACE_ACTIVE_STATUSES = Object.freeze(new Set([
  "checkout_created",
  "processing",
  "paid",
]));

const EXTERNAL_FEE_ACTIVE_STATUSES = Object.freeze(new Set([
  "pending_collection",
  "checkout_created",
  "processing",
  "collected",
]));

function hasStartedStripeMarketplaceCheckout(sale) {
  if (!sale || typeof sale !== "object") return false;
  const providerStatus = String(sale.paymentProviderStatus || "").trim();
  return String(sale.paymentMethod || "").trim() === "stripe_checkout" ||
    Boolean(String(sale.stripeCheckoutSessionId || "").trim()) ||
    Boolean(String(sale.stripePaymentIntentId || "").trim()) ||
    Boolean(String(sale.stripeChargeId || "").trim()) ||
    STRIPE_MARKETPLACE_ACTIVE_STATUSES.has(providerStatus);
}

function hasStartedExternalSettlement(sale) {
  if (!sale || typeof sale !== "object") return false;
  const feeStatus = String(sale.marketplaceFeeStatus || "").trim();
  return String(sale.paymentMethod || "").trim() === "external_settlement" ||
    sale.externalSettlementBuyerConfirmed === true ||
    sale.externalSettlementSellerConfirmed === true ||
    Boolean(String(sale.stripeMarketplaceFeeSessionId || "").trim()) ||
    Boolean(String(sale.stripeMarketplaceFeePaymentIntentId || "").trim()) ||
    Boolean(String(sale.stripeMarketplaceFeeChargeId || "").trim()) ||
    EXTERNAL_FEE_ACTIVE_STATUSES.has(feeStatus);
}

function externalSettlementFullyConfirmed(sale) {
  return Boolean(sale &&
    sale.externalSettlementBuyerConfirmed === true &&
    sale.externalSettlementSellerConfirmed === true &&
    String(sale.paymentMethod || "").trim() === "external_settlement");
}

module.exports = {
  EXTERNAL_FEE_ACTIVE_STATUSES,
  STRIPE_MARKETPLACE_ACTIVE_STATUSES,
  externalSettlementFullyConfirmed,
  hasStartedExternalSettlement,
  hasStartedStripeMarketplaceCheckout,
};
