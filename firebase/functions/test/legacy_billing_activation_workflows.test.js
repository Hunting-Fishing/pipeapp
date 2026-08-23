"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const workflows = [
  "activate-live-billing-pending-tax.yml",
  "retry-live-billing-activation.yml",
  "finalize-live-billing-activation.yml",
];

test("legacy billing activators cannot bypass audited payment readiness", () => {
  for (const filename of workflows) {
    const source = fs.readFileSync(
        path.join(__dirname, "../../../.github/workflows", filename),
        "utf8",
    );
    assert.match(source, /workflow_dispatch:/u, filename);
    assert.match(source, /deprecated activation path/iu, filename);
    assert.match(source, /setPaymentProviderReadiness/u, filename);
    assert.doesNotMatch(source, /productionBillingActivation/u, filename);
    assert.doesNotMatch(source, /stripeSubscriptionsEnabled:\s*true/u, filename);
    assert.doesNotMatch(source, /push:\s*\n/u, filename);
  }
});
