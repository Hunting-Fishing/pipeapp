"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  portalConfigurationApproved,
  portalReady,
  providerStateSupportsPortal,
  validPortalConfigurationId,
} = require("../dispatch_subscription_portal");

test("Dispatch portal configuration IDs must be Stripe billing portal IDs", () => {
  assert.equal(validPortalConfigurationId("bpc_123ABC"), true);
  assert.equal(validPortalConfigurationId("pc_123"), false);
  assert.equal(validPortalConfigurationId(""), false);
});

test("Dispatch portal remains fail closed until explicitly enabled", () => {
  const readiness = {
    stripeMode: "production",
    stripeWebhookVerified: true,
    stripeDispatchPortalEnabled: false,
    stripeDispatchPortalConfigurationId: "bpc_123ABC",
    dispatchPortalReturnUrl: "https://pipebuyer.com/payments/dispatch",
  };
  assert.equal(portalReady(readiness), false);
  assert.equal(portalReady({...readiness, stripeDispatchPortalEnabled: true}), true);
});

test("Dispatch portal requires production mode and verified webhook processing", () => {
  const ready = {
    stripeMode: "production",
    stripeWebhookVerified: true,
    stripeDispatchPortalEnabled: true,
    stripeDispatchPortalConfigurationId: "bpc_123ABC",
    dispatchPortalReturnUrl: "https://pipebuyer.com/payments/dispatch",
  };
  assert.equal(portalReady({...ready, stripeMode: "sandbox"}), false);
  assert.equal(portalReady({...ready, stripeWebhookVerified: false}), false);
});

test("provider state must belong to caller and contain customer and subscription IDs", () => {
  const state = {
    ownerUid: "user_1",
    stripeCustomerId: "cus_123",
    subscriptionId: "sub_123",
  };
  assert.equal(providerStateSupportsPortal(state, "user_1"), true);
  assert.equal(providerStateSupportsPortal(state, "user_2"), false);
  assert.equal(providerStateSupportsPortal({...state, stripeCustomerId: ""}, "user_1"), false);
  assert.equal(providerStateSupportsPortal({...state, subscriptionId: ""}, "user_1"), false);
});

test("approved Portal allows payment updates and period-end cancel but no plan switching", () => {
  const configuration = {
    id: "bpc_123ABC",
    active: true,
    features: {
      payment_method_update: {enabled: true},
      subscription_cancel: {enabled: true, mode: "at_period_end"},
      subscription_update: {enabled: false},
    },
  };
  assert.equal(
      portalConfigurationApproved(configuration, "bpc_123ABC"),
      true,
  );
  assert.equal(
      portalConfigurationApproved({
        ...configuration,
        features: {
          ...configuration.features,
          subscription_update: {enabled: true},
        },
      }, "bpc_123ABC"),
      false,
  );
  assert.equal(
      portalConfigurationApproved({
        ...configuration,
        features: {
          ...configuration.features,
          subscription_cancel: {enabled: true, mode: "immediately"},
        },
      }, "bpc_123ABC"),
      false,
  );
  assert.equal(
      portalConfigurationApproved({...configuration, active: false}, "bpc_123ABC"),
      false,
  );
});
