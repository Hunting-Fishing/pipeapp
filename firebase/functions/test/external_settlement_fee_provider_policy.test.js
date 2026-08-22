"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  existingExternalFeeSessionDecision,
  externalFeePostProviderPersistenceDecision,
} = require("../external_settlement_fee_provider_policy");

test("open Stripe fee session is reused only with a valid checkout URL", () => {
  assert.equal(existingExternalFeeSessionDecision({
    providerStatus: "open",
    checkoutUrlValid: true,
  }).action, "reuse");
  assert.equal(existingExternalFeeSessionDecision({
    providerStatus: "open",
    checkoutUrlValid: false,
  }).action, "invalid_url");
});

test("provider completion or paid state is treated as processing", () => {
  assert.equal(existingExternalFeeSessionDecision({
    providerStatus: "complete",
  }).action, "processing");
  assert.equal(existingExternalFeeSessionDecision({
    paymentStatus: "paid",
  }).action, "processing");
  assert.equal(existingExternalFeeSessionDecision({
    paymentStatus: "no_payment_required",
  }).action, "processing");
  assert.equal(existingExternalFeeSessionDecision({
    localFeeStatus: "processing",
    providerStatus: "expired",
  }).action, "processing");
});

test("only expired provider session authorizes a new attempt", () => {
  assert.equal(existingExternalFeeSessionDecision({
    providerStatus: "expired",
  }).action, "create_new");
  assert.equal(existingExternalFeeSessionDecision({
    providerStatus: "weird_future_status",
  }).action, "review");
});

test("post-provider write cannot downgrade collected webhook state", () => {
  assert.equal(externalFeePostProviderPersistenceDecision({
    currentStatus: "collected",
    currentSessionId: "cs_1",
    currentAttempt: 1,
    createdSessionId: "cs_1",
    createdAttempt: 1,
  }), "paid");
});

test("post-provider write preserves processing and failed state for same session", () => {
  assert.equal(externalFeePostProviderPersistenceDecision({
    currentStatus: "processing",
    currentSessionId: "cs_1",
    createdSessionId: "cs_1",
    currentAttempt: 1,
    createdAttempt: 1,
  }), "processing");
  assert.equal(externalFeePostProviderPersistenceDecision({
    currentStatus: "payment_failed",
    currentSessionId: "cs_1",
    createdSessionId: "cs_1",
    currentAttempt: 1,
    createdAttempt: 1,
  }), "payment_failed");
});

test("newer attempt supersedes stale provider response", () => {
  assert.equal(externalFeePostProviderPersistenceDecision({
    currentStatus: "checkout_created",
    currentSessionId: "cs_new",
    currentAttempt: 3,
    createdSessionId: "cs_old",
    createdAttempt: 2,
  }), "superseded");
});

test("normal first provider response persists checkout_created", () => {
  assert.equal(externalFeePostProviderPersistenceDecision({
    currentStatus: "pending_collection",
    currentAttempt: 0,
    createdSessionId: "cs_1",
    createdAttempt: 1,
  }), "checkout_created");
});
