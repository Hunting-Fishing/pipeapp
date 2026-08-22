"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  stripeMarketplaceConfig,
} = require("../stripe_marketplace_config");

test("production Stripe API pin uses reviewed GA dahlia version", () => {
  assert.equal(stripeMarketplaceConfig.apiVersion, "2026-06-24.dahlia");
  assert.match(
      stripeMarketplaceConfig.apiVersion,
      /^\d{4}-\d{2}-\d{2}\.[a-z]+$/u,
  );
  assert.doesNotMatch(stripeMarketplaceConfig.apiVersion, /\.preview$/u);
});
