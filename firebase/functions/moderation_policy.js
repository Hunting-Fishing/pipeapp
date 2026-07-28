"use strict";

const REVIEW_DECISIONS = new Set([
  "dismissed",
  "information_requested",
  "violation_confirmed",
]);
const ENFORCEMENT_ACTIONS = new Set([
  "none",
  "warning",
  "content_removed",
]);
const APPEAL_DECISIONS = new Set(["upheld", "overturned"]);

class ModerationPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ModerationPolicyError";
    this.code = code;
  }
}

function requiredText(data, fieldName, maximumLength) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > maximumLength) {
    throw new ModerationPolicyError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function validateModerationDecision(data) {
  const decision = requiredText(data, "decision", 40);
  const reason = requiredText(data, "reason", 1000);
  const enforcementAction = String(data && data.enforcementAction || "none")
      .trim();
  if (!REVIEW_DECISIONS.has(decision)) {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Select an approved moderation decision.",
    );
  }
  if (reason.length < 10) {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Record a review rationale of at least 10 characters.",
    );
  }
  if (!ENFORCEMENT_ACTIONS.has(enforcementAction)) {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Select an approved enforcement action.",
    );
  }
  if (decision !== "violation_confirmed" && enforcementAction !== "none") {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Enforcement can only follow a confirmed violation.",
    );
  }
  return {decision, reason, enforcementAction};
}

function validateModerationAppeal(data) {
  const reason = requiredText(data, "reason", 2000);
  if (reason.length < 20) {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Explain the appeal in at least 20 characters.",
    );
  }
  return {reason};
}

function validateModerationAppealDecision(data) {
  const decision = requiredText(data, "decision", 30);
  const reason = requiredText(data, "reason", 1000);
  if (!APPEAL_DECISIONS.has(decision)) {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Select an approved appeal decision.",
    );
  }
  if (reason.length < 10) {
    throw new ModerationPolicyError(
        "invalid-argument",
        "Record an appeal rationale of at least 10 characters.",
    );
  }
  return {decision, reason};
}

function appealDeadlineMillis(reviewedAtMillis) {
  return reviewedAtMillis + 30 * 24 * 60 * 60 * 1000;
}

module.exports = {
  APPEAL_DECISIONS,
  ENFORCEMENT_ACTIONS,
  ModerationPolicyError,
  REVIEW_DECISIONS,
  appealDeadlineMillis,
  validateModerationAppeal,
  validateModerationAppealDecision,
  validateModerationDecision,
};
