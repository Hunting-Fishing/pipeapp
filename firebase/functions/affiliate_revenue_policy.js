"use strict";

const BASIS_POINTS = 10000;
const AFFILIATE_SHARE_BPS = 500;

// Stripe Billing is currently a variable platform cost. Keep a conservative
// reserve in the commission base so affiliate economics never assume the
// entire pre-tax subscription price is Pipe Buyer net revenue. The reserve is
// intentionally higher than the present pay-as-you-go Billing percentage and
// can be revised in a future immutable policy revision.
const DISPATCH_BILLING_COST_RESERVE_BPS = 100;
const AFFILIATE_REVENUE_POLICY_REVISION = "2026-08-10-net-revenue-5pct-v1";

function minor(value, field) {
  const amount = Number(value || 0);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new TypeError(`${field} must be a non-negative integer in minor units.`);
  }
  return amount;
}

function bps(value, field) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount < 0 || amount > BASIS_POINTS) {
    throw new TypeError(`${field} must be valid basis points.`);
  }
  return amount;
}

function reserveMinor(amountMinor, reserveBps) {
  const amount = minor(amountMinor, "Revenue amount");
  const rate = bps(reserveBps, "Reserve rate");
  if (amount === 0 || rate === 0) return 0;
  return Math.ceil(amount * rate / BASIS_POINTS);
}

function dispatchBillingCostReserveMinor(revenueMinor) {
  return reserveMinor(revenueMinor, DISPATCH_BILLING_COST_RESERVE_BPS);
}

function affiliateEconomics({
  grossPlatformRevenueMinor,
  paymentProviderFeeMinor = 0,
  providerFeeRecoveredMinor = 0,
  billingCostReserveMinor = 0,
  provisionalTaxReserveMinor = 0,
  refundLossMinor = 0,
  chargebackLossMinor = 0,
  creditsMinor = 0,
  otherPassThroughCostMinor = 0,
  shareBps = AFFILIATE_SHARE_BPS,
}) {
  const gross = minor(grossPlatformRevenueMinor, "Gross platform revenue");
  const providerFee = minor(paymentProviderFeeMinor, "Payment provider fee");
  const recoveredProviderFee = Math.min(
      providerFee,
      minor(providerFeeRecoveredMinor, "Recovered provider fee"),
  );
  const unrecoveredProviderFeeMinor = Math.max(
      0,
      providerFee - recoveredProviderFee,
  );
  const billingReserve = minor(billingCostReserveMinor, "Billing cost reserve");
  const taxReserve = minor(provisionalTaxReserveMinor, "Tax reserve");
  const refunds = minor(refundLossMinor, "Refund loss");
  const chargebacks = minor(chargebackLossMinor, "Chargeback loss");
  const credits = minor(creditsMinor, "Credits");
  const passThrough = minor(otherPassThroughCostMinor, "Pass-through cost");
  const rate = bps(shareBps, "Affiliate share");
  const deductionsMinor =
    unrecoveredProviderFeeMinor +
    billingReserve +
    taxReserve +
    refunds +
    chargebacks +
    credits +
    passThrough;
  const commissionableRevenueMinor = Math.max(0, gross - deductionsMinor);
  const commissionMinor = Math.floor(
      commissionableRevenueMinor * rate / BASIS_POINTS,
  );
  return Object.freeze({
    policyRevision: AFFILIATE_REVENUE_POLICY_REVISION,
    shareBps: rate,
    grossPlatformRevenueMinor: gross,
    paymentProviderFeeMinor: providerFee,
    providerFeeRecoveredMinor: recoveredProviderFee,
    unrecoveredProviderFeeMinor,
    billingCostReserveMinor: billingReserve,
    provisionalTaxReserveMinor: taxReserve,
    refundLossMinor: refunds,
    chargebackLossMinor: chargebacks,
    creditsMinor: credits,
    otherPassThroughCostMinor: passThrough,
    deductionsMinor,
    commissionableRevenueMinor,
    commissionMinor,
  });
}

module.exports = {
  AFFILIATE_REVENUE_POLICY_REVISION,
  AFFILIATE_SHARE_BPS,
  BASIS_POINTS,
  DISPATCH_BILLING_COST_RESERVE_BPS,
  affiliateEconomics,
  dispatchBillingCostReserveMinor,
  reserveMinor,
};
