"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  cancellationRequiresFinancialResolution,
  isFullyRefundedMarketplaceCharge,
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
