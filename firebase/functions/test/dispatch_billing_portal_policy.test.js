"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  dispatchBillingPortalAvailable,
  dispatchBillingPortalProviderAssessment,
  dispatchBillingPortalProviderRecordReady,
  dispatchBillingPortalStoredFeaturesReady,
  validStripeBillingPortalConfigurationId,
  validStripeBillingPortalUrl,
} = require("../dispatch_billing_portal_policy");

function reviewedProviderConfiguration(overrides = {}) {
  return {
    id: "bpc_test123",
    livemode: true,
    active: true,
    features: {
      payment_method_update: {enabled: true},
      invoice_history: {enabled: true},
      subscription_cancel: {
        enabled: true,
        mode: "at_period_end",
        proration_behavior: "none",
      },
      subscription_update: {enabled: false},
    },
    ...overrides,
  };
}

function storedFeatures(overrides = {}) {
  return {
    paymentMethodUpdate: true,
    invoiceHistory: true,
    subscriptionCancel: true,
    subscriptionCancelMode: "at_period_end",
    subscriptionCancelProration: "none",
    subscriptionUpdate: false,
    ...overrides,
  };
}

function verifiedPortalRecord(overrides = {}) {
  return {
    enabled: true,
    stripePortalConfigurationId: "bpc_test123",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_test123",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: storedFeatures(),
    ...overrides,
  };
}

test("Billing Portal accepts only exact Stripe billing host", () => {
  assert.equal(
      validStripeBillingPortalUrl("https://billing.stripe.com/p/session/test"),
      true,
  );
  assert.equal(
      validStripeBillingPortalUrl("http://billing.stripe.com/p/session/test"),
      false,
  );
  assert.equal(
      validStripeBillingPortalUrl("https://billing.stripe.com.evil.example/test"),
      false,
  );
});

test("Billing Portal configuration requires exact Stripe bpc identity", () => {
  assert.equal(validStripeBillingPortalConfigurationId("bpc_test123"), true);
  assert.equal(validStripeBillingPortalConfigurationId(""), false);
  assert.equal(validStripeBillingPortalConfigurationId("cus_test123"), false);
  assert.equal(validStripeBillingPortalConfigurationId("bpc_bad/value"), false);
});

test("provider assessment requires the exact launch-safe Portal features", () => {
  const ready = dispatchBillingPortalProviderAssessment(
      reviewedProviderConfiguration(),
  );
  assert.equal(ready.ready, true);
  assert.deepEqual(ready.failedChecks, []);
  assert.equal(ready.features.paymentMethodUpdate, true);
  assert.equal(ready.features.invoiceHistory, true);
  assert.equal(ready.features.subscriptionCancelMode, "at_period_end");
  assert.equal(ready.features.subscriptionUpdate, false);

  const unsafe = dispatchBillingPortalProviderAssessment(
      reviewedProviderConfiguration({
        features: {
          payment_method_update: {enabled: true},
          invoice_history: {enabled: true},
          subscription_cancel: {
            enabled: true,
            mode: "immediately",
            proration_behavior: "create_prorations",
          },
          subscription_update: {enabled: true},
        },
      }),
  );
  assert.equal(unsafe.ready, false);
  assert.ok(unsafe.failedChecks.includes("subscription_cancel_mode"));
  assert.ok(unsafe.failedChecks.includes("subscription_cancel_proration"));
  assert.ok(unsafe.failedChecks.includes("subscription_update_disabled"));
});

test("stored provider feature evidence must match the approved launch profile", () => {
  assert.equal(dispatchBillingPortalStoredFeaturesReady(storedFeatures()), true);
  assert.equal(dispatchBillingPortalStoredFeaturesReady({}), false);
  assert.equal(dispatchBillingPortalStoredFeaturesReady(
      storedFeatures({subscriptionUpdate: true}),
  ), false);
  assert.equal(dispatchBillingPortalStoredFeaturesReady(
      storedFeatures({subscriptionCancelMode: "immediately"}),
  ), false);
});

test("provider verification record must be bound to exact configuration and features", () => {
  assert.equal(dispatchBillingPortalProviderRecordReady(verifiedPortalRecord()), true);
  assert.equal(dispatchBillingPortalProviderRecordReady(verifiedPortalRecord({
    providerVerifiedConfigurationId: "bpc_other123",
  })), false);
  assert.equal(dispatchBillingPortalProviderRecordReady(verifiedPortalRecord({
    providerVerificationRevision: "old-policy",
  })), false);
  assert.equal(dispatchBillingPortalProviderRecordReady(verifiedPortalRecord({
    providerVerified: false,
  })), false);
  assert.equal(dispatchBillingPortalProviderRecordReady(verifiedPortalRecord({
    providerVerifiedFeatures: {},
  })), false);
  assert.equal(dispatchBillingPortalProviderRecordReady(verifiedPortalRecord({
    providerVerifiedFeatures: storedFeatures({subscriptionUpdate: true}),
  })), false);
});

test("portal availability requires provider verification and subscription identity", () => {
  const config = verifiedPortalRecord();
  const state = {
    stripeCustomerId: "cus_test123",
    stripeSubscriptionId: "sub_test123",
    reviewRequired: false,
  };
  assert.equal(dispatchBillingPortalAvailable(config, state), true);
  assert.equal(dispatchBillingPortalAvailable({...config, enabled: false}, state), false);
  assert.equal(dispatchBillingPortalAvailable({
    ...config,
    providerVerified: false,
  }, state), false);
  assert.equal(dispatchBillingPortalAvailable(config, {
    ...state,
    stripeCustomerId: "",
  }), false);
  assert.equal(dispatchBillingPortalAvailable(config, {
    ...state,
    reviewRequired: true,
  }), false);
});
