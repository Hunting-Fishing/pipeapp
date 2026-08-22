"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  providerStateBlocksNewCheckout,
} = require("../dispatch_subscription_provider_access");

test("existing nonterminal Stripe Dispatch subscription blocks another checkout", () => {
  for (const status of [
    "active",
    "trialing",
    "incomplete",
    "past_due",
    "unpaid",
    "paused",
    "checkout_completed",
    "unknown",
  ]) {
    assert.equal(providerStateBlocksNewCheckout({
      subscriptionId: "sub_123",
      providerStatus: status,
      blocksNewCheckout: false,
    }), true, status);
  }
});

test("terminal or missing Stripe subscription state allows a new checkout", () => {
  assert.equal(providerStateBlocksNewCheckout(null), false);
  assert.equal(providerStateBlocksNewCheckout({providerStatus: "active"}), false);
  assert.equal(providerStateBlocksNewCheckout({
    subscriptionId: "sub_123",
    providerStatus: "canceled",
  }), false);
  assert.equal(providerStateBlocksNewCheckout({
    subscriptionId: "sub_123",
    providerStatus: "incomplete_expired",
  }), false);
});
