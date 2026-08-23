"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  smallSupplierBillingEvidence,
} = require("../canada_small_supplier_threshold_commands");

function validAssessment(overrides = {}) {
  return {
    worldwideAndAssociatedIncluded: true,
    singleQuarterCadMinor: 1000000,
    rollingFourQuarterCadMinor: 2000000,
    thresholdCadMinor: 3000000,
    exceeded: false,
    requiresRegistrationReview: false,
    revision: 7,
    ...overrides,
  };
}

function activeReadiness(overrides = {}) {
  return {
    canadaGstHstSmallSupplier: true,
    canadaGstHstSmallSupplierAssessmentRevision: 7,
    ...overrides,
  };
}

test("small-supplier evidence is not applicable when mode is inactive", () => {
  const result = smallSupplierBillingEvidence({}, validAssessment());
  assert.equal(result.applicable, false);
  assert.equal(result.ready, false);
  assert.equal(result.reason, "small_supplier_inactive");
});

test("small-supplier evidence is ready only when audited revision is current", () => {
  const result = smallSupplierBillingEvidence(
      activeReadiness(),
      validAssessment(),
  );
  assert.equal(result.applicable, true);
  assert.equal(result.ready, true);
  assert.equal(result.reason, "authorized");
  assert.equal(result.assessmentRevision, 7);
  assert.equal(result.boundRevision, 7);
});

test("small-supplier evidence fails closed when assessment binding is stale", () => {
  const result = smallSupplierBillingEvidence(
      activeReadiness({canadaGstHstSmallSupplierAssessmentRevision: 6}),
      validAssessment(),
  );
  assert.equal(result.applicable, true);
  assert.equal(result.ready, false);
  assert.equal(result.reason, "assessment_revision_mismatch");
  assert.equal(result.assessmentRevision, 7);
  assert.equal(result.boundRevision, 6);
});

test("small-supplier evidence fails closed when threshold is exceeded", () => {
  const result = smallSupplierBillingEvidence(
      activeReadiness(),
      validAssessment({
        singleQuarterCadMinor: 3000001,
        exceeded: true,
        requiresRegistrationReview: true,
      }),
  );
  assert.equal(result.applicable, true);
  assert.equal(result.ready, false);
  assert.equal(result.reason, "threshold_exceeded");
});

test("small-supplier evidence fails closed when assessment is missing", () => {
  const result = smallSupplierBillingEvidence(activeReadiness(), null);
  assert.equal(result.applicable, true);
  assert.equal(result.ready, false);
  assert.equal(result.reason, "assessment_missing");
});
