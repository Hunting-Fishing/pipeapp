"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  WEBHOOK_PROCESSING_LEASE_MS,
  stripeWebhookClaimDecision,
  timestampMillis,
} = require("../stripe_webhook_event_claim");

test("processed event is never claimed again", () => {
  assert.deepEqual(
      stripeWebhookClaimDecision({status: "processed"}, 1000),
      {action: "already_processed"},
  );
});

test("active processing lease blocks a simultaneous duplicate", () => {
  const decision = stripeWebhookClaimDecision({
    status: "processing",
    processingLeaseExpiresAt: 5000,
    attempts: 1,
  }, 4000);
  assert.equal(decision.action, "already_processing");
  assert.equal(decision.leaseExpiresAtMillis, 5000);
});

test("expired processing lease can be recovered", () => {
  const decision = stripeWebhookClaimDecision({
    status: "processing",
    processingLeaseExpiresAt: 3999,
    attempts: 2,
  }, 4000);
  assert.equal(decision.action, "claim");
  assert.equal(decision.attempt, 3);
  assert.equal(decision.processingStartedAtMillis, 4000);
  assert.equal(
      decision.processingLeaseExpiresAtMillis,
      4000 + WEBHOOK_PROCESSING_LEASE_MS,
  );
});

test("failed event is retryable and increments attempt", () => {
  const decision = stripeWebhookClaimDecision({
    status: "failed",
    attempts: 4,
  }, 9000);
  assert.equal(decision.action, "claim");
  assert.equal(decision.attempt, 5);
});

test("timestamp helper accepts Firestore-like timestamps", () => {
  assert.equal(timestampMillis({toMillis: () => 1234}), 1234);
  assert.equal(timestampMillis({seconds: 2, nanoseconds: 500000000}), 2500);
});

test("invalid clock input fails closed", () => {
  assert.throws(
      () => stripeWebhookClaimDecision({}, Number.NaN),
      /nowMillis/i,
  );
});
