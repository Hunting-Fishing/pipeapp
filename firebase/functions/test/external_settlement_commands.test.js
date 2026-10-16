"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  externalFeeCheckoutIdempotencyKey,
  nextExternalFeeCheckoutAttempt,
} = require("../external_settlement_commands");

test("external fee checkout attempts increment independently of transaction revision", () => {
  assert.equal(nextExternalFeeCheckoutAttempt({revision: 99}), 1);
  assert.equal(nextExternalFeeCheckoutAttempt({
    revision: 100,
    marketplaceFeeCheckoutAttempt: 1,
  }), 2);
  assert.equal(nextExternalFeeCheckoutAttempt({
    revision: 101,
    marketplaceFeeCheckoutAttempt: 7,
  }), 8);
});

test("external fee idempotency key is stable for a checkout attempt", () => {
  const transactionId = "txn_123";
  assert.equal(
      externalFeeCheckoutIdempotencyKey(transactionId, 1),
      "pipebuyer-external-fee-txn_123-attempt-1",
  );
  assert.equal(
      externalFeeCheckoutIdempotencyKey(transactionId, 2),
      "pipebuyer-external-fee-txn_123-attempt-2",
  );
});
