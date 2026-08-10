"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyPatch,
  normalizeReadiness,
  validateReadiness,
} = require("../payment_readiness_admin");

const base = normalizeReadiness({
  stripeMode: "disabled",
  connectReturnUrl: "https://pipebuyer.com/payments/connect/return",
  connectRefreshUrl: "https://pipebuyer.com/payments/connect/refresh",
  checkoutSuccessUrl: "https://pipebuyer.com/payments/success",
  checkoutCancelUrl: "https://pipebuyer.com/payments/cancel",
});

test("production mode requires explicit confirmation", () => {
  assert.throws(
      () => applyPatch(base, {stripeMode: "production"}),
      /explicit confirmation/i,
  );
  const next = applyPatch(
      base,
      {stripeMode: "production"},
      {confirmProduction: true},
  );
  assert.equal(next.stripeMode, "production");
});

test("marketplace checkout is fail-closed until every prerequisite is true", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeCheckoutEnabled: true,
      }, {confirmProduction: true}),
      /verified webhooks, tax readiness, and reconciliation readiness/i,
  );
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeConnectOnboardingEnabled: true,
    stripeCheckoutEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxReady: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeCheckoutEnabled, true);
});

test("financial resolution requires verified webhook and reconciliation", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        marketplaceFinancialResolutionEnabled: true,
      }, {confirmProduction: true}),
      /verified webhooks, and reconciliation readiness/i,
  );
});

test("dispute evidence cannot outrun dispute automation", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeWebhookVerified: true,
        stripeReconciliationReady: true,
        marketplaceFinancialResolutionEnabled: true,
        marketplaceDisputeEvidenceEnabled: true,
      }, {confirmProduction: true}),
      /requires dispute automation/i,
  );
});

test("affiliate payouts require the payout prerequisites", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        affiliatePayoutsEnabled: true,
      }, {confirmProduction: true}),
      /Affiliate payouts require/i,
  );
});

test("unsupported fields and non-Pipe Buyer callback URLs are rejected", () => {
  assert.throws(() => applyPatch(base, {madeUp: true}), /Unsupported readiness field/);
  assert.throws(
      () => applyPatch(base, {checkoutSuccessUrl: "https://example.com/success"}),
      /pipebuyer.com/i,
  );
});
