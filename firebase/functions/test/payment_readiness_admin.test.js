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

test("full marketplace checkout still requires active tax registration", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeConnectOnboardingEnabled: true,
        stripeCheckoutEnabled: true,
        stripeWebhookVerified: true,
        stripeTaxRegistrationPending: true,
        stripeReconciliationReady: true,
      }, {confirmProduction: true}),
      /active tax registration/i,
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

test("Dispatch subscriptions can launch while tax registration is pending", () => {
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxRegistrationPending: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeSubscriptionsEnabled, true);
  assert.equal(ready.stripeTaxReady, false);
  assert.equal(ready.stripeTaxRegistrationPending, true);
});

test("Pipe Buyer marketplace fee billing can launch while tax registration is pending", () => {
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeFeeBillingEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxRegistrationPending: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeFeeBillingEnabled, true);
});

test("tax registration cannot be pending and ready at the same time", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxReady: true,
        stripeTaxRegistrationPending: true,
      }, {confirmProduction: true}),
      /cannot be both pending and ready/i,
  );
});

test("tax registration pending is production-only", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "sandbox",
        stripeTaxRegistrationPending: true,
      }),
      /only be used with production billing/i,
  );
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
