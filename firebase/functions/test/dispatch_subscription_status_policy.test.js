"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchSubscriptionPublicStatus,
} = require("../dispatch_subscription_status_policy");

test("missing state is safe and can start Checkout", () => {
  assert.deepEqual(dispatchSubscriptionPublicStatus(null), {
    hasRecord: false,
    plan: "",
    providerStatus: "not_subscribed",
    billingStatus: "",
    entitlementActive: false,
    paymentIssue: false,
    reviewRequired: false,
    checkoutOpen: false,
    processing: false,
    alreadySubscribed: false,
    canStartCheckout: true,
  });
});

test("active subscription exposes only public status fields", () => {
  const result = dispatchSubscriptionPublicStatus({
    plan: "monthly",
    status: "active",
    billingStatus: "paid",
    entitlementActive: true,
    stripeSubscriptionId: "sub_secret_reference",
    stripeCustomerId: "cus_secret_reference",
  });
  assert.equal(result.plan, "monthly");
  assert.equal(result.providerStatus, "active");
  assert.equal(result.entitlementActive, true);
  assert.equal(result.alreadySubscribed, true);
  assert.equal(result.canStartCheckout, false);
  assert.equal("stripeSubscriptionId" in result, false);
  assert.equal("stripeCustomerId" in result, false);
});

test("open Checkout blocks another subscription Checkout", () => {
  const result = dispatchSubscriptionPublicStatus({
    plan: "yearly",
    status: "checkout_created",
    checkoutAttempt: 1,
    stripeCheckoutSessionId: "cs_test_existing",
  });
  assert.equal(result.checkoutOpen, true);
  assert.equal(result.canStartCheckout, false);
  assert.equal(result.plan, "yearly");
});

test("past due preserves entitlement and exposes payment issue", () => {
  const result = dispatchSubscriptionPublicStatus({
    plan: "monthly",
    status: "past_due",
    billingStatus: "payment_failed",
    entitlementActive: true,
    paymentIssue: true,
    stripeSubscriptionId: "sub_test_active",
  });
  assert.equal(result.entitlementActive, true);
  assert.equal(result.paymentIssue, true);
  assert.equal(result.canStartCheckout, false);
});

test("review state fails closed", () => {
  const result = dispatchSubscriptionPublicStatus({
    status: "canceled",
    entitlementActive: false,
    reviewRequired: true,
  });
  assert.equal(result.reviewRequired, true);
  assert.equal(result.canStartCheckout, false);
});

test("unknown provider state is not exposed verbatim", () => {
  const result = dispatchSubscriptionPublicStatus({
    status: "unexpected_provider_value",
  });
  assert.equal(result.providerStatus, "not_subscribed");
});
