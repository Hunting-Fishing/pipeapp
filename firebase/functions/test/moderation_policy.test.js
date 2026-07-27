"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ModerationPolicyError,
  appealDeadlineMillis,
  validateModerationAppeal,
  validateModerationAppealDecision,
  validateModerationDecision,
} = require("../moderation_policy");

test("moderation decisions require rationale and coherent enforcement", () => {
  assert.deepEqual(validateModerationDecision({
    decision: "violation_confirmed",
    reason: "The listing evidence confirms reused photographs.",
    enforcementAction: "content_removed",
  }), {
    decision: "violation_confirmed",
    reason: "The listing evidence confirms reused photographs.",
    enforcementAction: "content_removed",
  });
  assert.throws(
      () => validateModerationDecision({
        decision: "dismissed",
        reason: "The report was not supported by the evidence.",
        enforcementAction: "content_removed",
      }),
      (error) => error instanceof ModerationPolicyError &&
        error.code === "invalid-argument",
  );
  assert.throws(
      () => validateModerationDecision({
        decision: "violation_confirmed",
        reason: "Too short",
        enforcementAction: "warning",
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("appeals require a meaningful reason and approved review outcome", () => {
  assert.equal(validateModerationAppeal({
    reason: "The photos are mine and I can provide the original files.",
  }).reason, "The photos are mine and I can provide the original files.");
  assert.deepEqual(validateModerationAppealDecision({
    decision: "overturned",
    reason: "Original ownership evidence resolves the reported concern.",
  }), {
    decision: "overturned",
    reason: "Original ownership evidence resolves the reported concern.",
  });
  assert.throws(
      () => validateModerationAppeal({reason: "I disagree."}),
      (error) => error.code === "invalid-argument",
  );
  assert.throws(
      () => validateModerationAppealDecision({
        decision: "maybe",
        reason: "This is a sufficiently detailed review rationale.",
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("appeal deadline is exactly thirty days after review", () => {
  const reviewed = Date.UTC(2026, 6, 27, 12, 0, 0);
  assert.equal(
      appealDeadlineMillis(reviewed),
      reviewed + 30 * 24 * 60 * 60 * 1000,
  );
});
