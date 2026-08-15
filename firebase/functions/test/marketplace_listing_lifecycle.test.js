"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DAY_MS,
  MARKETPLACE_LISTING_ACTIVE_DAYS,
  listingExpiryMillis,
  listingLifecycleState,
} = require("../marketplace_listing_lifecycle");

const now = Date.UTC(2026, 7, 15, 12, 0, 0);

test("Marketplace listings expire after 30 days", () => {
  assert.equal(MARKETPLACE_LISTING_ACTIVE_DAYS, 30);
  assert.equal(
      listingExpiryMillis(now),
      now + 30 * DAY_MS,
  );
});

test("active listing reports time remaining", () => {
  const state = listingLifecycleState({
    status: "active",
    expiresAt: now + 12 * DAY_MS,
  }, now);
  assert.equal(state.expired, false);
  assert.equal(state.expiringSoon, false);
  assert.equal(state.remainingMs, 12 * DAY_MS);
});

test("listing enters expiring-soon window three days before expiry", () => {
  const state = listingLifecycleState({
    status: "active",
    expiresAt: now + 2 * DAY_MS,
  }, now);
  assert.equal(state.expired, false);
  assert.equal(state.expiringSoon, true);
});

test("expired status remains explicit even without an expiry timestamp", () => {
  const state = listingLifecycleState({status: "expired"}, now);
  assert.equal(state.expired, true);
});

test("elapsed active or paused listing is treated as expired", () => {
  for (const status of ["active", "paused"]) {
    const state = listingLifecycleState({
      status,
      expiresAt: now - 1,
    }, now);
    assert.equal(state.expired, true);
  }
});
