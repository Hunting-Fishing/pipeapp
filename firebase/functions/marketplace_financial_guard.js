"use strict";

function stripeMarketplaceChargeIds(sale = {}) {
  const candidates = [
    String(sale.stripeChargeId || ""),
    ...(Array.isArray(sale.stripeChargeIds) ?
      sale.stripeChargeIds.map((value) => String(value || "")) : []),
  ];
  return [...new Set(candidates.filter((value) =>
    /^ch_[A-Za-z0-9]+$/u.test(value),
  ))];
}

function hasStripeMarketplaceCharge(sale) {
  return stripeMarketplaceChargeIds(sale).length > 0;
}

function hasMarketplacePaymentExposure(sale = {}) {
  return hasStripeMarketplaceCharge(sale) ||
    (String(sale.paymentProvider || "") === "stripe" &&
      Number.isSafeInteger(Number(sale.amountPaidMinor || 0)) &&
      Number(sale.amountPaidMinor || 0) > 0);
}

function isFullyRefundedMarketplaceCharge(sale) {
  if (!hasMarketplacePaymentExposure(sale)) return false;
  const charged = Number(sale && sale.buyerChargedMinor || 0);
  const refunded = Number(sale && sale.refundedMinor || 0);
  return Number.isSafeInteger(charged) && charged > 0 &&
    Number.isSafeInteger(refunded) && refunded >= charged;
}

function cancellationRequiresFinancialResolution(sale) {
  return hasMarketplacePaymentExposure(sale) &&
    !isFullyRefundedMarketplaceCharge(sale);
}

module.exports = {
  cancellationRequiresFinancialResolution,
  hasMarketplacePaymentExposure,
  hasStripeMarketplaceCharge,
  isFullyRefundedMarketplaceCharge,
  stripeMarketplaceChargeIds,
};
