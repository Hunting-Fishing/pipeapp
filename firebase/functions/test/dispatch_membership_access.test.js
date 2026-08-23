"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchMembershipCurrentForUser,
} = require("../dispatch_membership_access");

test("Dispatch bidding requires an active membership with future paid-through date", () => {
  const now = 1_000_000;
  assert.equal(dispatchMembershipCurrentForUser({
    ownerUid: "carrier_1",
    active: true,
    currentPeriodEnd: {toMillis: () => now + 60_000},
  }, "carrier_1", now), true);

  assert.equal(dispatchMembershipCurrentForUser({
    ownerUid: "carrier_1",
    active: true,
    currentPeriodEnd: {toMillis: () => now - 1},
  }, "carrier_1", now), false);
});

test("Dispatch bidding rejects missing, inactive, or wrong-owner memberships", () => {
  const now = 1_000_000;
  assert.equal(dispatchMembershipCurrentForUser(null, "carrier_1", now), false);
  assert.equal(dispatchMembershipCurrentForUser({
    ownerUid: "carrier_1",
    active: false,
    currentPeriodEnd: {toMillis: () => now + 60_000},
  }, "carrier_1", now), false);
  assert.equal(dispatchMembershipCurrentForUser({
    ownerUid: "carrier_2",
    active: true,
    currentPeriodEnd: {toMillis: () => now + 60_000},
  }, "carrier_1", now), false);
});
