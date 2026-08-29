"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  CHECKOUT_CONFIGURATION_VERSION,
  createdCheckoutBlocksPlanChange,
  promotionCodeEntryAllowed,
  reusableCheckoutState,
} = require("../dispatch_subscription_commands");
const {
  discountPromotionCodeId,
  normalizePromotionCode,
  promotionCodeSummary,
  promotionCodeTargetsDispatchProduct,
  selectPromotionCode,
} = require("../dispatch_subscription_promotions");
const {safeStripeLogPath} = require("../stripe_checkout_commands");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

test("customer promotion codes are limited to undiscounted monthly Dispatch checkout", () => {
  assert.equal(promotionCodeEntryAllowed("monthly", null), true);
  assert.equal(promotionCodeEntryAllowed("monthly", ""), true);
  assert.equal(
      promotionCodeEntryAllowed("monthly", "PIPEBUYER_FREE_1Y"),
      false,
  );
  assert.equal(promotionCodeEntryAllowed("yearly", null), false);
});

test("promotion code input is normalized without client-side discount math", () => {
  assert.equal(normalizePromotionCode("  FOUNDING500  ", {required: true}), "FOUNDING500");
  assert.equal(normalizePromotionCode("save-25", {required: true}), "save-25");
  assert.throws(
      () => normalizePromotionCode("not a code", {required: true}),
      /promo code format/i,
  );
  assert.throws(
      () => normalizePromotionCode("A".repeat(65), {required: true}),
      /promo code format/i,
  );
  assert.throws(
      () => normalizePromotionCode("", {required: true}),
      /enter a promo code/i,
  );
});

test("Stripe error logging strips query strings containing typed promo codes", () => {
  assert.equal(
      safeStripeLogPath(
          "/v1/promotion_codes?active=true&code=PRIVATECODE&limit=10",
      ),
      "/v1/promotion_codes",
  );
  assert.equal(
      safeStripeLogPath("/v1/checkout/sessions/cs_123"),
      "/v1/checkout/sessions/cs_123",
  );
});

test("promotion selection is case-insensitive and prefers customer-restricted code", () => {
  const data = [
    {id: "promo_public", active: true, code: "WELCOME", customer: null},
    {id: "promo_customer", active: true, code: "welcome", customer: "cus_123"},
    {id: "promo_inactive", active: false, code: "WELCOME", customer: "cus_123"},
  ];
  assert.equal(selectPromotionCode(data, "Welcome", "cus_123").id, "promo_customer");
  assert.equal(selectPromotionCode(data, "WELCOME", "cus_other").id, "promo_public");
  assert.equal(selectPromotionCode(data, "MISSING", "cus_123"), null);
});

test("promotion summaries come only from Stripe coupon data", () => {
  assert.equal(
      promotionCodeSummary({
        promotion: {
          coupon: {
            percent_off: 100,
            duration: "repeating",
            duration_in_months: 6,
          },
        },
      }),
      "100% off for 6 months",
  );
  assert.equal(
      promotionCodeSummary({
        promotion: {
          coupon: {
            amount_off: 2500,
            currency: "cad",
            duration: "once",
          },
        },
      }),
      "CAD 25.00 off on the next eligible invoice",
  );
});

test("Dispatch product restriction is enforced when Stripe supplies applies_to", () => {
  const dispatchProductId =
    stripeMarketplaceConfig.products.dispatchMonthlyCad.productId;
  assert.equal(
      promotionCodeTargetsDispatchProduct({
        promotion: {coupon: {applies_to: {products: [dispatchProductId]}}},
      }),
      true,
  );
  assert.equal(
      promotionCodeTargetsDispatchProduct({
        promotion: {coupon: {applies_to: {products: ["prod_other"]}}},
      }),
      false,
  );
  // A coupon without applies_to is global in Stripe. Pipe Buyer still scopes its
  // promo entry to the Dispatch checkout/update callables.
  assert.equal(
      promotionCodeTargetsDispatchProduct({promotion: {coupon: {}}}),
      true,
  );
});

test("existing Stripe discount promotion code ids can be recognized idempotently", () => {
  assert.equal(discountPromotionCodeId({promotion_code: "promo_123"}), "promo_123");
  assert.equal(
      discountPromotionCodeId({promotion_code: {id: "promo_456"}}),
      "promo_456",
  );
  assert.equal(discountPromotionCodeId({coupon: {id: "coupon_1"}}), "");
});

test("stale or differently-discounted Checkout sessions are never reused", () => {
  const now = Date.now();
  const baseState = {
    plan: "monthly",
    status: "created",
    expiresAt: now + 60_000,
    checkoutSessionId: "cs_live_test",
    checkoutUrl: "https://checkout.stripe.com/c/pay/test",
  };

  assert.equal(reusableCheckoutState(baseState, "monthly", now), false);

  const currentNoPromo = {
    ...baseState,
    checkoutConfigurationVersion: CHECKOUT_CONFIGURATION_VERSION,
    promotionCodeId: null,
  };
  assert.equal(reusableCheckoutState(currentNoPromo, "monthly", now), true);
  assert.equal(
      reusableCheckoutState(currentNoPromo, "monthly", now, "promo_123"),
      false,
  );

  const currentWithPromo = {
    ...currentNoPromo,
    promotionCodeId: "promo_123",
  };
  assert.equal(
      reusableCheckoutState(currentWithPromo, "monthly", now, "promo_123"),
      true,
  );
  assert.equal(reusableCheckoutState(currentWithPromo, "monthly", now), false);
  assert.equal(
      reusableCheckoutState(currentWithPromo, "monthly", now, "promo_other"),
      false,
  );
});

test("open Checkout blocks changing plans but not changing promo on same plan", () => {
  const now = Date.now();
  const state = {
    status: "created",
    plan: "monthly",
    promotionCodeId: null,
    expiresAt: now + 60_000,
  };
  assert.equal(createdCheckoutBlocksPlanChange(state, "yearly", now), true);
  assert.equal(createdCheckoutBlocksPlanChange(state, "monthly", now), false);
  assert.equal(
      createdCheckoutBlocksPlanChange({...state, expiresAt: now - 1}, "yearly", now),
      false,
  );
});
