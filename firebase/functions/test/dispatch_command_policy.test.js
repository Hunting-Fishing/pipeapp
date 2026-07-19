"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  validateDispatchAward,
  validateDispatchQuote,
} = require("../dispatch_command_policy");

const now = new Date("2026-07-19T12:00:00.000Z");

test("carrier quote validates enrollment, fleet ownership, and payload", () => {
  const proposal = validateDispatchQuote({
    job: {
      createdByUid: "customer",
      status: "open",
      estimatedWeightKg: 20000,
    },
    carrier: {
      ownerUid: "carrier",
      status: "active",
      availableForHire: true,
    },
    vehicle: {
      ownerUid: "carrier",
      available: true,
      maximumPayloadKg: 25000,
    },
    existingBid: null,
    actorUid: "carrier",
    data: {
      jobId: "job",
      amount: 2500,
      note: "Includes permits",
      availableDate: now.getTime() + 24 * 60 * 60 * 1000,
    },
    now,
  });
  assert.equal(proposal.amount, 2500);
  assert.throws(
      () => validateDispatchQuote({
        job: {
          createdByUid: "customer",
          status: "open",
          estimatedWeightKg: 30000,
        },
        carrier: {
          ownerUid: "carrier",
          status: "active",
        },
        vehicle: {
          ownerUid: "carrier",
          maximumPayloadKg: 25000,
        },
        existingBid: null,
        actorUid: "carrier",
        data: {
          jobId: "job",
          amount: 2500,
          availableDate: now.getTime() + 24 * 60 * 60 * 1000,
        },
        now,
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("job owners cannot quote their own requests", () => {
  assert.throws(
      () => validateDispatchQuote({
        job: {createdByUid: "carrier", status: "open"},
        carrier: {ownerUid: "carrier", status: "active"},
        vehicle: {ownerUid: "carrier", maximumPayloadKg: 25000},
        existingBid: null,
        actorUid: "carrier",
        data: {
          jobId: "job",
          amount: 2500,
          availableDate: now.getTime() + 24 * 60 * 60 * 1000,
        },
        now,
      }),
      (error) => error.code === "permission-denied",
  );
});

test("award derives carrier and amount from the pending quote", () => {
  assert.deepEqual(
      validateDispatchAward(
          {id: "job", createdByUid: "customer", status: "open"},
          {
            jobId: "job",
            carrierUid: "carrier",
            amount: 2500,
            status: "pending",
          },
          "customer",
      ),
      {carrierUid: "carrier", amount: 2500},
  );
});
