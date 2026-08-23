"use strict";

const ACTIVE_FEE_CHECKOUT_STATUSES = Object.freeze(new Set([
  "checkout_created",
  "processing",
]));

function externalFeeCheckoutAttempt(sale) {
  const value = Number(sale && sale.marketplaceFeeCheckoutAttempt);
  if (!Number.isSafeInteger(value) || value < 0) return 0;
  return value;
}

function nextExternalFeeCheckoutAttempt(sale) {
  return externalFeeCheckoutAttempt(sale) + 1;
}

function externalFeeCheckoutSessionId(sale) {
  const value = String(
      sale && sale.stripeMarketplaceFeeSessionId || "",
  ).trim();
  return value.startsWith("cs_") ? value : "";
}

function externalFeeCheckoutState(sale) {
  const status = String(sale && sale.marketplaceFeeStatus || "").trim();
  const sessionId = externalFeeCheckoutSessionId(sale);
  if (status === "collected") return "paid";
  if (ACTIVE_FEE_CHECKOUT_STATUSES.has(status)) {
    return sessionId ? "active" : "inconsistent";
  }
  return "create";
}

function externalFeeCheckoutIdempotencyKey(transactionId, attempt) {
  const normalizedId = String(transactionId || "").trim();
  const normalizedAttempt = Number(attempt);
  if (!normalizedId ||
      normalizedId.length > 180 ||
      normalizedId.includes("/") ||
      !Number.isSafeInteger(normalizedAttempt) ||
      normalizedAttempt < 1) {
    throw new Error("Invalid external fee checkout idempotency input.");
  }
  return `pipebuyer-external-fee-${normalizedId}-attempt-${normalizedAttempt}`;
}

module.exports = {
  ACTIVE_FEE_CHECKOUT_STATUSES,
  externalFeeCheckoutAttempt,
  externalFeeCheckoutIdempotencyKey,
  externalFeeCheckoutSessionId,
  externalFeeCheckoutState,
  nextExternalFeeCheckoutAttempt,
};
