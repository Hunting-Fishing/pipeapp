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
  assert.match(source, /invoice\.paid/u);
  assert.match(source, /invoice\.payment_failed/u);
  assert.match(source, /customer\.subscription\.updated/u);
  assert.match(source, /customer\.subscription\.deleted/u);
  assert.match(source, /No live Stripe Billing Portal configuration exists/u);
  assert.match(source, /Dispatch subscription webhook events are incomplete/u);
});
