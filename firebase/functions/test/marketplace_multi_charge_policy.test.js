"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  aggregateChargeState,
  allocateRefundAcrossCharges,
  marketplaceChargeIds,
} = require("../marketplace_multi_charge_policy");

test("marketplace charge ids include singular and split charge arrays once", () => {
  assert.deepEqual(marketplaceChargeIds({
    stripeChargeId: "ch_Deposit",
    stripeChargeIds: ["ch_Deposit", "ch_Balance"],
  }), ["ch_Deposit", "ch_Balance"]);
});

test("refund allocation uses newest charge first and then deposit", () => {
  const charges = [
    {id: "ch_Deposit", amountMinor: 25000, refundedMinor: 0},
    {id: "ch_Balance", amountMinor: 75000, refundedMinor: 10000},
  ];
  assert.deepEqual(allocateRefundAcrossCharges(70000, charges), [
    {chargeId: "ch_Balance", amountMinor: 65000},
    {chargeId: "ch_Deposit", amountMinor: 5000},
  ]);
  assert.deepEqual(aggregateChargeState(charges), {
    chargedMinor: 100000,
    refundedMinor: 10000,
    refundableMinor: 90000,
  });
});

test("refund allocation rejects over-refunds and invalid charge state", () => {
  assert.throws(
      () => allocateRefundAcrossCharges(10001, [
        {id: "ch_One", amountMinor: 10000, refundedMinor: 0},
      ]),
      TypeError,
  );
  assert.throws(
      () => aggregateChargeState([
        {id: "bad", amountMinor: 10000, refundedMinor: 0},
      ]),
      TypeError,
  );
});
