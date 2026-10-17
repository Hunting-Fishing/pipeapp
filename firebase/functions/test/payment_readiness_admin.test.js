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

const economicsReady = Object.freeze({
  stripeFullGmvEconomicsApproved: true,
  stripeFullGmvEconomicsPolicyRevision: "finance-approved-2026-10-17",
  stripeFullGmvPaymentMethodConfigurationId: "pmc_approvedRail1",
  stripeFullGmvMaximumChargeMinorUsd: 1000000,
  stripeFullGmvMaximumProviderFeeBps: 200,
  stripeFullGmvMaximumProviderFeeFixedMinorUsd: 30,
  stripeFullGmvMaximumTaxUpliftBps: 2500,
  stripeFullGmvMinimumNetRevenueMinorUsd: 100,
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

test("full marketplace checkout requires tax registration or audited collection deferral", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeConnectOnboardingEnabled: true,
        stripeCheckoutEnabled: true,
        stripeWebhookVerified: true,
        stripeTaxRegistrationPending: true,
        stripeTaxPendingBillingApproved: true,
        stripeReconciliationReady: true,
        ...economicsReady,
      }, {confirmProduction: true}),
      /registered automatic tax or an audited deferred tax-collection decision/i,
  );
  const ready = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeConnectOnboardingEnabled: true,
    stripeCheckoutEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxReady: true,
    stripeReconciliationReady: true,
    ...economicsReady,
  }, {confirmProduction: true});
  assert.equal(ready.stripeCheckoutEnabled, true);
  const deferred = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeConnectOnboardingEnabled: true,
    stripeCheckoutEnabled: true,
    stripeWebhookVerified: true,
    marketplaceTaxCollectionDeferredApproved: true,
    stripeReconciliationReady: true,
    ...economicsReady,
  }, {confirmProduction: true});
  assert.equal(deferred.stripeCheckoutEnabled, true);
  assert.equal(deferred.stripeTaxReady, false);
});

test("full marketplace checkout requires separately approved rail economics", () => {
  const providerReady = {
    ...base,
    stripeMode: "production",
    stripeConnectOnboardingEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxReady: true,
    stripeReconciliationReady: true,
  };
  assert.throws(
      () => validateReadiness({
        ...providerReady,
        stripeCheckoutEnabled: true,
      }, {confirmProduction: true}),
      /approved full-GMV economics and payment rails/i,
  );
  const ready = validateReadiness({
    ...providerReady,
    ...economicsReady,
    stripeCheckoutEnabled: true,
  }, {confirmProduction: true});
  assert.equal(ready.stripeCheckoutEnabled, true);
});

test("full-GMV economics approval fails closed on incomplete or malformed inputs", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeFullGmvEconomicsApproved: true,
      }),
      /economics approval requires/i,
  );
  assert.throws(
      () => applyPatch(base, {
        stripeFullGmvPaymentMethodConfigurationId: "not-a-pmc",
      }),
      /payment-method configuration ID/i,
  );
  assert.throws(
      () => applyPatch(base, {
        stripeFullGmvMaximumProviderFeeBps: 12.5,
      }),
      /non-negative integer/i,
  );
  assert.throws(
      () => validateReadiness({
        ...base,
        ...economicsReady,
        stripeTaxReady: true,
        stripeFullGmvMaximumTaxUpliftBps: 0,
      }),
      /tax-uplift ceilings/i,
  );
});

test("registered tax and collection deferral cannot be enabled together", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxReady: true,
        marketplaceTaxCollectionDeferredApproved: true,
      }, {confirmProduction: true}),
      /cannot both be enabled/i,
  );
});

test("pending tax registration alone cannot authorize Dispatch billing", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeSubscriptionsEnabled: true,
        stripeWebhookVerified: true,
        stripeTaxRegistrationPending: true,
        stripeReconciliationReady: true,
      }, {confirmProduction: true}),
      /separately approved pending-registration billing decision/i,
  );
});

test("Dispatch subscriptions may use a separately approved pending-tax decision", () => {
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
  assert.equal(ready.stripeTaxReady, false);
  assert.equal(ready.stripeTaxRegistrationPending, true);
  assert.equal(ready.stripeTaxPendingBillingApproved, true);
});

test("pending-tax billing approval cannot exist without pending registration", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxPendingBillingApproved: true,
      }, {confirmProduction: true}),
      /only be enabled while tax registration is explicitly pending/i,
  );
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

test("marketplace fee billing also requires separate pending-tax approval", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeFeeBillingEnabled: true,
        stripeWebhookVerified: true,
        stripeTaxRegistrationPending: true,
        stripeReconciliationReady: true,
      }, {confirmProduction: true}),
      /separately approved pending-registration billing decision/i,
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
      /verified mode-bound webhooks, and reconciliation readiness/i,
  );
});

test("sandbox marketplace rails can be enabled without enabling subscriptions", () => {
  const ready = validateReadiness({
    ...base,
    stripeMode: "sandbox",
    stripeConnectOnboardingEnabled: true,
    stripeCheckoutEnabled: true,
    stripeFeeBillingEnabled: true,
    stripeWebhookVerified: true,
    stripeTaxReady: true,
    stripeReconciliationReady: true,
    stripeFullGmvEconomicsApproved: true,
    stripeFullGmvEconomicsPolicyRevision: "sandbox-marketplace-v1",
    stripeFullGmvPaymentMethodConfigurationId: "pmc_Sandbox1",
    stripeFullGmvMaximumChargeMinorUsd: 100000,
    stripeFullGmvMaximumProviderFeeBps: 300,
    stripeFullGmvMaximumProviderFeeFixedMinorUsd: 30,
    stripeFullGmvMaximumTaxUpliftBps: 1500,
    stripeFullGmvMinimumNetRevenueMinorUsd: 100,
    marketplaceFinancialResolutionEnabled: true,
  });
  assert.equal(ready.stripeCheckoutEnabled, true);
  assert.equal(ready.stripeFeeBillingEnabled, true);
  assert.equal(ready.marketplaceFinancialResolutionEnabled, true);
  assert.equal(ready.stripeSubscriptionsEnabled, false);
  assert.equal(ready.stripeVipSubscriptionsEnabled, false);
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
