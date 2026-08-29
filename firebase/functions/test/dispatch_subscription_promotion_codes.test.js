"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  CHECKOUT_CONFIGURATION_VERSION,
  promotionCodeEntryAllowed,
  reusableCheckoutState,
} = require("../dispatch_subscription_commands");

test("customer promotion codes are limited to undiscounted monthly Dispatch checkout", () => {
  assert.equal(promotionCodeEntryAllowed("monthly", null), true);
  assert.equal(promotionCodeEntryAllowed("monthly", ""), true);
  assert.equal(
      promotionCodeEntryAllowed("monthly", "PIPEBUYER_FREE_1Y"),
      false,
  );
  assert.equal(promotionCodeEntryAllowed("yearly", null), false);
});

test("stale Checkout sessions are not reused after promo configuration changes", () => {
  const now = Date.now();
  const baseState = {
    plan: "monthly",
    status: "created",
    expiresAt: now + 60_000,
    checkoutSessionId: "cs_live_test",
    checkoutUrl: "https://checkout.stripe.com/c/pay/test",
  };

  assert.equal(reusableCheckoutState(baseState, "monthly", now), false);
  assert.equal(reusableCheckoutState({
    ...baseState,
    checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION,
  }, "monthly", now), true);
});
