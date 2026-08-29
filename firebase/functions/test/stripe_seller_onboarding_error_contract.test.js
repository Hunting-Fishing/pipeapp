"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  stripeSellerSetupErrorMessage,
} = require("../stripe_marketplace_commands");

test("seller setup maps Connect platform profile failure to an actionable message", () => {
  assert.equal(
      stripeSellerSetupErrorMessage("connect_profile_not_submitted"),
      "Pipe Buyer must complete the Stripe Connect platform profile before seller payouts can be set up.",
  );
});

test("seller setup maps liability acknowledgement failure without exposing Stripe payloads", () => {
  assert.equal(
      stripeSellerSetupErrorMessage("account_creation_liability_unacknowledged"),
      "Pipe Buyer must acknowledge the Stripe Connect liability settings before seller payouts can be set up.",
  );
});

test("seller setup preserves an unknown sanitized Stripe code as a support reference", () => {
  assert.equal(
      stripeSellerSetupErrorMessage("configuration_creation_invalid"),
      "Stripe rejected the seller payout setup. Contact Pipe Buyer support with reference configuration_creation_invalid.",
  );
});

test("seller setup falls back safely when Stripe does not return a code", () => {
  assert.equal(
      stripeSellerSetupErrorMessage(""),
      "Stripe could not complete the seller payout setup. Try again or contact support.",
  );
});

test("seller setup normalizes and bounds Stripe error codes", () => {
  const message = stripeSellerSetupErrorMessage(
      `  ${"X".repeat(200)}  `,
  );
  assert.match(message, /^Stripe rejected the seller payout setup\./);
  assert.ok(message.length < 300);
  assert.doesNotMatch(message, /\s{2,}/);
});
