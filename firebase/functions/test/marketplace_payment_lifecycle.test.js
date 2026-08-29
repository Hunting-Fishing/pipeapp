"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  releaseEligible,
  transactionIdForAuction,
} = require("../marketplace_payment_lifecycle");

test("Timed Buying maps to one deterministic marketplace transaction id", () => {
  assert.equal(transactionIdForAuction("listing-123"), "auction_listing-123");
});

test("seller release requires paid physical-goods completion", () => {
  const paid = {
    status: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    refundedMinor: 0,
    financialHold: false,
  };
  assert.equal(releaseEligible(paid), true);
  assert.equal(releaseEligible({...paid, status: "pending_completion"}), false);
  assert.equal(releaseEligible({...paid, paymentProviderStatus: "processing"}), false);
  assert.equal(releaseEligible({...paid, refundedMinor: 1}), false);
  assert.equal(releaseEligible({...paid, disputeStatus: "open"}), false);
});

test("Timed Buying completion may release after the winner has paid", () => {
  assert.equal(releaseEligible({
    status: "pending_payment",
    auctionSettlementStatus: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    refundedMinor: 0,
  }), true);
});
