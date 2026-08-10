"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  AFFILIATE_SHARE_BPS,
  affiliateEconomics,
  dispatchBillingCostReserveMinor,
} = require("../affiliate_revenue_policy");

test("affiliate share is five percent", () => {
  assert.equal(AFFILIATE_SHARE_BPS, 500);
  const economics = affiliateEconomics({grossPlatformRevenueMinor: 10000});
  assert.equal(economics.commissionableRevenueMinor, 10000);
  assert.equal(economics.commissionMinor, 500);
});

test("customer tax and seller proceeds are not inputs to affiliate revenue", () => {
  const economics = affiliateEconomics({
    grossPlatformRevenueMinor: 2500,
    paymentProviderFeeMinor: 500,
    providerFeeRecoveredMinor: 500,
  });
  assert.equal(economics.commissionableRevenueMinor, 2500);
  assert.equal(economics.commissionMinor, 125);
});

test("unrecovered Stripe fees reduce eligible Pipe Buyer revenue", () => {
  const economics = affiliateEconomics({
    grossPlatformRevenueMinor: 2500,
    paymentProviderFeeMinor: 600,
    providerFeeRecoveredMinor: 100,
  });
  assert.equal(economics.unrecoveredProviderFeeMinor, 500);
  assert.equal(economics.commissionableRevenueMinor, 2000);
  assert.equal(economics.commissionMinor, 100);
});

test("tax reserves refunds and chargebacks can reduce commission to zero", () => {
  const economics = affiliateEconomics({
    grossPlatformRevenueMinor: 2500,
    provisionalTaxReserveMinor: 500,
    refundLossMinor: 1000,
    chargebackLossMinor: 1000,
  });
  assert.equal(economics.commissionableRevenueMinor, 0);
  assert.equal(economics.commissionMinor, 0);
});

test("Dispatch reserves one percent for variable Billing cost", () => {
  assert.equal(dispatchBillingCostReserveMinor(2500), 25);
  assert.equal(dispatchBillingCostReserveMinor(30000), 300);
});
