"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  isContingentDisputeTransaction,
} = require("../affiliate_payouts");

test("open marketplace disputes are contingent affiliate exposure", () => {
  assert.equal(isContingentDisputeTransaction({
    financialStatus: "disputed",
    activeDisputeIds: ["du_123"],
  }), true);
  assert.equal(isContingentDisputeTransaction({
    financialStatus: "settled",
    activeDisputeIds: ["du_123"],
  }), true);
});

test("finalized chargebacks and refunds are not contingent disputes", () => {
  assert.equal(isContingentDisputeTransaction({
    financialStatus: "charged_back",
    activeDisputeIds: [],
  }), false);
  assert.equal(isContingentDisputeTransaction({
    financialStatus: "refunded",
    activeDisputeIds: [],
  }), false);
  assert.equal(isContingentDisputeTransaction(null), false);
});
