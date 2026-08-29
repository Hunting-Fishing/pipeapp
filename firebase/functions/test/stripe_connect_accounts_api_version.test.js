"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {
  STRIPE_CONNECT_ACCOUNTS_API_VERSION,
} = require("../stripe_marketplace_commands");

test("seller Connect Accounts v2 uses the current marketplace recipient preview", () => {
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      "2026-07-29.preview",
  );
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      stripeMarketplaceConfig.connectAccountsApiVersion,
  );
});

test("Connect Accounts preview remains isolated from other Stripe surfaces", () => {
  assert.equal(stripeMarketplaceConfig.apiVersion, "2026-06-24.preview");
  assert.notEqual(
      stripeMarketplaceConfig.connectAccountsApiVersion,
      stripeMarketplaceConfig.apiVersion,
  );
});
