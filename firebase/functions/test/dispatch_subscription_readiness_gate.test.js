"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  requireSubscriptionReady,
} = require("../dispatch_subscription_commands");

function ready(overrides = {}) {
  return {
    stripeSubscriptionsEnabled: true,
    stripeMode: "production",
    stripeWebhookVerified: true,
    stripeSubscriptionLifecycleWebhookVerified: true,
    stripeSubscriptionRecoveryVerified: true,
    stripeReconciliationReady: true,
    stripeTaxReady: true,
    stripeTaxRegistrationPending: false,
    stripeTaxPendingBillingApproved: false,
    canadaGstHstSmallSupplier: false,
    ...overrides,
  };
}

test("Dispatch checkout requires verified subscription lifecycle webhooks", () => {
  assert.throws(
      () => requireSubscriptionReady(ready({
        stripeSubscriptionLifecycleWebhookVerified: false,
      })),
      /not enabled yet/i,
  );
});

test("Dispatch checkout requires verified subscription recovery settings", () => {
  assert.throws(
      () => requireSubscriptionReady(ready({
        stripeSubscriptionRecoveryVerified: false,
      })),
      /not enabled yet/i,
  );
});

test("Dispatch checkout accepts the complete audited readiness set", () => {
  assert.doesNotThrow(() => requireSubscriptionReady(ready()));
});
