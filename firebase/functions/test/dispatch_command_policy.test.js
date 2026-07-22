"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  validateDispatchAward,
  validateDispatchJobChange,
  validateDispatchJobInput,
  validateDispatchQuote,
} = require("../dispatch_command_policy");

const now = new Date("2026-07-19T12:00:00.000Z");

test("Dispatch jobs require complete mapped and dated load details", () => {
  const job = validateDispatchJobInput({
    title: "54 joints of drill pipe",
    pickupLabel: "Grande Prairie, Alberta",
    deliveryLabel: "Dawson Creek, British Columbia",
    truckingDate: now.getTime() + 24 * 60 * 60 * 1000,
    loadDetails: "54 joints, loading assistance available",
    sourceType: "marketplace",
    listingId: "listing",
    estimatedWeightKg: 22000,
    distanceKm: 132.4,
    pickupPoint: {latitude: 55.17, longitude: -118.79},
    deliveryPoint: {latitude: 55.76, longitude: -120.24},
  }, now);
  assert.equal(job.sourceType, "marketplace");
  assert.equal(job.distanceKm, 132.4);
  assert.throws(
      () => validateDispatchJobInput({
        title: "Pipe",
        pickupLabel: "A",
        deliveryLabel: "B",
        truckingDate: now.getTime() + 24 * 60 * 60 * 1000,
        loadDetails: "Pipe",
        sourceType: "auction",
      }, now),
      (error) => error.code === "invalid-argument",
  );
});

test("only owners can edit live Dispatch jobs and revisions are bounded", () => {
  assert.doesNotThrow(() => validateDispatchJobChange({
    createdByUid: "customer",
    status: "open",
    revision: 4,
    updatedAt: now.getTime() - 4000,
  }, "customer", now));
  assert.throws(
      () => validateDispatchJobChange({
        createdByUid: "customer",
        status: "open",
        revision: 4,
      }, "attacker", now),
      (error) => error.code === "permission-denied",
  );
});

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
