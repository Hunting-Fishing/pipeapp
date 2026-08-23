"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchBillingPortalAvailable,
  validStripeBillingPortalConfigurationId,
  validStripeBillingPortalUrl,
} = require("../dispatch_billing_portal_policy");

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

test("portal availability requires explicit readiness, reviewed configuration, and provider identity", () => {
  const config = {
    enabled: true,
    stripePortalConfigurationId: "bpc_test123",
  };
  const state = {
    stripeCustomerId: "cus_test123",
    stripeSubscriptionId: "sub_test123",
    reviewRequired: false,
  };
  assert.equal(dispatchBillingPortalAvailable(config, state), true);
  assert.equal(dispatchBillingPortalAvailable({...config, enabled: false}, state), false);
  assert.equal(dispatchBillingPortalAvailable({enabled: true}, state), false);
  assert.equal(dispatchBillingPortalAvailable(config, {
    ...state,
    stripeCustomerId: "",
  }), false);
  assert.equal(dispatchBillingPortalAvailable(config, {
    ...state,
    reviewRequired: true,
  }), false);
});
