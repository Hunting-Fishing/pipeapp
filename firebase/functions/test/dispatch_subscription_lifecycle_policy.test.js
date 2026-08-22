"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchCheckoutWebhookDecision,
  dispatchSubscriptionLifecycleDecision,
} = require("../dispatch_subscription_lifecycle_policy");

test("active and trialing provider status activate Dispatch entitlement", () => {
  for (const status of ["active", "trialing"]) {
    const decision = dispatchSubscriptionLifecycleDecision(status, false);
    assert.equal(decision.entitlementActive, true);
    assert.equal(decision.paymentIssue, false);
    assert.equal(decision.reviewRequired, false);
  }
});

test("past_due preserves existing entitlement while Stripe retries payment", () => {
  assert.equal(
      dispatchSubscriptionLifecycleDecision("past_due", true).entitlementActive,
      true,
  );
  assert.equal(
      dispatchSubscriptionLifecycleDecision("past_due", false).entitlementActive,
      false,
  );
  assert.equal(
      dispatchSubscriptionLifecycleDecision("past_due", true).paymentIssue,
      true,
  );
});

test("terminal or paused subscription statuses revoke entitlement", () => {
  for (const status of [
    "canceled",
    "unpaid",
    "incomplete",
    "incomplete_expired",
    "paused",
  ]) {
    assert.equal(
        dispatchSubscriptionLifecycleDecision(status, true).entitlementActive,
        false,
        status,
    );
  }
});

test("unknown provider status preserves state but requires review", () => {
  const decision = dispatchSubscriptionLifecycleDecision("future_status", true);
  assert.equal(decision.entitlementActive, true);
  assert.equal(decision.reviewRequired, true);
});

test("late Checkout completion cannot downgrade active paid subscription", () => {
  const decision = dispatchCheckoutWebhookDecision({
    entitlementActive: true,
    stripeSubscriptionId: "sub_live",
  }, {
    subscription: "sub_live",
  });
  assert.equal(decision.action, "preserve_active");
});

test("different subscription id from Checkout is quarantined for review", () => {
  const decision = dispatchCheckoutWebhookDecision({
    entitlementActive: true,
    stripeSubscriptionId: "sub_expected",
  }, {
    subscription: "sub_unexpected",
  });
  assert.equal(decision.action, "review");
  assert.equal(decision.reason, "subscription_conflict");
});

test("normal Checkout completion moves singleton toward processing", () => {
  const decision = dispatchCheckoutWebhookDecision({}, {
    subscription: "sub_new",
  });
  assert.equal(decision.action, "processing");
  assert.equal(decision.stripeSubscriptionId, "sub_new");
});
