"use strict";

function existingExternalFeeSessionDecision({
  localFeeStatus = "",
  providerStatus = "",
  paymentStatus = "",
  checkoutUrlValid = false,
} = {}) {
  const local = String(localFeeStatus || "").trim();
  const provider = String(providerStatus || "").trim();
  const payment = String(paymentStatus || "").trim();
  if (local === "processing" ||
      provider === "complete" ||
      payment === "paid" ||
      payment === "no_payment_required") {
    return Object.freeze({action: "processing"});
  }
  if (provider === "open") {
    return Object.freeze({
      action: checkoutUrlValid ? "reuse" : "invalid_url",
    });
  }
  if (provider === "expired") {
    return Object.freeze({action: "create_new"});
  }
  return Object.freeze({action: "review"});
}

function externalFeePostProviderPersistenceDecision({
  currentStatus = "",
  currentSessionId = "",
  currentAttempt = 0,
  createdSessionId = "",
  createdAttempt = 0,
} = {}) {
  const status = String(currentStatus || "").trim();
  const currentSession = String(currentSessionId || "").trim();
  const createdSession = String(createdSessionId || "").trim();
  const currentAttemptNumber = Number(currentAttempt);
  const createdAttemptNumber = Number(createdAttempt);
  if (status === "collected") return "paid";
  if (currentSession === createdSession && status === "processing") {
    return "processing";
  }
  if (currentSession === createdSession && status === "payment_failed") {
    return "payment_failed";
  }
  if (Number.isSafeInteger(currentAttemptNumber) &&
      Number.isSafeInteger(createdAttemptNumber) &&
      currentAttemptNumber > createdAttemptNumber) {
    return "superseded";
  }
  return "checkout_created";
}

module.exports = {
  existingExternalFeeSessionDecision,
  externalFeePostProviderPersistenceDecision,
};
