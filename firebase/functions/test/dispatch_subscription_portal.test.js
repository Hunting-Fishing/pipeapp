"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
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
