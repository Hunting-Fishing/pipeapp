"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  invoiceCommissionBaseMinor,
  subscriptionIdentityFromInvoice,
} = require("../subscription_monetization");
const {
  couponFromEntitlement,
  selectedPlan,
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
