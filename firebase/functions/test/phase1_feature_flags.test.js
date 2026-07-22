"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  FeatureFlagError,
  normalizePhase1FeatureFlags,
  requirePhase1Feature,
  safeDefaults,
} = require("../phase1_feature_flags");

test("missing configuration keeps core features and closes high-risk paths", () => {
  const flags = normalizePhase1FeatureFlags(null);

  assert.equal(flags.marketplace, true);
  assert.equal(flags.wantedAds, true);
  assert.equal(flags.offers, true);
  assert.equal(flags.auctions, false);
  assert.equal(flags.dispatch, false);
  assert.equal(flags.paidFeatures, false);
  assert.equal(flags.regulatedListings, false);
  assert.deepEqual(
      Object.fromEntries(Object.keys(safeDefaults).map(
          (key) => [key, flags[key]],
      )),
      safeDefaults,
  );
});

test("explicit booleans override defaults without accepting truthy values", () => {
  const flags = normalizePhase1FeatureFlags({
    marketplace: false,
    auctions: true,
    dispatch: "true",
    revision: 4,
  });

  assert.equal(flags.marketplace, false);
  assert.equal(flags.auctions, true);
  assert.equal(flags.dispatch, false);
  assert.equal(flags.revision, 4);
});

test("disabled and unknown feature checks fail with a safe policy error", () => {
  const flags = normalizePhase1FeatureFlags({offers: false});

  assert.throws(
      () => requirePhase1Feature(flags, "offers"),
      (error) =>
        error instanceof FeatureFlagError &&
        error.code === "failed-precondition",
  );
  assert.throws(
      () => requirePhase1Feature(flags, "unknown"),
      (error) => error instanceof FeatureFlagError,
  );
});
