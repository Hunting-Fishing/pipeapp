"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {
  STRIPE_CONNECT_ACCOUNTS_API_VERSION,
  recipientTransferStatus,
  sellerPayoutReady,
  stripeFormBody,
} = require("../stripe_marketplace_commands");

test("seller Connect uses stable v1 API instead of Accounts v2 preview", () => {
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      "2026-06-24.dahlia",
  );
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      stripeMarketplaceConfig.connectAccountsApiVersion,
  );
  assert.doesNotMatch(STRIPE_CONNECT_ACCOUNTS_API_VERSION, /preview/);
});

test("seller Connect API remains isolated from other Stripe surfaces", () => {
  assert.equal(stripeMarketplaceConfig.apiVersion, "2026-06-24.preview");
  assert.notEqual(
      stripeMarketplaceConfig.connectAccountsApiVersion,
      stripeMarketplaceConfig.apiVersion,
  );
});

test("seller onboarding creates a minimal typed Express account and lets Stripe Configuration settings choose capabilities", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "stripe_marketplace_commands.js"),
      "utf8",
  );
  assert.match(source, /path:\s*"\/v1\/accounts"/);
  assert.match(source, /path:\s*"\/v1\/account_links"/);
  assert.match(source, /type:\s*"express"/);
  assert.match(
      source,
      /capabilityConfigurationSource:\s*"stripe_connect_configuration"/,
  );
  assert.doesNotMatch(source, /"controller\[/);
  assert.doesNotMatch(
      source,
      /"capabilities\[transfers\]\[requested\]":\s*"true"/,
  );
  assert.doesNotMatch(source, /\/v2\/core\/accounts/);
  assert.doesNotMatch(source, /stripe_transfers:\s*\{requested:/);
  assert.doesNotMatch(source, /card_payments/);
  assert.doesNotMatch(source, /merchant_capabilities/);
});

test("Connect v1 requests use form encoding", () => {
  const body = stripeFormBody({
    country: "CA",
    type: "express",
  });
  const params = new URLSearchParams(body);
  assert.equal(params.get("country"), "CA");
  assert.equal(params.get("type"), "express");
});

test("payout readiness requires active transfers and payouts enabled", () => {
  assert.equal(
      recipientTransferStatus({capabilities: {transfers: "active"}}),
      "active",
  );
  assert.equal(
      sellerPayoutReady({
        capabilities: {transfers: "active"},
        payouts_enabled: true,
      }),
      true,
  );
  assert.equal(
      sellerPayoutReady({
        capabilities: {transfers: "active"},
        payouts_enabled: false,
      }),
      false,
  );
  assert.equal(
      sellerPayoutReady({
        capabilities: {transfers: "pending"},
        payouts_enabled: true,
      }),
      false,
  );
});
