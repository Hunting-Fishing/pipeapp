"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  FULL_GMV_ECONOMICS_MODEL,
  requireFullGmvCheckoutEconomics,
} = require("../marketplace_checkout_economics");

function approvedReadiness(overrides = {}) {
  return {
    stripeFullGmvEconomicsApproved: true,
    stripeFullGmvEconomicsPolicyRevision: "finance-approved-2026-10-17",
    stripeFullGmvPaymentMethodConfigurationId: "pmc_approvedRail1",
    stripeFullGmvMaximumChargeMinorUsd: 1000000,
    stripeFullGmvMaximumProviderFeeBps: 200,
    stripeFullGmvMaximumProviderFeeFixedMinorUsd: 30,
    stripeFullGmvMaximumTaxUpliftBps: 2500,
    stripeFullGmvMinimumNetRevenueMinorUsd: 100,
    ...overrides,
  };
}

function feeSnapshot(overrides = {}) {
  return {
    currency: "USD",
    agreedTotalMinor: 100000,
    marketplaceFeeMinor: 30000,
    affiliateCommissionMinor: 6000,
    ...overrides,
  };
}

test("full-GMV checkout economics fail closed without explicit approval", () => {
  assert.throws(
      () => requireFullGmvCheckoutEconomics({
        readiness: {},
        feeSnapshot: feeSnapshot(),
      }),
      /economics are approved/i,
  );
});

test("full-GMV checkout economics require an approved Stripe payment-method configuration", () => {
  assert.throws(
      () => requireFullGmvCheckoutEconomics({
        readiness: approvedReadiness({
          stripeFullGmvPaymentMethodConfigurationId: "",
        }),
        feeSnapshot: feeSnapshot(),
      }),
      /payment-method configuration/i,
  );
});

test("full-GMV checkout declines currencies and amounts outside the approved rail", () => {
  assert.throws(
      () => requireFullGmvCheckoutEconomics({
        readiness: approvedReadiness(),
        feeSnapshot: feeSnapshot({currency: "CAD"}),
      }),
      /not eligible/i,
  );
  assert.throws(
      () => requireFullGmvCheckoutEconomics({
        readiness: approvedReadiness(),
        feeSnapshot: feeSnapshot({agreedTotalMinor: 1000001}),
      }),
      /exceeds the approved/i,
  );
});

test("full-GMV checkout declines when the retained fee cannot cover the configured cost ceiling and margin", () => {
  assert.throws(
      () => requireFullGmvCheckoutEconomics({
        readiness: approvedReadiness(),
        feeSnapshot: feeSnapshot({
          agreedTotalMinor: 500000,
          marketplaceFeeMinor: 12661,
          affiliateCommissionMinor: 2532,
        }),
      }),
      /not economical/i,
  );
});

test("full-GMV checkout returns an auditable economics decision", () => {
  const decision = requireFullGmvCheckoutEconomics({
    readiness: approvedReadiness(),
    feeSnapshot: feeSnapshot({
      agreedTotalMinor: 500000,
      marketplaceFeeMinor: 15000,
      affiliateCommissionMinor: 3000,
    }),
  });
  assert.equal(decision.model, FULL_GMV_ECONOMICS_MODEL);
  assert.equal(decision.currency, "USD");
  assert.equal(decision.configuredProviderCostCeilingMinor, 10030);
  assert.equal(decision.requiredMarketplaceFeeMinor, 10130);
  assert.equal(decision.retainedFeeBeforeProviderCostsMinor, 12000);
  assert.equal(decision.projectedMinimumNetPlatformRevenueMinor, 1970);
});

test("automatic tax applies the approved tax uplift to the provider cost base", () => {
  const decision = requireFullGmvCheckoutEconomics({
    readiness: approvedReadiness({stripeTaxReady: true}),
    feeSnapshot: feeSnapshot({
      agreedTotalMinor: 500000,
      marketplaceFeeMinor: 16000,
      affiliateCommissionMinor: 3000,
    }),
  });
  assert.equal(decision.maximumTaxUpliftBpsApplied, 2500);
  assert.equal(decision.providerCostBaseMinor, 625000);
  assert.equal(decision.configuredProviderCostCeilingMinor, 12530);
  assert.equal(decision.projectedMinimumNetPlatformRevenueMinor, 470);
});
