"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  couponFromEntitlement,
  dispatchPromotionCodeEntryEnabled,
  selectedLaunchCode,
} = require("../dispatch_subscription_commands");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

test("Stripe promotion-code entry is enabled when no server promotion is pre-applied", () => {
  assert.equal(dispatchPromotionCodeEntryEnabled(null, false), true);
  assert.equal(dispatchPromotionCodeEntryEnabled("", false), true);
});

test("Stripe promotion-code entry is disabled for a Founding 500 trial", () => {
  assert.equal(dispatchPromotionCodeEntryEnabled(null, true), false);
});

test("Stripe promotion-code entry is disabled for a 1-year entitlement coupon", () => {
  const couponId = couponFromEntitlement({
    active: true,
    type: "dispatch_1_year_free",
  });
  assert.equal(couponId, stripeMarketplaceConfig.coupons.oneYearFree);
  assert.equal(dispatchPromotionCodeEntryEnabled(couponId, false), false);
});

test("Stripe promotion-code entry is disabled for a 5-year entitlement coupon", () => {
  const couponId = couponFromEntitlement({
    active: true,
    type: "dispatch_5_years_free",
  });
  assert.equal(couponId, stripeMarketplaceConfig.coupons.fiveYearsFree);
  assert.equal(dispatchPromotionCodeEntryEnabled(couponId, false), false);
});

test("Pipe Buyer launch-code input accepts only FOUNDING500", () => {
  assert.equal(selectedLaunchCode(""), "");
  assert.equal(selectedLaunchCode(" founding500 "), "FOUNDING500");
  assert.throws(() => selectedLaunchCode("OTHER-CODE"), /not recognized/i);
});
