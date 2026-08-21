"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchSubscriptionPlanCatalog,
  subscriptionCheckoutReady,
} = require("../dispatch_subscription_catalog");

test("Dispatch catalog exposes launch recurring CAD prices from server config", () => {
  assert.deepEqual(dispatchSubscriptionPlanCatalog(), {
    monthly: {
      currency: "CAD",
      amountMinor: 2500,
      amount: 25,
      interval: "month",
    },
    yearly: {
      currency: "CAD",
      amountMinor: 30000,
      amount: 300,
      interval: "year",
    },
  });
});

test("catalog checkout availability uses the same readiness gate as checkout", () => {
  const ready = {
    stripeSubscriptionsEnabled: true,
    stripeMode: "production",
    stripeWebhookVerified: true,
    stripeReconciliationReady: true,
    stripeTaxReady: false,
    stripeTaxRegistrationPending: true,
  };
  assert.equal(subscriptionCheckoutReady(ready, true), true);
  assert.equal(subscriptionCheckoutReady(ready, false), false);
  assert.equal(subscriptionCheckoutReady({
    ...ready,
    stripeWebhookVerified: false,
  }, true), false);
});
