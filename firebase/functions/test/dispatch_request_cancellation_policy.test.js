"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  cancellationReason,
  validateDispatchRequestCancellation,
} = require("../dispatch_request_cancellation_policy");

test("request owner can cancel an open request", () => {
  assert.deepEqual(
      validateDispatchRequestCancellation(
          {createdByUid: "buyer-1", status: "open"},
          "buyer-1",
          "Job no longer required",
      ),
      {alreadyApplied: false, reason: "Job no longer required"},
  );
});

test("cancelled request is idempotent", () => {
  assert.deepEqual(
      validateDispatchRequestCancellation(
          {
            createdByUid: "buyer-1",
            status: "cancelled",
            cancellationReason: "Duplicate request",
          },
          "buyer-1",
          "ignored retry reason",
      ),
      {alreadyApplied: true, reason: "Duplicate request"},
  );
});

test("non-owner cannot cancel a request", () => {
  assert.throws(
      () => validateDispatchRequestCancellation(
          {createdByUid: "buyer-1", status: "open"},
          "buyer-2",
          "",
      ),
      (error) => error && error.code === "permission-denied",
  );
});

test("awarded request cannot use pre-award cancellation", () => {
  assert.throws(
      () => validateDispatchRequestCancellation(
          {createdByUid: "buyer-1", status: "awarded"},
          "buyer-1",
          "",
      ),
      (error) => error && error.code === "failed-precondition",
  );
});

test("cancellation reason is bounded", () => {
  assert.equal(cancellationReason("  duplicate  "), "duplicate");
  assert.throws(
      () => cancellationReason("x".repeat(501)),
      (error) => error && error.code === "invalid-argument",
  );
});
