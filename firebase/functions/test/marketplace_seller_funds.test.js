"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  desiredSellerNetMinor,
  netSellerTransferredMinor,
  uniqueSellerTransferIds,
} = require("../marketplace_seller_funds");

test("desired seller net decreases proportionally with cumulative exposure", () => {
  const sale = {
    buyerChargedMinor: 105000,
    sellerProceedsMinor: 97000,
  };
  assert.equal(desiredSellerNetMinor({
    sale,
    customerExposureMinor: 52500,
  }), 48500);
  assert.equal(desiredSellerNetMinor({
    sale,
    customerExposureMinor: 105000,
  }), 0);
});

test("seller net includes restoration transfers minus their reversals", () => {
  assert.equal(netSellerTransferredMinor([
    {amountMinor: 90000, reversedMinor: 45000},
    {amountMinor: 20000, reversedMinor: 5000},
  ]), 60000);
});

test("seller transfer IDs are de-duplicated across original and restorations", () => {
  assert.deepEqual(uniqueSellerTransferIds({
    stripeSellerTransferId: "tr_original",
    sellerPayoutTransferIds: ["tr_original", "tr_restore1", "bad"],
  }), ["tr_original", "tr_restore1"]);
});
