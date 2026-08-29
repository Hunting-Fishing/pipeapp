"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  allocateMarketplaceFeeAcrossParts,
  splitReleaseEligible,
} = require("../marketplace_split_seller_release");

test("marketplace fee is allocated exactly once across deposit and balance", () => {
  const allocations = allocateMarketplaceFeeAcrossParts(50000, [250000, 750000]);
  assert.equal(allocations.length, 2);
  assert.equal(allocations[0] + allocations[1], 50000);
  assert.equal(250000 - allocations[0] + 750000 - allocations[1], 950000);
});

test("rounding remainder is assigned to the final payment part", () => {
  const allocations = allocateMarketplaceFeeAcrossParts(333, [3333, 6667]);
  assert.deepEqual(allocations, [110, 223]);
  assert.equal(allocations.reduce((sum, value) => sum + value, 0), 333);
});

test("fee allocation rejects impossible inputs", () => {
  assert.throws(
      () => allocateMarketplaceFeeAcrossParts(1001, [500, 500]),
      TypeError,
  );
  assert.throws(
      () => allocateMarketplaceFeeAcrossParts(-1, [500, 500]),
      TypeError,
  );
});

test("split seller release requires paid completion without financial exposure", () => {
  const eligible = {
    status: "completed",
    paymentPlan: "deposit_balance",
    paymentPlanStatus: "active",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    financialStatus: "paid_pending_fulfillment",
    financialHold: false,
    refundedMinor: 0,
  };
  assert.equal(splitReleaseEligible(eligible), true);
  assert.equal(splitReleaseEligible({...eligible, refundedMinor: 1}), false);
  assert.equal(splitReleaseEligible({...eligible, financialHold: true}), false);
  assert.equal(splitReleaseEligible({...eligible, paymentProviderStatus: "partially_paid"}), false);
});
