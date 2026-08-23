"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
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
      customer_update: {
        enabled: true,
        allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
      },
      invoice_history: {enabled: true},
      subscription_cancel: {
        enabled: true,
        mode: "at_period_end",
        proration_behavior: "none",
      },
      subscription_update: {
        enabled: true,
        default_allowed_updates: ["price"],
        proration_behavior: "none",
        products: [{
          product: DISPATCH_PORTAL_PRODUCT_ID,
          prices: [...DISPATCH_PORTAL_PRICE_IDS],
        }],
      },
    },
    ...overrides,
  };
}

function storedFeatures(overrides = {}) {
  return {
    paymentMethodUpdate: true,
    customerUpdate: true,
    customerUpdateAllowedUpdates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
    invoiceHistory: true,
    subscriptionCancel: true,
    subscriptionCancelMode: "at_period_end",
    subscriptionCancelProration: "none",
    subscriptionUpdate: true,
    subscriptionUpdateAllowedUpdates: ["price"],
    subscriptionUpdateProration: "none",
    subscriptionUpdateProductId: DISPATCH_PORTAL_PRODUCT_ID,
    subscriptionUpdatePriceIds: [...DISPATCH_PORTAL_PRICE_IDS],
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

test("provider assessment requires exact customer fields and two-price Dispatch switching", () => {
  const ready = dispatchBillingPortalProviderAssessment(
      reviewedProviderConfiguration(),
  );
  assert.equal(ready.ready, true);
  assert.deepEqual(ready.failedChecks, []);
  assert.equal(ready.features.paymentMethodUpdate, true);
  assert.equal(ready.features.customerUpdate, true);
  assert.deepEqual(
      ready.features.customerUpdateAllowedUpdates,
      [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
  );
  assert.equal(ready.features.invoiceHistory, true);
  assert.equal(ready.features.subscriptionCancelMode, "at_period_end");
  assert.equal(ready.features.subscriptionUpdate, true);
  assert.deepEqual(ready.features.subscriptionUpdateAllowedUpdates, ["price"]);
  assert.equal(ready.features.subscriptionUpdateProration, "none");
  assert.equal(
      ready.features.subscriptionUpdateProductId,
      DISPATCH_PORTAL_PRODUCT_ID,
  );
  assert.deepEqual(
      ready.features.subscriptionUpdatePriceIds,
      [...DISPATCH_PORTAL_PRICE_IDS],
  );
});

test("provider assessment rejects quantity edits, extra products, shipping edits, or prorated switches", () => {
  const unsafe = dispatchBillingPortalProviderAssessment(
      reviewedProviderConfiguration({
        features: {
          payment_method_update: {enabled: true},
          customer_update: {
            enabled: true,
            allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES, "shipping"],
          },
          invoice_history: {enabled: true},
          subscription_cancel: {
            enabled: true,
            mode: "at_period_end",
            proration_behavior: "none",
          },
          subscription_update: {
            enabled: true,
            default_allowed_updates: ["price", "quantity"],
            proration_behavior: "always_invoice",
            products: [
              {
                product: DISPATCH_PORTAL_PRODUCT_ID,
                prices: [...DISPATCH_PORTAL_PRICE_IDS],
              },
              {product: "prod_unreviewed", prices: ["price_unreviewed"]},
            ],
          },
        },
      }),
  );
  assert.equal(unsafe.ready, false);
  assert.ok(unsafe.failedChecks.includes("customer_update_fields"));
  assert.ok(unsafe.failedChecks.includes("subscription_update_fields"));
  assert.ok(unsafe.failedChecks.includes("subscription_update_proration"));
  assert.ok(unsafe.failedChecks.includes("subscription_update_products"));
});

test("stored provider feature evidence must match the approved launch profile", () => {
  assert.equal(dispatchBillingPortalStoredFeaturesReady(storedFeatures()), true);
  assert.equal(dispatchBillingPortalStoredFeaturesReady({}), false);
  assert.equal(dispatchBillingPortalStoredFeaturesReady(
      storedFeatures({subscriptionUpdateAllowedUpdates: ["price", "quantity"]}),
  ), false);
  assert.equal(dispatchBillingPortalStoredFeaturesReady(
      storedFeatures({subscriptionUpdatePriceIds: [DISPATCH_PORTAL_PRICE_IDS[0]]}),
  ), false);
  assert.equal(dispatchBillingPortalStoredFeaturesReady(
      storedFeatures({customerUpdateAllowedUpdates: ["email"]}),
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
    providerVerifiedFeatures: storedFeatures({
      subscriptionUpdateProductId: "prod_other",
    }),
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
