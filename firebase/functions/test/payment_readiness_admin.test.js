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
  dispatchPortalReturnUrl: "https://pipebuyer.com/payments/dispatch",
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

test("Dispatch Customer Portal is independent from new subscription checkout", () => {
  const ready = applyPatch(
      base,
      {
        stripeMode: "production",
        stripeWebhookVerified: true,
        stripeDispatchPortalEnabled: true,
        stripeDispatchPortalConfigurationId: "bpc_123ABC",
        dispatchPortalReturnUrl: "https://pipebuyer.com/payments/dispatch",
      },
      {confirmProduction: true},
  );
  assert.equal(ready.stripeDispatchPortalEnabled, true);
  assert.equal(ready.stripeSubscriptionsEnabled, false);
});

test("Dispatch Customer Portal requires an approved Stripe configuration", () => {
  assert.throws(
      () => applyPatch(
          base,
          {
            stripeMode: "production",
            stripeWebhookVerified: true,
            stripeDispatchPortalEnabled: true,
          },
          {confirmProduction: true},
      ),
      /approved Stripe portal configuration/i,
  );
  assert.throws(
      () => applyPatch(base, {stripeDispatchPortalConfigurationId: "pc_bad"}),
      /billing portal configuration ID/i,
  );
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

test("affiliate payout economics approval is a separate production gate", () => {
  const providerReady = {
    ...base,
    stripeMode: "production",
    stripeConnectOnboardingEnabled: true,
    stripeWebhookVerified: true,
    stripeReconciliationReady: true,
  };
  assert.throws(
      () => validateReadiness({
        ...providerReady,
        affiliatePayoutsEnabled: true,
      }, {confirmProduction: true}),
      /separate approved affiliate payout economics gate/i,
  );
  const ready = validateReadiness({
    ...providerReady,
    affiliatePayoutEconomicsReady: true,
    affiliatePayoutsEnabled: true,
  }, {confirmProduction: true});
  assert.equal(ready.affiliatePayoutEconomicsReady, true);
  assert.equal(ready.affiliatePayoutsEnabled, true);
});

test("affiliate economics cannot be approved before provider readiness", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        affiliatePayoutEconomicsReady: true,
      }, {confirmProduction: true}),
      /economics approval requires production mode, Connect onboarding/i,
  );
});

test("unsupported fields and non-Pipe Buyer callback URLs are rejected", () => {
  assert.throws(() => applyPatch(base, {madeUp: true}), /Unsupported readiness field/);
  assert.throws(
      () => applyPatch(base, {checkoutSuccessUrl: "https://example.com/success"}),
      /pipebuyer.com/i,
  );
});
