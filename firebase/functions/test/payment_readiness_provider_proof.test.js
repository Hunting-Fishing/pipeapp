"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyPatch,
  normalizeReadiness,
} = require("../payment_readiness_admin");

test("lifecycle webhook readiness cannot be manually declared true", () => {
  const current = normalizeReadiness({stripeMode: "disabled"});
  assert.throws(
      () => applyPatch(current, {
        stripeSubscriptionLifecycleWebhookVerified: true,
      }),
      /only be enabled by live Stripe endpoint verification/i,
  );
});

test("administrator can revoke lifecycle readiness immediately", () => {
  const current = normalizeReadiness({
    stripeMode: "disabled",
    stripeSubscriptionLifecycleWebhookVerified: true,
  });
  const next = applyPatch(current, {
    stripeSubscriptionLifecycleWebhookVerified: false,
  });
  assert.equal(next.stripeSubscriptionLifecycleWebhookVerified, false);
});
