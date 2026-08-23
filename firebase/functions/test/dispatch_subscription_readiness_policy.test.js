"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
} = require("../dispatch_billing_portal_policy");
const {
  dispatchSubscriptionFeatureReady,
  dispatchSubscriptionStoredReadiness,
  dispatchSubscriptionTaxReady,
} = require("../dispatch_subscription_readiness_policy");

function safePortal(overrides = {}) {
  return {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_dispatch",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_dispatch",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: {
      paymentMethodUpdate: true,
      invoiceHistory: true,
      subscriptionCancel: true,
      subscriptionCancelMode: "at_period_end",
      subscriptionCancelProration: "none",
      subscriptionUpdate: false,
    },
    ...overrides,
  };
}

function readyReadiness(overrides = {}) {
  return {
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    stripeWebhookVerified: true,
    stripeSubscriptionLifecycleWebhookVerified: true,
    stripeSubscriptionRecoveryVerified: true,
    stripeReconciliationReady: true,
    stripeTaxReady: true,
    ...overrides,
  };
}

const features = Object.freeze({dispatch: true, paidFeatures: true});

function validAssessment(overrides = {}) {
  return {
    worldwideAndAssociatedIncluded: true,
    singleQuarterCadMinor: 1000000,
    rollingFourQuarterCadMinor: 2000000,
    thresholdCadMinor: 3000000,
    exceeded: false,
    requiresRegistrationReview: false,
    revision: 7,
    ...overrides,
  };
}

test("feature readiness requires both dispatch and paidFeatures", () => {
  assert.equal(dispatchSubscriptionFeatureReady(features), true);
  assert.equal(dispatchSubscriptionFeatureReady({dispatch: true}), false);
  assert.equal(dispatchSubscriptionFeatureReady({paidFeatures: true}), false);
});

test("stored readiness requires all eight launch prerequisites", () => {
  const result = dispatchSubscriptionStoredReadiness(
      readyReadiness(),
      safePortal(),
      null,
      features,
  );
  assert.equal(result.readyCount, 8);
  assert.equal(result.prerequisiteCount, 8);
  assert.equal(result.prerequisitesReady, true);
  assert.equal(result.publicBillingAvailable, true);
});

test("public billing stays off when activation switch is off", () => {
  const result = dispatchSubscriptionStoredReadiness(
      readyReadiness({stripeSubscriptionsEnabled: false}),
      safePortal(),
      null,
      features,
  );
  assert.equal(result.prerequisitesReady, true);
  assert.equal(result.publicBillingAvailable, false);
});

test("feature flag or production mode mismatch prevents false-ready state", () => {
  const featureBlocked = dispatchSubscriptionStoredReadiness(
      readyReadiness(),
      safePortal(),
      null,
      {dispatch: true, paidFeatures: false},
  );
  assert.equal(featureBlocked.featureFlagsReady, false);
  assert.equal(featureBlocked.prerequisitesReady, false);

  const modeBlocked = dispatchSubscriptionStoredReadiness(
      readyReadiness({stripeMode: "test"}),
      safePortal(),
      null,
      features,
  );
  assert.equal(modeBlocked.productionModeReady, false);
  assert.equal(modeBlocked.prerequisitesReady, false);
});

test("small-supplier tax readiness requires current bound assessment", () => {
  const readiness = readyReadiness({
    stripeTaxReady: false,
    canadaGstHstSmallSupplier: true,
    canadaGstHstSmallSupplierAssessmentRevision: 7,
  });
  assert.equal(
      dispatchSubscriptionTaxReady(readiness, validAssessment()),
      true,
  );
  assert.equal(
      dispatchSubscriptionTaxReady(
          {...readiness, canadaGstHstSmallSupplierAssessmentRevision: 6},
          validAssessment(),
      ),
      false,
  );
});

test("unsafe or incomplete Portal proof prevents stored readiness", () => {
  const result = dispatchSubscriptionStoredReadiness(
      readyReadiness(),
      safePortal({providerVerified: false}),
      null,
      features,
  );
  assert.equal(result.portalReady, false);
  assert.equal(result.prerequisitesReady, false);
  assert.equal(result.publicBillingAvailable, false);
});
