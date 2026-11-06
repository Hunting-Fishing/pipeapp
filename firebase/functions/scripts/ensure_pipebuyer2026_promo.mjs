#!/usr/bin/env node
import {execSync} from "node:child_process";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config.js");

const COUPON_ID = "PIPEBUYER_2026_6M_FREE";
const PROMO_CODE = "pipebuyer2026";
const TARGET_PRODUCTS = [
  stripeMarketplaceConfig.products.dispatchMonthlyCad.productId,
  stripeMarketplaceConfig.products.yellowPagesVerifiedProMonthly.productId,
  stripeMarketplaceConfig.products.yellowPagesFeaturedMonthly.productId,
];

function loadProductionStripeSecret() {
  const fromEnv = String(process.env.STRIPE_SECRET_PRODUCTION || "").trim();
  if (fromEnv) return fromEnv;
  const raw = execSync(
      "gcloud secrets versions access latest --secret=STRIPE_SECRET_PRODUCTION --project=flutter-flow-pipe",
      {encoding: "utf8", stdio: ["ignore", "pipe", "pipe"]},
  ).trim();
  if (!raw.startsWith("sk_live_") && !raw.startsWith("rk_live_")) {
    throw new Error("Unexpected STRIPE_SECRET_PRODUCTION prefix from Secret Manager.");
  }
  return raw;
}

function encodeFormFields(fields) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    if (value === undefined || value === null || value === "") continue;
    if (Array.isArray(value)) {
      value.forEach((item, idx) => {
        params.append(`${key}[${idx}]`, String(item));
      });
    } else {
      params.append(key, String(value));
    }
  }
  return params.toString();
}

async function stripeRequest({secretKey, path, method = "GET", fields = null}) {
  const headers = {
    "Authorization": `Bearer ${secretKey}`,
    "Stripe-Version": stripeMarketplaceConfig.apiVersion,
  };
  let body;
  if (method !== "GET" && fields) {
    headers["Content-Type"] = "application/x-www-form-urlencoded";
    body = encodeFormFields(fields);
  }
  const res = await fetch(`https://api.stripe.com${path}`, {
    method,
    headers,
    body,
  });
  const payload = await res.json();
  if (!res.ok) {
    const err = new Error(
        (payload && payload.error && payload.error.message) ||
        `Stripe HTTP ${res.status} on ${method} ${path}`,
    );
    err.status = res.status;
    err.stripeCode = payload && payload.error && payload.error.code;
    err.stripeParam = payload && payload.error && payload.error.param;
    throw err;
  }
  return payload;
}

function extractExpandedCoupon(promo) {
  const nested = promo && promo.promotion && promo.promotion.coupon;
  if (nested && typeof nested === "object") return nested;
  if (promo && promo.coupon && typeof promo.coupon === "object") return promo.coupon;
  return null;
}

async function ensureCoupon(secretKey) {
  try {
    const existing = await stripeRequest({
      secretKey,
      path: `/v1/coupons/${encodeURIComponent(COUPON_ID)}?expand%5B%5D=applies_to`,
      method: "GET",
    });
    const products = (existing.applies_to && existing.applies_to.products) || [];
    const missingProducts = TARGET_PRODUCTS.filter((id) => !products.includes(id));
    if (
      existing.valid === true &&
      Number(existing.percent_off) === 100 &&
      existing.duration === "repeating" &&
      Number(existing.duration_in_months) === 6 &&
      missingProducts.length === 0
    ) {
      return {coupon: existing, created: false};
    }
    throw new Error(
        `Existing coupon ${COUPON_ID} does not match expected 100%-off 6-month spec (missing products: ${missingProducts.join(",")}).`,
    );
  } catch (err) {
    if (err.status !== 404 && err.stripeCode !== "resource_missing") {
      throw err;
    }
  }

  const created = await stripeRequest({
    secretKey,
    path: "/v1/coupons?expand%5B%5D=applies_to",
    method: "POST",
    fields: {
      "id": COUPON_ID,
      "name": "PipeBuyer 2026 - First 6 Months Free",
      "percent_off": 100,
      "duration": "repeating",
      "duration_in_months": 6,
      "applies_to[products]": TARGET_PRODUCTS,
      "metadata[campaign]": "yellow_pages_outreach_2026",
      "metadata[promoCode]": PROMO_CODE,
    },
  });
  return {coupon: created, created: true};
}

