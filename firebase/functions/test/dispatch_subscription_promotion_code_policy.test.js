"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  couponFromEntitlement,
  dispatchPromotionCodeEntryEnabled,
} = require("../dispatch_subscription_commands");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

test("customer promotion-code entry is enabled when no entitlement coupon is pre-applied", () => {
  assert.equal(dispatchPromotionCodeEntryEnabled(null), true);
  assert.equal(dispatchPromotionCodeEntryEnabled(""), true);
});

test("customer promotion-code entry is disabled when a 1-year entitlement coupon is pre-applied", () => {
  const couponId = couponFromEntitlement({
    active: true,
    type: "dispatch_1_year_free",
  });
  assert.equal(couponId, stripeMarketplaceConfig.coupons.oneYearFree);
  assert.equal(dispatchPromotionCodeEntryEnabled(couponId), false);
});

test("customer promotion-code entry is disabled when a 5-year entitlement coupon is pre-applied", () => {
  const couponId = couponFromEntitlement({
    active: true,
    type: "dispatch_5_years_free",
  });
  assert.equal(couponId, stripeMarketplaceConfig.coupons.fiveYearsFree);
  assert.equal(dispatchPromotionCodeEntryEnabled(couponId), false);
});
