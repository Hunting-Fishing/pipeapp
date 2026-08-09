"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  adjustedAffiliateCommission,
  proportionalRecoveryTarget,
  refundReasonCode,
} = require("../marketplace_financial_resolution");

test("seller recovery scales proportionally and reaches the full transfer", () => {
  assert.equal(proportionalRecoveryTarget({
    transferAmountMinor: 97000,
    originalChargeAmountMinor: 105000,
    customerExposureMinor: 52500,
  }), 48500);
  assert.equal(proportionalRecoveryTarget({
    transferAmountMinor: 97000,
    originalChargeAmountMinor: 105000,
    customerExposureMinor: 105000,
  }), 97000);
});

test("cumulative partial exposure never over-recovers seller proceeds", () => {
  const first = proportionalRecoveryTarget({
    transferAmountMinor: 90000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 25000,
  });
  const second = proportionalRecoveryTarget({
    transferAmountMinor: 90000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 60000,
  });
  assert.equal(first, 22500);
  assert.equal(second, 54000);
  assert.equal(second - first, 31500);
});

test("affiliate commission is reduced by financial exposure", () => {
  assert.equal(adjustedAffiliateCommission({
    commissionMinor: 2000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 25000,
  }), 1500);
  assert.equal(adjustedAffiliateCommission({
    commissionMinor: 2000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 100000,
  }), 0);
});

test("refund reason codes are restricted to Stripe-supported values", () => {
  assert.equal(refundReasonCode("fraudulent"), "fraudulent");
  assert.equal(refundReasonCode("duplicate"), "duplicate");
  assert.equal(refundReasonCode("seller_requested"), "requested_by_customer");
});
