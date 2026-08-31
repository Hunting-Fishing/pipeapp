"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {stripeFormRequest} = require("./stripe_checkout_commands");
const {
  couponFromPromotionCode,
  normalizePromotionCode,
  promotionCodeSummary,
  selectPromotionCode,
} = require("./dispatch_subscription_promotions");

function promotionCodeTargetsProduct(promotionCode, productId) {
  const coupon = couponFromPromotionCode(promotionCode);
  const products = coupon && coupon.applies_to && coupon.applies_to.products;
  if (!Array.isArray(products) || products.length === 0) return true;
  const normalizedProductId = String(productId || "").trim();
  return normalizedProductId ? products.includes(normalizedProductId) : true;
}

async function resolveSubscriptionPromotionCode({
  secretKey,
  code,
  stripeCustomerId = "",
  existingSubscriber = false,
  productId = "",
  productLabel = "subscription",
}) {
  const normalizedCode = normalizePromotionCode(code, {required: true});
  const path = "/v1/promotion_codes" +
    `?active=true&limit=10&code=${encodeURIComponent(normalizedCode)}` +
    "&expand%5B%5D=data.promotion.coupon";
  const list = await stripeFormRequest({secretKey, path, method: "GET"});
  const promotionCode = selectPromotionCode(
      list && list.data,
      normalizedCode,
      stripeCustomerId,
  );
  if (!promotionCode) {
    throw new HttpsError(
        "invalid-argument",
        "That promo code is not active or is not available for this account.",
    );
  }
  if (!String(promotionCode.id || "").startsWith("promo_")) {
    throw new HttpsError("failed-precondition", "Stripe returned an invalid promo code.");
  }
  const coupon = couponFromPromotionCode(promotionCode);
  if (coupon && coupon.valid === false) {
    throw new HttpsError("failed-precondition", "That promo code has expired.");
  }
  if (!promotionCodeTargetsProduct(promotionCode, productId)) {
    throw new HttpsError(
        "failed-precondition",
        `That promo code is not valid for ${productLabel}.`,
    );
  }
  if (existingSubscriber &&
      promotionCode.restrictions &&
      promotionCode.restrictions.first_time_transaction === true) {
    throw new HttpsError(
        "failed-precondition",
        "This promo code is for new customers and must be used before the first purchase.",
    );
  }
  return {
    id: String(promotionCode.id),
    code: String(promotionCode.code || normalizedCode),
    couponId: String(coupon && coupon.id || ""),
    summary: promotionCodeSummary(promotionCode),
    firstTimeTransaction: Boolean(
        promotionCode.restrictions &&
        promotionCode.restrictions.first_time_transaction === true,
    ),
  };
}

module.exports = {
  promotionCodeTargetsProduct,
  resolveSubscriptionPromotionCode,
};