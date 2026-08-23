"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  requireCanadaSmallSupplierRuntimeEvidence,
} = require("../canada_small_supplier_runtime_gate");

function fakeDb(assessment) {
  return {
    collection(name) {
      assert.equal(name, "tax_threshold_assessments");
      return {
        doc(id) {
          assert.equal(id, "canada_gst_hst_current");
          return {
            async get() {
              return {
                exists: assessment != null,
                data: () => assessment,
              };
            },
          };
        },
      };
    },
  };
}

function readiness(overrides = {}) {
  return {
    canadaGstHstSmallSupplier: true,
    canadaGstHstSmallSupplierAssessmentRevision: 3,
    ...overrides,
  };
}

function assessment(overrides = {}) {
  return {
    revision: 3,
    worldwideAndAssociatedIncluded: true,
    thresholdCadMinor: 3000000,
    singleQuarterCadMinor: 500000,
    rollingFourQuarterCadMinor: 1200000,
    exceeded: false,
    requiresRegistrationReview: false,
    ...overrides,
  };
}

test("non-small-supplier tax mode does not require threshold evidence", async () => {
  const result = await requireCanadaSmallSupplierRuntimeEvidence(
      fakeDb(null),
      {canadaGstHstSmallSupplier: false},
  );
  assert.equal(result.applicable, false);
  assert.equal(result.authorized, true);
});

test("current bound audited assessment authorizes billing runtime", async () => {
  const result = await requireCanadaSmallSupplierRuntimeEvidence(
      fakeDb(assessment()),
      readiness(),
  );
  assert.equal(result.applicable, true);
  assert.equal(result.authorized, true);
  assert.equal(result.boundRevision, 3);
});

test("missing assessment fails closed at billing runtime", async () => {
  await assert.rejects(
      () => requireCanadaSmallSupplierRuntimeEvidence(
          fakeDb(null),
          readiness(),
      ),
      /missing, stale, or no longer eligible/i,
  );
});

test("stale readiness binding fails closed at billing runtime", async () => {
  await assert.rejects(
      () => requireCanadaSmallSupplierRuntimeEvidence(
          fakeDb(assessment({revision: 4})),
          readiness({canadaGstHstSmallSupplierAssessmentRevision: 3}),
      ),
      /missing, stale, or no longer eligible/i,
  );
});

test("exceeded threshold fails closed at billing runtime", async () => {
  await assert.rejects(
      () => requireCanadaSmallSupplierRuntimeEvidence(
          fakeDb(assessment({
            rollingFourQuarterCadMinor: 3000001,
            exceeded: true,
            requiresRegistrationReview: true,
          })),
          readiness(),
      ),
      /missing, stale, or no longer eligible/i,
  );
});
