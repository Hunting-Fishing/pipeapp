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
        canadaGstHstSmallSupplier: true,
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

test("Canadian small supplier mode can authorize Dispatch subscriptions", () => {
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    stripeWebhookVerified: true,
    canadaGstHstSmallSupplier: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeSubscriptionsEnabled, true);
  assert.equal(ready.canadaGstHstSmallSupplier, true);
  assert.equal(ready.stripeTaxReady, false);
});

test("Dispatch affiliate accrual is a separate audited control", () => {
  assert.equal(base.dispatchAffiliateCommissionAccrualEnabled, false);
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        dispatchAffiliateCommissionAccrualEnabled: true,
        stripeWebhookVerified: true,
        stripeReconciliationReady: true,
      }, {confirmProduction: true}),
      /requires live Dispatch subscriptions/i,
  );

  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    dispatchAffiliateCommissionAccrualEnabled: true,
    stripeWebhookVerified: true,
    canadaGstHstSmallSupplier: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.dispatchAffiliateCommissionAccrualEnabled, true);
  assert.equal(ready.affiliatePayoutsEnabled, false);
});

test("affiliate payout pause does not disable approved Dispatch accrual", () => {
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    dispatchAffiliateCommissionAccrualEnabled: true,
    affiliatePayoutsEnabled: false,
    stripeWebhookVerified: true,
    canadaGstHstSmallSupplier: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.dispatchAffiliateCommissionAccrualEnabled, true);
  assert.equal(ready.affiliatePayoutsEnabled, false);
});

test("Canadian small supplier mode can authorize Pipe Buyer fee billing", () => {
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeFeeBillingEnabled: true,
    stripeWebhookVerified: true,
    canadaGstHstSmallSupplier: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeFeeBillingEnabled, true);
  assert.equal(ready.canadaGstHstSmallSupplier, true);
});

test("pending registration alone cannot authorize Dispatch subscriptions", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeSubscriptionsEnabled: true,
        stripeWebhookVerified: true,
        stripeTaxRegistrationPending: true,
        stripeReconciliationReady: true,
      }, {confirmProduction: true}),
      /authorized GST\/HST billing state/i,
  );
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxRegistrationPending: true,
    stripeTaxPendingBillingApproved: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeSubscriptionsEnabled, true);
  assert.equal(ready.stripeTaxPendingBillingApproved, true);
});

test("pending registration alone cannot authorize Pipe Buyer fee billing", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeFeeBillingEnabled: true,
        stripeWebhookVerified: true,
        stripeTaxRegistrationPending: true,
        stripeReconciliationReady: true,
      }, {confirmProduction: true}),
      /authorized GST\/HST billing state/i,
  );
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeFeeBillingEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxRegistrationPending: true,
    stripeTaxPendingBillingApproved: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeFeeBillingEnabled, true);
  assert.equal(ready.stripeTaxPendingBillingApproved, true);
});

test("pending-tax billing approval requires registration to be pending", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxPendingBillingApproved: true,
      }, {confirmProduction: true}),
      /only be enabled while tax registration is explicitly pending/i,
  );
});

test("GST HST identity states are mutually exclusive", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxReady: true,
        canadaGstHstSmallSupplier: true,
      }, {confirmProduction: true}),
      /exactly one of registered, registration pending, or Canadian small supplier/i,
  );
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxRegistrationPending: true,
        canadaGstHstSmallSupplier: true,
      }, {confirmProduction: true}),
      /exactly one of registered, registration pending, or Canadian small supplier/i,
  );
});

test("pending registration and small supplier states are production-only", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "sandbox",
        stripeTaxRegistrationPending: true,
      }),
      /only be used with production billing/i,
  );
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "sandbox",
        canadaGstHstSmallSupplier: true,
      }),
      /small-supplier billing status may only be used with production billing/i,
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
