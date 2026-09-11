"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  dispatchQuoteValidityStatus,
  validateDispatchAward,
  validateDispatchQuoteCancellation,
} = require("../dispatch_command_policy");

function job(overrides = {}) {
  return {
    id: "job-1",
    createdByUid: "customer-1",
    status: "open",
    ...overrides,
  };
}

function bid(overrides = {}) {
  return {
    jobId: "job-1",
    carrierUid: "carrier-1",
    amount: 1200,
    status: "pending",
    validityStatus: "active",
    quoteVersion: 2,
    ...overrides,
  };
}

test("legacy quote without validityStatus remains active", () => {
  assert.equal(
      dispatchQuoteValidityStatus(bid({validityStatus: undefined})),
      "active",
  );
});

test("award rejects a cancelled quote even if status is accidentally pending", () => {
  assert.throws(
      () => validateDispatchAward(
          job(),
          bid({validityStatus: "cancelled"}),
          "customer-1",
      ),
      (error) => error &&
        error.code === "failed-precondition" &&
        /unavailable/.test(error.message),
  );
});

test("carrier can cancel its active pending quote", () => {
  const result = validateDispatchQuoteCancellation({
    job: job(),
    bid: bid(),
    actorUid: "carrier-1",
    reason: "Equipment became unavailable.",
  });
  assert.equal(result.alreadyApplied, false);
  assert.equal(result.reason, "Equipment became unavailable.");
});

test("quote cancellation rejects another user", () => {
  assert.throws(
      () => validateDispatchQuoteCancellation({
        job: job(),
        bid: bid(),
        actorUid: "carrier-2",
        reason: "Wrong carrier should not cancel.",
      }),
      (error) => error && error.code === "permission-denied",
  );
});

test("quote cancellation is idempotent for an already-cancelled quote", () => {
  const result = validateDispatchQuoteCancellation({
    job: job(),
    bid: bid({status: "cancelled", validityStatus: "cancelled"}),
    actorUid: "carrier-1",
    reason: "Retry cancellation request.",
  });
  assert.equal(result.alreadyApplied, true);
});

test("unknown validity state fails closed", () => {
  assert.equal(dispatchQuoteValidityStatus(bid({validityStatus: "mystery"})), "invalid");
  assert.throws(
      () => validateDispatchAward(
          job(),
          bid({validityStatus: "mystery"}),
          "customer-1",
      ),
      (error) => error && error.code === "failed-precondition",
  );
});
