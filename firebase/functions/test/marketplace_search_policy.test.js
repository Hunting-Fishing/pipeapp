"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildMarketplaceSearchTokens,
  normalizeMarketplaceSearchText,
  searchIndexVersion,
} = require("../marketplace_listing_policy");

test("marketplace search normalization is bounded and deterministic", () => {
  assert.equal(
      normalizeMarketplaceSearchText("  CAT-320 Hydraulic Excavator extra "),
      "cat 320 hydraulic",
  );
  assert.equal(normalizeMarketplaceSearchText("A"), "a");
  assert.equal(searchIndexVersion, 2);
  assert.equal(
      normalizeMarketplaceSearchText("Montréal, Québec"),
      "montreal quebec",
  );
  assert.equal(normalizeMarketplaceSearchText("México"), "mexico");
});

test("listing index supports prefixes and adjacent industrial terms", () => {
  const tokens = buildMarketplaceSearchTokens({
    title: "CAT 320 Hydraulic Excavator",
    category: "Heavy Equipment",
    nearestTown: "Dawson Creek",
    description: "Low-hour tracked machine",
  });

  assert.ok(tokens.includes("cat"));
  assert.ok(tokens.includes("cat 320"));
  assert.ok(tokens.includes("hydraulic exc"));
  assert.ok(tokens.includes("dawson cr"));
  assert.ok(tokens.includes("tracked machine"));
  assert.equal(tokens.length, new Set(tokens).size);
  assert.ok(tokens.length <= 480);
});

test("listing index does not accept unlimited description growth", () => {
  const tokens = buildMarketplaceSearchTokens({
    title: "Pipe",
    description: Array.from({length: 600}, (_, index) => `term${index}`)
        .join(" "),
  });

  assert.ok(tokens.length <= 480);
  assert.ok(tokens.every((token) => token.length <= 64));
});
