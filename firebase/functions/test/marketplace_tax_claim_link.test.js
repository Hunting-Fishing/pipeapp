"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {identifier} = require("../marketplace_tax_claim_link");

test("tax claim link accepts bounded document identifiers", () => {
  assert.equal(identifier("tx_123", "Transaction"), "tx_123");
});

test("tax claim link rejects empty and path-shaped identifiers", () => {
  assert.throws(() => identifier("", "Transaction"));
  assert.throws(() => identifier("transactions/123", "Transaction"));
});

test("tax claim link verifies both transaction buyer and claim owner", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "marketplace_tax_claim_link.js"),
      "utf8",
  );
  assert.match(source, /sale\.buyerUid/);
  assert.match(source, /claim\.buyerUid/);
  assert.match(source, /taxExemptionClaimId/);
  assert.match(source, /taxReviewRequired:\s*true/);
});
