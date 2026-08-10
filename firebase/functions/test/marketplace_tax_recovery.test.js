"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  RESPONSIBLE_PARTIES,
  TAX_TYPES,
} = require("../marketplace_tax_recovery");

test("tax recovery supports buyer seller and shared responsibility", () => {
  assert.deepEqual(
      [...RESPONSIBLE_PARTIES].sort(),
      ["both", "buyer", "seller"],
  );
});

test("tax recovery supports Canadian and international tax categories", () => {
  for (const required of ["gst_hst", "bc_pst", "qst", "us_sales_tax", "vat"]) {
    assert.equal(TAX_TYPES.has(required), true, required);
  }
});

test("tax recovery case imposes compliance and seller payout holds", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "marketplace_tax_recovery.js"),
      "utf8",
  );
  assert.match(source, /taxComplianceHold:\s*true/);
  assert.match(source, /sellerPayoutHold:\s*true/);
  assert.match(source, /marketplace_tax_recovery_obligations/);
  assert.match(source, /tax_compliance_events/);
});

test("tax recovery never silently charges a stored buyer payment method", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "marketplace_tax_recovery.js"),
      "utf8",
  );
  assert.doesNotMatch(source, /payment_intents/);
  assert.doesNotMatch(source, /charge.*customer/i);
});
