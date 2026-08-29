"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {
  STRIPE_CONNECT_ACCOUNTS_API_VERSION,
} = require("../stripe_marketplace_commands");

test("seller Connect Accounts v2 uses Stripe's documented marketplace recipient preview", () => {
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      "2026-02-25.preview",
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

test("seller onboarding remains recipient-only and never requests merchant card capability", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "stripe_marketplace_commands.js"),
      "utf8",
  );
  assert.match(source, /stripe_transfers:\s*\{requested:\s*true\}/);
  assert.match(source, /configurations:\s*\["recipient"\]/);
  assert.doesNotMatch(source, /configuration:\s*\{\s*merchant:/);
  assert.doesNotMatch(source, /card_payments:\s*\{requested:\s*true\}/);
});