"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  invoiceCommissionBaseMinor,
  invoicePeriodBounds,
  stripeCustomerIdFromInvoice,
  subscriptionIdentityFromInvoice,
} = require("../subscription_monetization");
const {
  CHECKOUT_CONFIGURATION_VERSION,
  checkoutAttemptKey,
  couponFromEntitlement,
  dispatchMembershipIsCurrent,
  reusableCheckoutState,
  selectedPlan,
} = require("../dispatch_subscription_commands");
const {
  membershipStatusPayload,
} = require("../dispatch_subscription_status");

test("subscription commission uses post-discount amount excluding tax", () => {
  assert.equal(invoiceCommissionBaseMinor({
    total_excluding_tax: 2000,
    total: 2100,
    subtotal: 2500,
  }), 2000);
});

test("zero-dollar free invoices create a zero commission base", () => {
  assert.equal(invoiceCommissionBaseMinor({
    total_excluding_tax: 0,
    total: 0,
    subtotal: 2500,
  }), 0);
});

test("reads immutable subscription metadata from invoice parent", () => {
  const identity = subscriptionIdentityFromInvoice({
    parent: {
      subscription_details: {
        subscription: "sub_123",
        metadata: {
          billingType: "dispatch_subscription",
          pipeBuyerUid: "user_123",
        },
      },
    },
  });
  assert.equal(identity.subscriptionId, "sub_123");
  assert.equal(identity.metadata.pipeBuyerUid, "user_123");
});

test("extracts only a valid Stripe Customer id from an invoice", () => {
  assert.equal(
      stripeCustomerIdFromInvoice({customer: "cus_123"}),
      "cus_123",
  );
  assert.equal(
      stripeCustomerIdFromInvoice({customer: {id: "cus_456"}}),
      "cus_456",
  );
  assert.equal(stripeCustomerIdFromInvoice({customer: "acct_123"}), "");
});

test("invoice period bounds use the widest provider-confirmed paid period", () => {
  const period = invoicePeriodBounds({
    period_start: 100,
    period_end: 200,
    lines: {
      data: [
        {period: {start: 90, end: 190}},
        {period: {start: 110, end: 240}},
      ],
    },
  });
  assert.deepEqual(period, {
    startMillis: 90000,
    endMillis: 240000,
  });
});

test("only controlled free entitlements map to Stripe coupons", () => {
  assert.equal(couponFromEntitlement({
    active: true,
    type: "dispatch_1_year_free",
  }), "PIPEBUYER_FREE_1Y");
  assert.equal(couponFromEntitlement({
    active: true,
    type: "dispatch_5_years_free",
  }), "PIPEBUYER_FREE_5Y");
  assert.equal(couponFromEntitlement({
    active: false,
    type: "dispatch_5_years_free",
  }), null);
});

test("Dispatch plan requires an explicit monthly or yearly selection", () => {
  assert.equal(selectedPlan("MONTHLY"), "monthly");
  assert.equal(selectedPlan("yearly"), "yearly");
  assert.throws(() => selectedPlan("lifetime"));
  assert.throws(() => selectedPlan(""));
  assert.throws(() => selectedPlan(undefined));
});

test("Dispatch membership requires active flag and a future paid-through date", () => {
  const now = 1_000_000;
  assert.equal(dispatchMembershipIsCurrent({
    active: true,
    currentPeriodEnd: {toMillis: () => now + 1000},
  }, now), true);
  assert.equal(dispatchMembershipIsCurrent({
    active: true,
    currentPeriodEnd: {toMillis: () => now - 1},
  }, now), false);
  assert.equal(dispatchMembershipIsCurrent({
    active: false,
    currentPeriodEnd: {toMillis: () => now + 1000},
  }, now), false);
});

test("open Dispatch checkout is reused only for the same plan before expiry", () => {
  const now = 1_000_000;
  const state = {
    status: "created",
    plan: "monthly",
    checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION,
    checkoutSessionId: "cs_live_123",
    checkoutUrl: "https://checkout.stripe.com/example",
    expiresAt: {toMillis: () => now + 1000},
  };
  assert.equal(reusableCheckoutState(state, "monthly", now), true);
  assert.equal(reusableCheckoutState(state, "yearly", now), false);
  assert.equal(reusableCheckoutState({
    ...state,
    checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION - 1,
  }, "monthly", now), false);
  assert.equal(reusableCheckoutState({
    ...state,
    expiresAt: {toMillis: () => now - 1},
  }, "monthly", now), false);
});

test("Stripe idempotency key is stable for one server checkout attempt", () => {
  assert.equal(
      checkoutAttemptKey("user_123", 7),
      "pipebuyer-dispatch-user_123-attempt-7",
  );
  assert.equal(
      checkoutAttemptKey("user_123", 7),
      checkoutAttemptKey("user_123", 7),
  );
  assert.notEqual(
      checkoutAttemptKey("user_123", 7),
      checkoutAttemptKey("user_123", 8),
  );
});

test("private status payload never reports an expired membership active", () => {
  const now = 1_000_000;
  assert.deepEqual(membershipStatusPayload(null, now), {
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
  assert.deepEqual(membershipStatusPayload({
    active: true,
    status: "active",
    plan: "yearly",
    currentPeriodStart: {toMillis: () => now - 5000},
    currentPeriodEnd: {toMillis: () => now - 1},
  }, now), {
    active: false,
    status: "expired",
    plan: "yearly",
    currentPeriodStartMillis: now - 5000,
    currentPeriodEndMillis: now - 1,
    paymentIssue: false,
    cancelAtPeriodEnd: false,
    providerStatus: "",
    renewalStatus: "",
  });
  assert.equal(membershipStatusPayload({
    active: true,
    status: "active",
    plan: "monthly",
    currentPeriodEnd: {toMillis: () => now + 5000},
  }, now).active, true);
});
