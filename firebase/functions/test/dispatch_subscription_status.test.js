"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  managementAvailable,
  membershipStatusPayload,
} = require("../dispatch_subscription_status");

test("missing membership returns safe inactive lifecycle fields", () => {
  assert.deepEqual(membershipStatusPayload(null, 1000), {
    active: false,
    status: "none",
    plan: "",
    currentPeriodStartMillis: null,
    currentPeriodEndMillis: null,
    paymentIssue: false,
    cancelAtPeriodEnd: false,
    providerStatus: "",
    renewalStatus: "",
  });
});

test("active membership preserves provider lifecycle messaging", () => {
  const payload = membershipStatusPayload({
    active: true,
    status: "active_until_period_end",
    plan: "yearly",
    currentPeriodStart: 1000,
    currentPeriodEnd: 5000,
    paymentIssue: true,
    cancelAtPeriodEnd: true,
    providerStatus: "past_due",
    renewalStatus: "cancel_at_period_end",
  }, 2000);
  assert.equal(payload.active, true);
  assert.equal(payload.status, "active_until_period_end");
  assert.equal(payload.paymentIssue, true);
  assert.equal(payload.cancelAtPeriodEnd, true);
  assert.equal(payload.providerStatus, "past_due");
});

test("expired paid-through date normalizes active flag to false", () => {
  const payload = membershipStatusPayload({
    active: true,
    status: "active",
    currentPeriodEnd: 1000,
  }, 2000);
  assert.equal(payload.active, false);
  assert.equal(payload.status, "expired");
});

test("management availability requires both portal readiness and owned provider state", () => {
  const readiness = {
    stripeMode: "production",
    stripeWebhookVerified: true,
    stripeDispatchPortalEnabled: true,
    stripeDispatchPortalConfigurationId: "bpc_123ABC",
    dispatchPortalReturnUrl: "https://pipebuyer.com/payments/dispatch",
  };
  const providerState = {
    ownerUid: "user_1",
    stripeCustomerId: "cus_123",
    subscriptionId: "sub_123",
  };
  assert.equal(managementAvailable({readiness, providerState, uid: "user_1"}), true);
  assert.equal(managementAvailable({readiness, providerState, uid: "user_2"}), false);
  assert.equal(managementAvailable({
    readiness: {...readiness, stripeDispatchPortalEnabled: false},
    providerState,
    uid: "user_1",
  }), false);
});
