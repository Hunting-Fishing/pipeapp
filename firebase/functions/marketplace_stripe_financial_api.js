"use strict";

const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

async function stripeFinancialRequest({
  secretKey,
  path,
  fields,
  method = "POST",
  idempotencyKey,
}) {
  const url = new URL(`https://api.stripe.com${path}`);
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    if (value == null) continue;
    if (method === "GET") {
      if (Array.isArray(value)) {
        for (const item of value) url.searchParams.append(`${key}[]`, String(item));
      } else {
        url.searchParams.append(key, String(value));
      }
    } else if (Array.isArray(value)) {
      for (const item of value) form.append(`${key}[]`, String(item));
    } else {
      form.append(key, String(value));
    }
  }
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Stripe-Version": stripeMarketplaceConfig.apiVersion,
      ...(method === "GET" ? {} : {
        "Content-Type": "application/x-www-form-urlencoded",
      }),
      ...(idempotencyKey ? {"Idempotency-Key": idempotencyKey} : {}),
    },
    ...(method === "GET" ? {} : {body: form.toString()}),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch (_) {
    payload = null;
  }
  if (!response.ok) {
    const error = new Error("Stripe financial operation failed.");
    error.stripeStatus = response.status;
    error.stripeCode = String(
        payload && payload.error &&
        (payload.error.code || payload.error.type) || "provider_error",
    ).slice(0, 120);
    throw error;
  }
  return payload || {};
}

function isStripeDisputeId(value) {
  return /^du_[A-Za-z0-9]+$/u.test(String(value || ""));
}

function isStripeChargeId(value) {
  return /^ch_[A-Za-z0-9]+$/u.test(String(value || ""));
}

function isStripeTransferId(value) {
  return /^tr_[A-Za-z0-9]+$/u.test(String(value || ""));
}

function isStripeFileId(value) {
  return /^file_[A-Za-z0-9]+$/u.test(String(value || ""));
}

module.exports = {
  isStripeChargeId,
  isStripeDisputeId,
  isStripeFileId,
  isStripeTransferId,
  stripeFinancialRequest,
};
