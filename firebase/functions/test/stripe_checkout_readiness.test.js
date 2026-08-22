"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  requireCheckoutReady,
  requirePlatformFeeBillingReady,
} = require("../stripe_checkout_commands");

const providerReady = {
  stripeMode: "production",
  stripeWebhookVerified: true,
  stripeReconciliationReady: true,
};

test("platform fee billing rejects pending registration without separate approval", () => {
  assert.throws(
      () => requirePlatformFeeBillingReady({
        ...providerReady,
        stripeFeeBillingEnabled: true,
        stripeTaxRegistrationPending: true,
      }),
      /marketplace fee billing is not enabled/i,
  );
});

test("platform fee billing accepts separately approved pending registration", () => {
  assert.doesNotThrow(
      () => requirePlatformFeeBillingReady({
        ...providerReady,
        stripeFeeBillingEnabled: true,
        stripeTaxRegistrationPending: true,
        stripeTaxPendingBillingApproved: true,
      }),
  );
});

test("full marketplace checkout still requires actual tax readiness", () => {
  assert.throws(
      () => requireCheckoutReady({
        ...providerReady,
        stripeCheckoutEnabled: true,
        stripeTaxRegistrationPending: true,
        stripeTaxPendingBillingApproved: true,
      }),
      /full marketplace checkout is not yet approved/i,
  );
  assert.doesNotThrow(
      () => requireCheckoutReady({
        ...providerReady,
        stripeCheckoutEnabled: true,
        stripeTaxReady: true,
      }),
  );
});
