"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assessmentFromRequest,
} = require("../canada_small_supplier_threshold_commands");

test("threshold assessment requires worldwide and associated-business attestation", () => {
  assert.throws(
      () => assessmentFromRequest({
        periodLabel: "2026 Q3",
        sourceNote: "Reviewed from bookkeeping records and external business totals.",
        singleQuarterCadMinor: 100000,
        rollingFourQuarterCadMinor: 200000,
      }),
      /worldwide taxable supplies and associated businesses/i,
  );
});

test("threshold assessment records normal small supplier state", () => {
  const assessment = assessmentFromRequest({
    periodLabel: "2026 Q3",
    sourceNote: "Reviewed from bookkeeping records and associated-business totals.",
    worldwideAndAssociatedIncluded: true,
    singleQuarterCadMinor: 500000,
    rollingFourQuarterCadMinor: 1200000,
  });
  assert.equal(assessment.level, "within_threshold");
  assert.equal(assessment.requiresRegistrationReview, false);
  assert.equal(assessment.remainingCadMinor, 1800000);
});

test("threshold assessment flags registration review when either CRA test is exceeded", () => {
  const assessment = assessmentFromRequest({
    periodLabel: "2026 Q4",
    sourceNote: "Reviewed from bookkeeping records and associated-business totals.",
    worldwideAndAssociatedIncluded: true,
    singleQuarterCadMinor: 3000001,
    rollingFourQuarterCadMinor: 3000001,
  });
  assert.equal(assessment.level, "exceeded");
  assert.equal(assessment.requiresRegistrationReview, true);
});

test("threshold assessment rejects fractional monetary input", () => {
  assert.throws(
      () => assessmentFromRequest({
        periodLabel: "2026 Q3",
        sourceNote: "Reviewed from bookkeeping records and associated-business totals.",
        worldwideAndAssociatedIncluded: true,
        singleQuarterCadMinor: 1.5,
        rollingFourQuarterCadMinor: 100,
      }),
      /integer amount in CAD cents/i,
  );
});
