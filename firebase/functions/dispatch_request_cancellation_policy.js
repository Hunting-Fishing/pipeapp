"use strict";

const {CommandPolicyError} = require("./marketplace_command_policy");

function cancellationReason(value) {
  const reason = String(value || "").trim();
  if (reason.length > 500) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The cancellation reason must be 500 characters or fewer.",
    );
  }
  return reason;
}

function validateDispatchRequestCancellation(job, actorUid, reasonValue) {
  if (!job) {
    throw new CommandPolicyError(
        "not-found",
        "This Dispatch request is unavailable.",
    );
  }
  if (String(job.createdByUid || "") !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the request owner can cancel this Dispatch request.",
    );
  }

  const status = String(job.status || "");
  if (status === "cancelled") {
    return {
      alreadyApplied: true,
      reason: String(job.cancellationReason || ""),
    };
  }
  if (status !== "open" && status !== "draft") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only an open or draft Dispatch request can be cancelled here.",
    );
  }

  return {
    alreadyApplied: false,
    reason: cancellationReason(reasonValue),
  };
}

module.exports = {
  cancellationReason,
  validateDispatchRequestCancellation,
};
