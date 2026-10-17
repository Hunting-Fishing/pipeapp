"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchSubscriptionPlanCatalog,
  subscriptionCheckoutReady,
} = require("../dispatch_subscription_catalog");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

test("Dispatch catalog exposes launch recurring USD prices from server config", () => {
  assert.deepEqual(dispatchSubscriptionPlanCatalog(), {
    monthly: {
      currency: "USD",
      amountMinor: 2500,
      amount: 25,
      interval: "month",
    },
    yearly: {
      currency: "USD",
      amountMinor: 25000,
      amount: 250,
      interval: "year",
    },
  });
  assert.equal(
      stripeMarketplaceConfig.products.dispatchMonthlyUsd.priceId,
      "price_1UReXRDkO07WMXyRFyrSKpR4",
  );
  assert.equal(
      stripeMarketplaceConfig.products.dispatchYearlyUsd.priceId,
      "price_1UReYXDkO07WMXyRwonGROt3",
  );
});

test("catalog checkout availability uses the same readiness gate as checkout", () => {
  const ready = {
    stripeSubscriptionsEnabled: true,
    stripeMode: "production",
    stripeWebhookVerified: true,
    stripeReconciliationReady: true,
    stripeTaxReady: false,
    stripeTaxRegistrationPending: true,
    stripeTaxPendingBillingApproved: true,
  };
  assert.equal(subscriptionCheckoutReady(ready, true), true);
  assert.equal(subscriptionCheckoutReady(ready, false), false);
  assert.equal(subscriptionCheckoutReady({
    ...ready,
    stripeWebhookVerified: false,
  }, true), false);
  assert.equal(subscriptionCheckoutReady({
    ...ready,
    stripeTaxPendingBillingApproved: false,
  }, true), false);
});
