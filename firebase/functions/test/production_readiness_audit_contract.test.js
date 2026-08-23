"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

test("production readiness audit verifies Dispatch provider controls", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "../../../.github/workflows/production-readiness-audit.yml"),
      "utf8",
  );
  assert.match(source, /\/v1\/billing_portal\/configurations\?limit=100/u);
  assert.match(source, /payment_method_update/u);
  assert.match(source, /invoice_history/u);
  assert.match(source, /subscription_cancel/u);
  assert.match(source, /at_period_end/u);
  assert.match(source, /proration_behavior/u);
  assert.match(source, /subscription_update/u);
  assert.match(source, /enabled === false/u);
  assert.match(source, /invoice\.paid/u);
  assert.match(source, /invoice\.payment_failed/u);
  assert.match(source, /customer\.subscription\.updated/u);
  assert.match(source, /customer\.subscription\.deleted/u);
  assert.match(source, /getDispatchSubscriptionLaunchReadiness/u);
  assert.match(source, /verifyDispatchBillingPortalConfiguration/u);
  assert.match(source, /verifyDispatchSubscriptionLifecycleWebhook/u);
  assert.match(source, /createDispatchBillingPortalSession/u);
  assert.match(source, /reconcileDispatchSubscriptionInvoice/u);
  assert.match(source, /No launch-safe live Stripe Billing Portal configuration exists/u);
  assert.match(source, /Dispatch subscription webhook events are incomplete/u);
});
