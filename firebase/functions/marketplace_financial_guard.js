"use strict";

function hasStripeMarketplaceCharge(sale) {
  return /^ch_[A-Za-z0-9]+$/u.test(String(sale && sale.stripeChargeId || ""));
}

function isFullyRefundedMarketplaceCharge(sale) {
  if (!hasStripeMarketplaceCharge(sale)) return false;
  const charged = Number(sale && sale.buyerChargedMinor || 0);
  const refunded = Number(sale && sale.refundedMinor || 0);
  return Number.isSafeInteger(charged) && charged > 0 &&
    Number.isSafeInteger(refunded) && refunded >= charged;
}

function cancellationRequiresFinancialResolution(sale) {
  return hasStripeMarketplaceCharge(sale) &&
    !isFullyRefundedMarketplaceCharge(sale);
}

module.exports = {
  cancellationRequiresFinancialResolution,
  hasStripeMarketplaceCharge,
  isFullyRefundedMarketplaceCharge,
};
