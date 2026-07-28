"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SupportPolicyError,
  assertSupportTransition,
  categoryServiceLevel,
  validateSupportCaseInput,
  validateSupportReply,
  validateSupportResponse,
} = require("../support_policy");

test("support categories derive transparent response targets", () => {
  assert.deepEqual(categoryServiceLevel("safety"), {
    priority: "urgent",
    firstResponseHours: 4,
  });
  assert.deepEqual(categoryServiceLevel("transaction"), {
    priority: "high",
    firstResponseHours: 24,
  });
  assert.deepEqual(categoryServiceLevel("technical"), {
    priority: "normal",
    firstResponseHours: 48,
  });
});

test("support intake validates content and does not trust client priority", () => {
  const input = validateSupportCaseInput({
    category: "safety",
    subject: "Threatening marketplace message",
    description: "A marketplace message contains a specific threat against me.",
    priority: "normal",
    relatedType: "conversation",
    relatedId: "conversation-1",
  });
  assert.equal(input.priority, "urgent");
  assert.equal(input.firstResponseHours, 4);
  assert.throws(
      () => validateSupportCaseInput({
        category: "invented",
        subject: "Invalid category",
        description: "This description is long enough for the policy.",
      }),
      (error) => error instanceof SupportPolicyError &&
        error.code === "invalid-argument",
  );
});

test("support responses and customer replies require meaningful detail", () => {
  assert.deepEqual(validateSupportResponse({
    action: "respond",
    message: "Please attach the transaction reference and screenshot.",
  }), {
    action: "respond",
    message: "Please attach the transaction reference and screenshot.",
  });
  assert.equal(validateSupportReply({
    message: "The transaction reference is offer-12345.",
  }).message, "The transaction reference is offer-12345.");
  assert.throws(
      () => validateSupportReply({message: "Too short"}),
      (error) => error.code === "invalid-argument",
  );
});

test("support case state transitions fail closed", () => {
  assert.equal(assertSupportTransition("open", "acknowledge"), "in_review");
  assert.equal(assertSupportTransition("in_review", "respond"),
      "waiting_customer");
  assert.equal(assertSupportTransition("resolved", "reopen"), "in_review");
  assert.throws(
      () => assertSupportTransition("resolved", "resolve"),
      (error) => error.code === "failed-precondition",
  );
});
