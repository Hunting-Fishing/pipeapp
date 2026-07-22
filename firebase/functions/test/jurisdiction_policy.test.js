"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const {
  canUseFeature,
  resolveExactPolicy,
} = require("../jurisdiction_policy");

const fixturePath = path.join(
    __dirname,
    "..",
    "..",
    "config",
    "jurisdictions",
    "north_america.design.json",
);
const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
const now = new Date("2026-07-19T00:00:00.000Z");

test("design fixture covers Canada, the U.S., and Mexico", () => {
  assert.equal(fixture.publishingEnabled, false);
  assert.deepEqual(
      fixture.policies.map((policy) => policy.jurisdiction.countryCode).sort(),
      ["CA", "MX", "US"],
  );
});

test("design fixture cannot authorize public property publishing", () => {
  for (const policy of fixture.policies) {
    const decision = canUseFeature(
        policy,
        "publicPropertyListings",
        now,
    );
    assert.equal(decision.allowed, false);
    assert.ok(decision.reasons.length > 0);
  }
});

test("exact resolver never falls back from a subdivision to country", () => {
  const policy = resolveExactPolicy(fixture.policies, {
    countryCode: "CA",
    subdivisionCode: "AB",
  });
  assert.equal(policy, null);
});

test("complete active subdivision policy can authorize publishing", () => {
  const jurisdiction = {
    countryCode: "CA",
    subdivisionCode: "AB",
  };
  const policy = {
    schemaVersion: 1,
    id: "ca-ab-test-v1",
    jurisdiction,
    status: "active",
    responsibleEntity: {
      id: "exp-realty-canada",
      legalName: "eXp Realty of Canada, Inc.",
      countryCode: "CA",
      active: true,
    },
    brokerageLicense: {
      id: "ca-ab-test-license",
      entityId: "exp-realty-canada",
      jurisdiction,
      licenseNumber: "TEST-ONLY",
      validFrom: "2026-01-01T00:00:00.000Z",
      validUntil: "2027-01-01T00:00:00.000Z",
      active: true,
    },
    complianceOwnerId: "test-supervising-broker",
    requiredFormSetVersion: "test-forms-v1",
    legalReviewVersion: "test-legal-v1",
    trustFundsApprovalVersion: null,
    effectiveAt: "2026-01-01T00:00:00.000Z",
    expiresAt: "2027-01-01T00:00:00.000Z",
    features: {
      enabledFeatures: ["publicPropertyListings"],
    },
  };

  const decision = canUseFeature(
      policy,
      "publicPropertyListings",
      now,
  );
  assert.deepEqual(decision, {allowed: true, reasons: []});
});

