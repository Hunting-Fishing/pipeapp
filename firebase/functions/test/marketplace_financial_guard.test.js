"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  cancellationRequiresFinancialResolution,
  hasMarketplacePaymentExposure,
  isFullyRefundedMarketplaceCharge,
  stripeMarketplaceChargeIds,
} = require("../marketplace_financial_guard");

test("paid Stripe transactions cannot cancel before a full refund", () => {
  assert.equal(cancellationRequiresFinancialResolution({
    stripeChargeId: "ch_Paid123",
    buyerChargedMinor: 100000,
    refundedMinor: 0,
  }), true);
  assert.equal(cancellationRequiresFinancialResolution({
    stripeChargeId: "ch_Paid123",
    buyerChargedMinor: 100000,
    refundedMinor: 25000,
  }), true);
});

test("split and partially paid Stripe transactions are real financial exposure", () => {
  const sale = {
    paymentProvider: "stripe",
    paymentProviderStatus: "partially_paid",
    amountPaidMinor: 25000,
    buyerChargedMinor: 25000,
    stripeChargeIds: ["ch_Deposit123"],
    refundedMinor: 0,
  };
  assert.deepEqual(stripeMarketplaceChargeIds(sale), ["ch_Deposit123"]);
  assert.equal(hasMarketplacePaymentExposure(sale), true);
  assert.equal(cancellationRequiresFinancialResolution(sale), true);
});

test("fully refunded split payment can enter normal cancellation flow", () => {
  const sale = {
    paymentProvider: "stripe",
    amountPaidMinor: 25000,
    stripeChargeIds: ["ch_Deposit123"],
    buyerChargedMinor: 25000,
    refundedMinor: 25000,
  };
  assert.equal(isFullyRefundedMarketplaceCharge(sale), true);
  assert.equal(cancellationRequiresFinancialResolution(sale), false);
});

test("fully refunded Stripe transactions can enter normal cancellation flow", () => {
  const sale = {
    stripeChargeId: "ch_Paid123",
    buyerChargedMinor: 100000,
    refundedMinor: 100000,
  };
  assert.equal(isFullyRefundedMarketplaceCharge(sale), true);
  assert.equal(cancellationRequiresFinancialResolution(sale), false);
});

test("unpaid or external transactions keep the existing cancellation policy", () => {
  assert.equal(cancellationRequiresFinancialResolution({
    paymentMethod: "external_settlement",
    stripeChargeId: null,
  }), false);
});
