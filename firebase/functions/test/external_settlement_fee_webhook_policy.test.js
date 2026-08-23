"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  externalFeeWebhookTransitionDecision,
  feeOnlyWebhookTransition,
} = require("../external_settlement_fee_webhook_policy");

function feeEvent(type, overrides = {}) {
  return {
    type,
    data: {
      object: {
        id: "cs_1",
        payment_status: "unpaid",
        metadata: {
          billingType: "marketplace_fee_only",
          checkoutAttempt: "1",
          pipeBuyerTransactionId: "txn_1",
        },
        ...overrides,
      },
    },
  };
}

test("only fee-only non-success events are intercepted", () => {
  assert.equal(
      feeOnlyWebhookTransition(feeEvent("checkout.session.async_payment_failed")),
      "payment_failed",
  );
  assert.equal(
      feeOnlyWebhookTransition(feeEvent("checkout.session.completed")),
      "processing",
  );
  assert.equal(
      feeOnlyWebhookTransition(feeEvent("checkout.session.completed", {
        payment_status: "paid",
      })),
      null,
  );
  assert.equal(feeOnlyWebhookTransition({
    type: "checkout.session.async_payment_failed",
    data: {object: {metadata: {billingType: "dispatch_subscription"}}},
  }), null);
});

test("collected fee cannot be downgraded by late processing or failure", () => {
  for (const nextStatus of ["processing", "payment_failed"]) {
    const decision = externalFeeWebhookTransitionDecision({
      currentStatus: "collected",
      currentSessionId: "cs_1",
      currentAttempt: 1,
      eventSessionId: "cs_1",
      eventAttempt: 1,
      nextStatus,
    });
    assert.equal(decision.action, "ignore");
    assert.equal(decision.reason, "already_collected");
  }
});

test("stale failed event from older attempt cannot overwrite newer checkout", () => {
  const decision = externalFeeWebhookTransitionDecision({
    currentStatus: "checkout_created",
    currentSessionId: "cs_new",
    currentAttempt: 3,
    eventSessionId: "cs_old",
    eventAttempt: 2,
    nextStatus: "payment_failed",
  });
  assert.equal(decision.action, "ignore");
  assert.equal(decision.reason, "stale_attempt");
});

test("processing cannot overwrite a failed terminal state for same attempt", () => {
  const decision = externalFeeWebhookTransitionDecision({
    currentStatus: "payment_failed",
    currentSessionId: "cs_1",
    currentAttempt: 1,
    eventSessionId: "cs_1",
    eventAttempt: 1,
    nextStatus: "processing",
  });
  assert.equal(decision.action, "ignore");
  assert.equal(decision.reason, "attempt_already_failed");
});

test("newer attempt webhook may arrive before callable persistence", () => {
  const decision = externalFeeWebhookTransitionDecision({
    currentStatus: "payment_failed",
    currentSessionId: "cs_old",
    currentAttempt: 1,
    eventSessionId: "cs_new",
    eventAttempt: 2,
    nextStatus: "processing",
  });
  assert.equal(decision.action, "apply");
  assert.equal(decision.eventAttempt, 2);
});

test("same-attempt different-session event is flagged for review", () => {
  const decision = externalFeeWebhookTransitionDecision({
    currentStatus: "checkout_created",
    currentSessionId: "cs_expected",
    currentAttempt: 2,
    eventSessionId: "cs_unexpected",
    eventAttempt: 2,
    nextStatus: "payment_failed",
  });
  assert.equal(decision.action, "review");
  assert.equal(decision.reason, "session_conflict");
});

test("normal same-session processing and failure transitions apply", () => {
  assert.equal(externalFeeWebhookTransitionDecision({
    currentStatus: "checkout_created",
    currentSessionId: "cs_1",
    currentAttempt: 1,
    eventSessionId: "cs_1",
    eventAttempt: 1,
    nextStatus: "processing",
  }).action, "apply");
  assert.equal(externalFeeWebhookTransitionDecision({
    currentStatus: "processing",
    currentSessionId: "cs_1",
    currentAttempt: 1,
    eventSessionId: "cs_1",
    eventAttempt: 1,
    nextStatus: "payment_failed",
  }).action, "apply");
});
