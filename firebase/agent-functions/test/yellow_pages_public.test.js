"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  isPublicEntryCurrent,
} = require("../yellow_pages_public");

function timestamp(millis) {
  return {toMillis: () => millis};
}

test("public entries fail closed when the paid entitlement has expired", () => {
  const now = Date.now();
  assert.equal(isPublicEntryCurrent({
    verified: true,
    paidThrough: timestamp(now + 60_000),
  }, now), true);
  assert.equal(isPublicEntryCurrent({
    verified: true,
    paidThrough: timestamp(now - 1),
  }, now), false);
  assert.equal(isPublicEntryCurrent({
    verified: true,
    paidThrough: null,
  }, now), false);
});

test("non-expiring paid listings still require verified public state", () => {
  const now = Date.now();
  assert.equal(isPublicEntryCurrent({
    verified: true,
    nonExpiringPaid: true,
  }, now), true);
  assert.equal(isPublicEntryCurrent({
    verified: false,
    nonExpiringPaid: true,
  }, now), false);
});
