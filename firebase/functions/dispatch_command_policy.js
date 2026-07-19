"use strict";

const {
  CommandPolicyError,
  requireMoney,
} = require("./marketplace_command_policy");

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function validateQuoteDate(value, now) {
  const milliseconds = Number(value);
  const nowMillis = timestampMillis(now);
  if (
    !Number.isInteger(milliseconds) ||
    milliseconds < nowMillis - 24 * 60 * 60 * 1000 ||
    milliseconds > nowMillis + 730 * 24 * 60 * 60 * 1000
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Carrier availability must be within the next two years.",
    );
  }
  return milliseconds;
}

function validateDispatchQuote({
  job,
  carrier,
  vehicle,
  existingBid,
  actorUid,
  data,
  now,
}) {
  if (!job || job.status !== "open") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch job is no longer open.",
    );
  }
  if (job.createdByUid === actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "You cannot quote your own Dispatch request.",
    );
  }
  if (
    !carrier ||
    carrier.ownerUid !== actorUid ||
    carrier.status !== "active" ||
    carrier.availableForHire === false
  ) {
    throw new CommandPolicyError(
        "permission-denied",
        "Complete active Dispatch enrollment before quoting.",
    );
  }
  if (
    !vehicle ||
    vehicle.ownerUid !== actorUid ||
    vehicle.available === false
  ) {
    throw new CommandPolicyError(
        "permission-denied",
        "Choose an available vehicle from your fleet.",
    );
  }
  if (
    existingBid &&
    (existingBid.carrierUid !== actorUid ||
     existingBid.jobId !== data.jobId ||
     existingBid.status !== "pending")
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This carrier quote cannot be revised.",
    );
  }
  const amount = requireMoney(data.amount, "Carrier quote");
  const note = String(data.note || "").trim();
  if (note.length > 2000) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Quote notes must be 2,000 characters or fewer.",
    );
  }
  const availableDate = validateQuoteDate(data.availableDate, now);
  const payload = Number(
      vehicle.maximumPayloadKg || vehicle.calculatedPayloadKg || 0,
  );
  const loadWeight = Number(
      job.estimatedWeightKg || job.catalogWeightKg || 0,
  );
  if (
    Number.isFinite(payload) &&
    payload > 0 &&
    Number.isFinite(loadWeight) &&
    loadWeight > payload
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The selected vehicle payload is below the job's estimated weight.",
    );
  }
  if (existingBid) {
    const updatedAt = timestampMillis(
        existingBid.updatedAt || existingBid.createdAt,
    );
    if (updatedAt != null && timestampMillis(now) - updatedAt < 5000) {
      throw new CommandPolicyError(
          "resource-exhausted",
          "Wait a few seconds before revising this carrier quote.",
      );
    }
    if (Number(existingBid.revision || 1) >= 50) {
      throw new CommandPolicyError(
          "resource-exhausted",
          "The carrier quote revision limit has been reached.",
      );
    }
  }
  return {amount, note, availableDate};
}

function validateDispatchAward(job, bid, actorUid) {
  if (!job || job.createdByUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the Dispatch request owner can award this job.",
    );
  }
  if (job.status !== "open") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch job is no longer open.",
    );
  }
  if (
    !bid ||
    bid.jobId !== job.id ||
    bid.status !== "pending" ||
    !String(bid.carrierUid || "") ||
    !Number.isFinite(Number(bid.amount)) ||
    Number(bid.amount) <= 0
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The selected carrier quote is unavailable.",
    );
  }
  return {
    carrierUid: bid.carrierUid,
    amount: Number(bid.amount),
  };
}

module.exports = {
  validateDispatchAward,
  validateDispatchQuote,
};
