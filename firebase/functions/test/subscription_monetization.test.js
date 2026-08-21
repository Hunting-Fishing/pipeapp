"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchSubscriptionLifecyclePatch,
  invoiceCommissionBaseMinor,
  subscriptionIdentityFromInvoice,
} = require("../subscription_monetization");
const {
  CHECKOUT_IDEMPOTENCY_WINDOW_MS,
  checkoutIdempotencyKey,
  couponFromEntitlement,
  selectedPlan,
  subscriptionPlanCatalog,
} = require("../dispatch_subscription_commands");

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

test("Dispatch plan accepts only monthly and yearly", () => {
  assert.equal(selectedPlan("MONTHLY"), "monthly");
  assert.equal(selectedPlan("yearly"), "yearly");
  assert.throws(() => selectedPlan("lifetime"));
});

test("Dispatch pricing catalog reflects the server-owned live CAD plans", () => {
  const catalog = subscriptionPlanCatalog();
  assert.deepEqual(catalog.monthly, {
    currency: "CAD",
    amountMinor: 2500,
    amount: 25,
    interval: "month",
  });
  assert.deepEqual(catalog.yearly, {
    currency: "CAD",
    amountMinor: 30000,
    amount: 300,
    interval: "year",
  });
});

test("duplicate checkout attempts share an idempotency key inside the window", () => {
  const start = 2000000000000;
  const first = checkoutIdempotencyKey("user_1", "monthly", start);
  const retry = checkoutIdempotencyKey(
      "user_1",
      "monthly",
      start + CHECKOUT_IDEMPOTENCY_WINDOW_MS - 1,
  );
  assert.equal(first, retry);
  assert.notEqual(
      first,
      checkoutIdempotencyKey(
          "user_1",
          "monthly",
          start + CHECKOUT_IDEMPOTENCY_WINDOW_MS,
      ),
  );
  assert.notEqual(first, checkoutIdempotencyKey("user_1", "yearly", start));
});

test("Stripe active status does not independently grant Dispatch access", () => {
  const patch = dispatchSubscriptionLifecyclePatch({
    id: "sub_123",
    status: "active",
    current_period_end: 2000000000,
    cancel_at_period_end: false,
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "user_123",
      dispatchPlan: "monthly",
    },
  }, "customer.subscription.updated");
  assert.equal(patch.status, "active");
  assert.equal(patch.activeUpdate, null);
  assert.equal(patch.paymentProblem, false);
});

test("past-due Dispatch subscription raises attention without creating a second access decision", () => {
  const patch = dispatchSubscriptionLifecyclePatch({
    id: "sub_123",
    status: "past_due",
    cancel_at_period_end: false,
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "user_123",
      dispatchPlan: "yearly",
    },
  }, "customer.subscription.updated");
  assert.equal(patch.status, "past_due");
  assert.equal(patch.paymentProblem, true);
  assert.equal(patch.activeUpdate, null);
});

test("deleted Dispatch subscription terminates provider-authored access", () => {
  const patch = dispatchSubscriptionLifecyclePatch({
    id: "sub_123",
    status: "active",
    cancel_at_period_end: false,
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "user_123",
      dispatchPlan: "monthly",
    },
  }, "customer.subscription.deleted");
  assert.equal(patch.status, "canceled");
  assert.equal(patch.activeUpdate, false);
});

test("subscription lifecycle ignores non-Dispatch Stripe subscriptions", () => {
  assert.equal(dispatchSubscriptionLifecyclePatch({
    id: "sub_123",
    status: "active",
    metadata: {
      billingType: "other_subscription",
      pipeBuyerUid: "user_123",
    },
  }, "customer.subscription.updated"), null);
});
