"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchBillingPortalAvailable,
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

test("portal availability requires explicit readiness and provider identity", () => {
  const state = {
    stripeCustomerId: "cus_test123",
    stripeSubscriptionId: "sub_test123",
    reviewRequired: false,
  };
  assert.equal(dispatchBillingPortalAvailable({enabled: true}, state), true);
  assert.equal(dispatchBillingPortalAvailable({enabled: false}, state), false);
  assert.equal(dispatchBillingPortalAvailable({enabled: true}, {
    ...state,
    stripeCustomerId: "",
  }), false);
  assert.equal(dispatchBillingPortalAvailable({enabled: true}, {
    ...state,
    reviewRequired: true,
  }), false);
});
