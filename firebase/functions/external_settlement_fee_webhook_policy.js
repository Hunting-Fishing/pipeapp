"use strict";

function safeAttempt(value) {
  const attempt = Number(value);
  return Number.isSafeInteger(attempt) && attempt > 0 ? attempt : 0;
}

function feeOnlyWebhookTransition(event = {}) {
  const type = String(event.type || "").trim();
  const session = event.data && event.data.object || {};
  const billingType = String(
      session.metadata && session.metadata.billingType || "",
  ).trim();
  if (billingType !== "marketplace_fee_only") return null;
  if (type === "checkout.session.async_payment_failed") {
    return "payment_failed";
  }
  if (type === "checkout.session.completed" &&
      String(session.payment_status || "") !== "paid") {
    return "processing";
  }
  return null;
}

function externalFeeWebhookTransitionDecision({
  currentStatus = "",
  currentSessionId = "",
  currentAttempt = 0,
  eventSessionId = "",
  eventAttempt = 0,
  nextStatus = "",
} = {}) {
  const current = String(currentStatus || "").trim();
  const currentSession = String(currentSessionId || "").trim();
  const eventSession = String(eventSessionId || "").trim();
  const currentAttemptNumber = safeAttempt(currentAttempt);
  const eventAttemptNumber = safeAttempt(eventAttempt);
  const next = String(nextStatus || "").trim();
  if (!["processing", "payment_failed"].includes(next)) {
    return Object.freeze({action: "review", reason: "invalid_transition"});
  }
  if (current === "collected") {
    return Object.freeze({action: "ignore", reason: "already_collected"});
  }
  if (eventAttemptNumber > 0 && currentAttemptNumber > 0 &&
      eventAttemptNumber < currentAttemptNumber) {
    return Object.freeze({action: "ignore", reason: "stale_attempt"});
  }
  const sameOrUnknownAttempt = eventAttemptNumber === 0 ||
    currentAttemptNumber === 0 || eventAttemptNumber === currentAttemptNumber;
  if (currentSession && eventSession && currentSession !== eventSession &&
      sameOrUnknownAttempt && eventAttemptNumber <= currentAttemptNumber) {
    return Object.freeze({action: "review", reason: "session_conflict"});
  }
  if (current === "payment_failed" && next === "processing" &&
      (eventAttemptNumber === 0 || currentAttemptNumber === 0 ||
       eventAttemptNumber <= currentAttemptNumber)) {
    return Object.freeze({action: "ignore", reason: "attempt_already_failed"});
  }
  return Object.freeze({
    action: "apply",
    nextStatus: next,
    eventAttempt: eventAttemptNumber,
  });
}

module.exports = {
  externalFeeWebhookTransitionDecision,
  feeOnlyWebhookTransition,
  safeAttempt,
};
