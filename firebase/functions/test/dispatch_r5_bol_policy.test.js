"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  validateDispatchTransactionAction,
} = require("../dispatch_command_policy");

const now = new Date("2026-09-11T18:00:00.000Z");

function job(overrides = {}) {
  return {
    id: "job-1",
    createdByUid: "customer-1",
    status: "awarded",
    ...overrides,
  };
}

function dispatch(overrides = {}) {
  return {
    jobId: "job-1",
    customerUid: "customer-1",
    carrierUid: "carrier-1",
    status: "scheduled",
    workflowVersion: 2,
    scheduledDate: new Date("2026-09-12T18:00:00.000Z"),
    ...overrides,
  };
}

test("R5 carrier records a structured bill of lading without changing job status", () => {
  const result = validateDispatchTransactionAction({
    job: job(),
    dispatchTransaction: dispatch({status: "accepted"}),
    actorUid: "carrier-1",
    action: "record_bol",
    data: {
      bolNumber: "PB-BOL-2026-001",
      bolShipperReference: "PO-88421",
      bolPieceCount: 54,
      bolNotes: "54 joints loaded and counted at origin.",
    },
    now,
  });

  assert.equal(result.status, "accepted");
  assert.equal(result.actorRole, "carrier");
  assert.equal(result.alreadyApplied, false);
  assert.deepEqual(result.billOfLading, {
    number: "PB-BOL-2026-001",
    shipperReference: "PO-88421",
    pieceCount: 54,
    notes: "54 joints loaded and counted at origin.",
  });
});

test("only the awarded carrier can record the bill of lading", () => {
  assert.throws(
      () => validateDispatchTransactionAction({
        job: job(),
        dispatchTransaction: dispatch({status: "accepted"}),
        actorUid: "customer-1",
        action: "record_bol",
        data: {bolNumber: "BOL-1"},
        now,
      }),
      (error) => error && error.code === "permission-denied",
  );
});

test("R5 transport cannot start until a BOL is recorded", () => {
  assert.throws(
      () => validateDispatchTransactionAction({
        job: job(),
        dispatchTransaction: dispatch({billOfLading: null}),
        actorUid: "carrier-1",
        action: "start_transit",
        data: {},
        now,
      }),
      (error) => error &&
        error.code === "failed-precondition" &&
        /bill of lading/i.test(error.message),
  );
});

test("R5 transport starts when the server transaction has a BOL", () => {
  const result = validateDispatchTransactionAction({
    job: job(),
    dispatchTransaction: dispatch({
      billOfLading: {
        number: "PB-BOL-2026-001",
        shipperReference: "PO-88421",
        pieceCount: 54,
        notes: "Loaded and counted.",
      },
    }),
    actorUid: "carrier-1",
    action: "start_transit",
    data: {},
    now,
  });
  assert.equal(result.status, "in_transit");
});

test("legacy awarded transactions remain compatible without a BOL", () => {
  const result = validateDispatchTransactionAction({
    job: job(),
    dispatchTransaction: dispatch({workflowVersion: 1, billOfLading: null}),
    actorUid: "carrier-1",
    action: "start_transit",
    data: {},
    now,
  });
  assert.equal(result.status, "in_transit");
});

test("BOL piece count must be a positive whole number when supplied", () => {
  assert.throws(
      () => validateDispatchTransactionAction({
        job: job(),
        dispatchTransaction: dispatch({status: "accepted"}),
        actorUid: "carrier-1",
        action: "record_bol",
        data: {bolNumber: "BOL-1", bolPieceCount: 2.5},
        now,
      }),
      (error) => error && error.code === "invalid-argument",
  );
});
