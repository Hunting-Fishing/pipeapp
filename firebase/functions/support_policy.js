"use strict";

const SUPPORT_CATEGORIES = new Set([
  "account_access",
  "transaction",
  "safety",
  "dispatch",
  "technical",
  "other",
]);
const SUPPORT_ACTIONS = new Set([
  "acknowledge",
  "respond",
  "resolve",
  "reopen",
  "escalate",
]);

class SupportPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "SupportPolicyError";
    this.code = code;
  }
}

function requiredText(data, fieldName, maximumLength) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > maximumLength) {
    throw new SupportPolicyError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function optionalText(data, fieldName, maximumLength) {
  const value = String(data && data[fieldName] || "").trim();
  if (value.length > maximumLength) {
    throw new SupportPolicyError(
        "invalid-argument",
        `${fieldName} is too long.`,
    );
  }
  return value;
}

function categoryServiceLevel(category) {
  switch (category) {
    case "safety":
      return {priority: "urgent", firstResponseHours: 4};
    case "account_access":
    case "transaction":
      return {priority: "high", firstResponseHours: 24};
    default:
      return {priority: "normal", firstResponseHours: 48};
  }
}

function validateSupportCaseInput(data) {
  const category = requiredText(data, "category", 40);
  const subject = requiredText(data, "subject", 120);
  const description = requiredText(data, "description", 4000);
  if (!SUPPORT_CATEGORIES.has(category)) {
    throw new SupportPolicyError(
        "invalid-argument",
        "Select an approved support category.",
    );
  }
  if (subject.length < 5 || description.length < 20) {
    throw new SupportPolicyError(
        "invalid-argument",
        "Provide a clear subject and at least 20 characters of detail.",
    );
  }
  const relatedType = optionalText(data, "relatedType", 40);
  const relatedId = optionalText(data, "relatedId", 180);
  if (relatedId.includes("/")) {
    throw new SupportPolicyError(
        "invalid-argument",
        "The related reference is invalid.",
    );
  }
  return {
    category,
    subject,
    description,
    relatedType,
    relatedId,
    ...categoryServiceLevel(category),
  };
}

function validateSupportResponse(data) {
  const action = requiredText(data, "action", 30);
  const message = requiredText(data, "message", 2000);
  if (!SUPPORT_ACTIONS.has(action)) {
    throw new SupportPolicyError(
        "invalid-argument",
        "Select an approved support action.",
    );
  }
  if (message.length < 10) {
    throw new SupportPolicyError(
        "invalid-argument",
        "Provide a response of at least 10 characters.",
    );
  }
  return {action, message};
}

function validateSupportReply(data) {
  const message = requiredText(data, "message", 2000);
  if (message.length < 10) {
    throw new SupportPolicyError(
        "invalid-argument",
        "Provide a reply of at least 10 characters.",
    );
  }
  return {message};
}

function supportStatusForAction(action) {
  return {
    acknowledge: "in_review",
    respond: "waiting_customer",
    resolve: "resolved",
    reopen: "in_review",
    escalate: "escalated",
  }[action];
}

function assertSupportTransition(currentStatus, action) {
  const allowed = {
    open: new Set(["acknowledge", "respond", "resolve", "escalate"]),
    in_review: new Set(["respond", "resolve", "escalate"]),
    waiting_customer: new Set(["respond", "resolve", "escalate"]),
    escalated: new Set(["respond", "resolve"]),
    resolved: new Set(["reopen"]),
  }[currentStatus];
  if (!allowed || !allowed.has(action)) {
    throw new SupportPolicyError(
        "failed-precondition",
        "This support case action is not available in its current state.",
    );
  }
  return supportStatusForAction(action);
}

module.exports = {
  SUPPORT_ACTIONS,
  SUPPORT_CATEGORIES,
  SupportPolicyError,
  assertSupportTransition,
  categoryServiceLevel,
  supportStatusForAction,
  validateSupportCaseInput,
  validateSupportReply,
  validateSupportResponse,
};
