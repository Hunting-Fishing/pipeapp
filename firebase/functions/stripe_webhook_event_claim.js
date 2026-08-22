"use strict";

const WEBHOOK_PROCESSING_LEASE_MS = 10 * 60 * 1000;

function safeAttempts(value) {
  const attempts = Number(value);
  return Number.isSafeInteger(attempts) && attempts >= 0 ? attempts : 0;
}

function timestampMillis(value) {
  if (value == null) return null;
  if (Number.isFinite(value)) return Number(value);
  if (value instanceof Date) return value.getTime();
  if (typeof value.toMillis === "function") {
    const millis = Number(value.toMillis());
    return Number.isFinite(millis) ? millis : null;
  }
  if (Number.isFinite(value.seconds)) {
    return Number(value.seconds) * 1000 + Math.floor(Number(value.nanoseconds || 0) / 1e6);
  }
  return null;
}

function stripeWebhookClaimDecision(existing = {}, nowMillis = Date.now()) {
  const now = Number(nowMillis);
  if (!Number.isFinite(now) || now < 0) {
    throw new TypeError("nowMillis must be a non-negative finite timestamp.");
  }
  const status = String(existing.status || "").trim();
  if (status === "processed") {
    return Object.freeze({action: "already_processed"});
  }
  if (status === "processing") {
    const leaseExpiresAtMillis = timestampMillis(existing.processingLeaseExpiresAt);
    if (leaseExpiresAtMillis != null && leaseExpiresAtMillis > now) {
      return Object.freeze({
        action: "already_processing",
        leaseExpiresAtMillis,
      });
    }
  }
  return Object.freeze({
    action: "claim",
    attempt: safeAttempts(existing.attempts) + 1,
    processingStartedAtMillis: now,
    processingLeaseExpiresAtMillis: now + WEBHOOK_PROCESSING_LEASE_MS,
  });
}

module.exports = {
  WEBHOOK_PROCESSING_LEASE_MS,
  safeAttempts,
  stripeWebhookClaimDecision,
  timestampMillis,
};
