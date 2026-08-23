"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  externalFeeCheckoutAttempt,
  externalFeeCheckoutIdempotencyKey,
  externalFeeCheckoutSessionId,
  externalFeeCheckoutState,
  nextExternalFeeCheckoutAttempt,
} = require("../external_settlement_fee_checkout_policy");

test("fee checkout attempt numbers are bounded server values", () => {
  assert.equal(externalFeeCheckoutAttempt({}), 0);
  assert.equal(externalFeeCheckoutAttempt({marketplaceFeeCheckoutAttempt: -1}), 0);
  assert.equal(externalFeeCheckoutAttempt({marketplaceFeeCheckoutAttempt: 2}), 2);
  assert.equal(nextExternalFeeCheckoutAttempt({marketplaceFeeCheckoutAttempt: 2}), 3);
});

test("active fee checkout requires a valid stored Stripe session", () => {
  assert.equal(externalFeeCheckoutState({
    marketplaceFeeStatus: "checkout_created",
    stripeMarketplaceFeeSessionId: "cs_live_123",
  }), "active");
  assert.equal(externalFeeCheckoutState({
    marketplaceFeeStatus: "processing",
    stripeMarketplaceFeeSessionId: "cs_live_123",
  }), "active");
  assert.equal(externalFeeCheckoutState({
    marketplaceFeeStatus: "processing",
  }), "inconsistent");
});

test("failed or expired-local fee checkout state advances to a new attempt", () => {
  const failed = {
    marketplaceFeeStatus: "payment_failed",
    marketplaceFeeCheckoutAttempt: 1,
    stripeMarketplaceFeeSessionId: "cs_old_123",
  };
  assert.equal(externalFeeCheckoutState(failed), "create");
  assert.equal(nextExternalFeeCheckoutAttempt(failed), 2);
});

test("collected fee never creates a new checkout", () => {
  assert.equal(externalFeeCheckoutState({
    marketplaceFeeStatus: "collected",
    stripeMarketplaceFeeSessionId: "cs_paid_123",
  }), "paid");
});

test("session and idempotency helpers reject malformed inputs", () => {
  assert.equal(externalFeeCheckoutSessionId({
    stripeMarketplaceFeeSessionId: "not-a-session",
  }), "");
  assert.equal(
      externalFeeCheckoutIdempotencyKey("transaction-1", 2),
      "pipebuyer-external-fee-transaction-1-attempt-2",
  );
  assert.throws(() => externalFeeCheckoutIdempotencyKey("bad/id", 1));
  assert.throws(() => externalFeeCheckoutIdempotencyKey("transaction-1", 0));
});
