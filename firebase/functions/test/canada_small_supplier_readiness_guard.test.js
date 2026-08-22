"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  canadaSmallSupplierAssessmentDecision,
  canadaSmallSupplierReadinessDecision,
} = require("../canada_small_supplier_readiness_guard");

function validAssessment(overrides = {}) {
  return {
    revision: 2,
    worldwideAndAssociatedIncluded: true,
    thresholdCadMinor: 3000000,
    singleQuarterCadMinor: 500000,
    rollingFourQuarterCadMinor: 1200000,
    exceeded: false,
    requiresRegistrationReview: false,
    ...overrides,
  };
}

function validReadiness(overrides = {}) {
  return {
    canadaGstHstSmallSupplier: true,
    canadaGstHstSmallSupplierAssessmentRevision: 2,
    ...overrides,
  };
}

test("missing assessment cannot authorize small supplier billing", () => {
  assert.equal(
      canadaSmallSupplierAssessmentDecision(null).reason,
      "assessment_missing",
  );
});

test("worldwide and associated-business attestation is mandatory", () => {
  const decision = canadaSmallSupplierAssessmentDecision(validAssessment({
    worldwideAndAssociatedIncluded: false,
  }));
  assert.equal(decision.authorized, false);
  assert.equal(decision.reason, "attestation_missing");
});

test("valid audited assessment authorizes small supplier readiness", () => {
  const decision = canadaSmallSupplierAssessmentDecision(validAssessment());
  assert.equal(decision.authorized, true);
  assert.equal(decision.revision, 2);
  assert.equal(decision.thresholdCadMinor, 3000000);
});

test("assessment over either threshold test is rejected", () => {
  for (const assessment of [
    validAssessment({singleQuarterCadMinor: 3000001}),
    validAssessment({rollingFourQuarterCadMinor: 3000001}),
    validAssessment({exceeded: true}),
    validAssessment({requiresRegistrationReview: true}),
  ]) {
    const decision = canadaSmallSupplierAssessmentDecision(assessment);
    assert.equal(decision.authorized, false);
    assert.equal(decision.reason, "threshold_exceeded");
  }
});

test("threshold constant and monetary values must be valid CAD cents", () => {
  assert.equal(canadaSmallSupplierAssessmentDecision(validAssessment({
    thresholdCadMinor: 2500000,
  })).reason, "assessment_invalid");
  assert.equal(canadaSmallSupplierAssessmentDecision(validAssessment({
    rollingFourQuarterCadMinor: 1.5,
  })).reason, "assessment_invalid");
});

test("assessment must have an audit revision", () => {
  const decision = canadaSmallSupplierAssessmentDecision(validAssessment({
    revision: 0,
  }));
  assert.equal(decision.authorized, false);
  assert.equal(decision.reason, "assessment_unversioned");
});

test("runtime readiness must be active and bound to the current assessment revision", () => {
  assert.equal(canadaSmallSupplierReadinessDecision(
      validReadiness(), validAssessment()).authorized, true);
  assert.equal(canadaSmallSupplierReadinessDecision(
      {canadaGstHstSmallSupplier: false}, validAssessment()).reason,
  "readiness_inactive");
  assert.equal(canadaSmallSupplierReadinessDecision(
      {canadaGstHstSmallSupplier: true}, validAssessment()).reason,
  "readiness_unbound");
  const mismatch = canadaSmallSupplierReadinessDecision(
      validReadiness({canadaGstHstSmallSupplierAssessmentRevision: 1}),
      validAssessment(),
  );
  assert.equal(mismatch.authorized, false);
  assert.equal(mismatch.reason, "assessment_revision_mismatch");
});

test("runtime readiness fails closed when bound assessment becomes invalid", () => {
  const decision = canadaSmallSupplierReadinessDecision(
      validReadiness(),
      validAssessment({requiresRegistrationReview: true, exceeded: true}),
  );
  assert.equal(decision.authorized, false);
  assert.equal(decision.reason, "threshold_exceeded");
});