async function ensurePromotionCode(secretKey, couponId) {
  const existingList = await stripeRequest({
    secretKey,
    path: `/v1/promotion_codes?code=${encodeURIComponent(PROMO_CODE)}&limit=10&expand%5B%5D=data.promotion.coupon`,
    method: "GET",
  });
  const activeMatch = (existingList.data || []).find(
      (entry) =>
        entry &&
        entry.active === true &&
        String(entry.code || "").toLowerCase() === PROMO_CODE.toLowerCase(),
  );
  if (activeMatch) {
    const attachedCoupon = extractExpandedCoupon(activeMatch);
    const attachedCouponId = attachedCoupon ?
      attachedCoupon.id :
      (activeMatch.promotion && activeMatch.promotion.coupon);
    if (attachedCouponId !== couponId) {
      throw new Error(
          `Active promo code ${PROMO_CODE} (${activeMatch.id}) points to ${attachedCouponId} instead of ${couponId}.`,
      );
    }
    return {promotionCode: activeMatch, created: false};
  }

  let created;
  try {
    created = await stripeRequest({
      secretKey,
      path: "/v1/promotion_codes?expand%5B%5D=promotion.coupon",
      method: "POST",
      fields: {
        "code": PROMO_CODE,
        "active": "true",
        "promotion[type]": "coupon",
        "promotion[coupon]": couponId,
        "metadata[campaign]": "yellow_pages_outreach_2026",
        "metadata[benefit]": "first_6_months_free",
      },
    });
  } catch (err) {
    if (err.stripeParam && String(err.stripeParam).startsWith("promotion")) {
      created = await stripeRequest({
        secretKey,
        path: "/v1/promotion_codes",
        method: "POST",
        fields: {
          "code": PROMO_CODE,
          "active": "true",
          "coupon": couponId,
          "metadata[campaign]": "yellow_pages_outreach_2026",
          "metadata[benefit]": "first_6_months_free",
        },
      });
    } else {
      throw err;
    }
  }
  return {promotionCode: created, created: true};
}

async function verifyCaseInsensitiveLookup(secretKey) {
  const upperRes = await stripeRequest({
    secretKey,
    path: `/v1/promotion_codes?active=true&limit=10&code=${encodeURIComponent(PROMO_CODE.toUpperCase())}&expand%5B%5D=data.promotion.coupon`,
    method: "GET",
  });
  const lowerRes = await stripeRequest({
    secretKey,
    path: `/v1/promotion_codes?active=true&limit=10&code=${encodeURIComponent(PROMO_CODE.toLowerCase())}&expand%5B%5D=data.promotion.coupon`,
    method: "GET",
  });
  return {
    upperMatches: (upperRes.data || []).length,
    lowerMatches: (lowerRes.data || []).length,
  };
}

async function main() {
  const secretKey = loadProductionStripeSecret();
  const {coupon, created: couponCreated} = await ensureCoupon(secretKey);
  const {promotionCode, created: promoCreated} = await ensurePromotionCode(
      secretKey,
      coupon.id,
  );
  const lookupCheck = await verifyCaseInsensitiveLookup(secretKey);

  console.log(JSON.stringify({
    ok: true,
    apiVersion: stripeMarketplaceConfig.apiVersion,
    coupon: {
      id: coupon.id,
      name: coupon.name,
      percentOff: coupon.percent_off,
      duration: coupon.duration,
      durationInMonths: coupon.duration_in_months,
      appliesToProducts: coupon.applies_to && coupon.applies_to.products,
      created: couponCreated,
    },
    promotionCode: {
      id: promotionCode.id,
      code: promotionCode.code,
      active: promotionCode.active,
      created: promoCreated,
    },
    lookupCheck,
  }, null, 2));
}

main().catch((err) => {
  console.error("Failed to provision pipebuyer2026 in Stripe:", err.message);
  process.exit(1);
});
