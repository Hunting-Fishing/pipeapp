"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SMALL_SUPPLIER_THRESHOLD_CAD_MINOR,
  canadaSmallSupplierThresholdState,
} = require("../canada_small_supplier_policy");

test("small supplier threshold is CAD 30000", () => {
  assert.equal(SMALL_SUPPLIER_THRESHOLD_CAD_MINOR, 3000000);
});

test("amounts below 75 percent remain within threshold", () => {
  const state = canadaSmallSupplierThresholdState({
    singleQuarterCadMinor: 1000000,
    rollingFourQuarterCadMinor: 2000000,
  });
  assert.equal(state.level, "within_threshold");
  assert.equal(state.exceeded, false);
  assert.equal(state.remainingCadMinor, 1000000);
});

test("75 and 90 percent create warning bands", () => {
  assert.equal(canadaSmallSupplierThresholdState({
    rollingFourQuarterCadMinor: 2250000,
  }).level, "warning");
  assert.equal(canadaSmallSupplierThresholdState({
    rollingFourQuarterCadMinor: 2700000,
  }).level, "high_warning");
});

test("exactly CAD 30000 does not exceed the CRA threshold", () => {
  const state = canadaSmallSupplierThresholdState({
    singleQuarterCadMinor: 3000000,
  });
  assert.equal(state.exceeded, false);
  assert.equal(state.remainingCadMinor, 0);
  assert.equal(state.level, "high_warning");
});

test("one cent over the threshold records the applicable exceeded test", () => {
  const quarter = canadaSmallSupplierThresholdState({
    singleQuarterCadMinor: 3000001,
    rollingFourQuarterCadMinor: 2000000,
  });
  assert.equal(quarter.level, "exceeded");
  assert.equal(quarter.exceededSingleQuarter, true);
  assert.equal(quarter.exceededRolling, false);

  const rolling = canadaSmallSupplierThresholdState({
    singleQuarterCadMinor: 1000000,
    rollingFourQuarterCadMinor: 3000001,
  });
  assert.equal(rolling.exceededSingleQuarter, false);
  assert.equal(rolling.exceededRolling, true);
});

test("negative or fractional tax revenue inputs fail closed", () => {
  assert.throws(
      () => canadaSmallSupplierThresholdState({singleQuarterCadMinor: -1}),
      /non-negative integer/i,
  );
  assert.throws(
      () => canadaSmallSupplierThresholdState({rollingFourQuarterCadMinor: 1.5}),
      /non-negative integer/i,
  );
});
