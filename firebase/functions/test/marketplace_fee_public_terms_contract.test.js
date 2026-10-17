"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  launchMarketplaceFeeSchedule,
} = require("../marketplace_fee_policy");

const termsPath = path.resolve(__dirname, "../../../web/terms.html");

test("public terms identify the server-authoritative fee schedule", () => {
  const terms = fs.readFileSync(termsPath, "utf8");
  assert.match(terms, new RegExp(launchMarketplaceFeeSchedule.revision, "u"));
  assert.match(terms, /Marketplace and Timed Buying listings are free/u);
  assert.match(terms, /USD \$1 per sold stick, joint, or item/u);
  assert.match(terms, /lower of 3% of the agreed sale value or USD \$2,500/u);
  assert.match(terms, /progressive fee of 3% on the first USD \$5,000/u);
  assert.match(terms, /USD \$1 minimum and USD \$2,500 maximum/u);
  assert.doesNotMatch(terms, /\$25 minimum and \$5,000 maximum/u);
  assert.doesNotMatch(terms, /5% for a sale below \$10,000/u);
});
