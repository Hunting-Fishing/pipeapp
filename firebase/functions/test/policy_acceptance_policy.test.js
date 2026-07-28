"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  REQUIRED_POLICY_IDS,
  acceptanceFingerprint,
  assertCurrentPolicies,
  validateAcceptanceItems,
  validatePolicyPublication,
} = require("../policy_acceptance_policy");

const hash = "a".repeat(64);

function acceptanceItems() {
  return REQUIRED_POLICY_IDS.map((policyId) => ({
    policyId,
    version: "2026.07",
    contentSha256: hash,
  }));
}

test("policy publication requires a controlled id, HTTPS URL, hash, and note", () => {
  const result = validatePolicyPublication({
    policyId: "privacy_notice",
    version: "2026.07",
    summary: "Explains how account and marketplace information is handled.",
    documentUrl: "https://example.test/policies/privacy",
    contentSha256: hash,
    effectiveAtMillis: Date.parse("2026-08-01T00:00:00Z"),
    approvalNote: "Approved for the staging acceptance exercise by the policy owner.",
  });
  assert.equal(result.title, "Privacy Notice");
  assert.equal(result.documentUrl, "https://example.test/policies/privacy");
  assert.throws(() => validatePolicyPublication({...result,
    effectiveAtMillis: 1,
    documentUrl: "http://example.test/privacy",
  }), /HTTPS/);
});

test("acceptance must contain every current policy exactly once", () => {
  const accepted = validateAcceptanceItems(acceptanceItems());
  assert.deepEqual(Object.keys(accepted), REQUIRED_POLICY_IDS);
  assert.throws(
      () => validateAcceptanceItems(acceptanceItems().slice(1)),
      /every current required policy/,
  );
  const duplicate = acceptanceItems();
  duplicate[1] = duplicate[0];
  assert.throws(() => validateAcceptanceItems(duplicate), /only once/);
});

test("server rejects stale versions and fingerprints the exact set", () => {
  const accepted = validateAcceptanceItems(acceptanceItems());
  const documents = Object.fromEntries(REQUIRED_POLICY_IDS.map((policyId) => [
    policyId,
    {status: "published", version: "2026.07", contentSha256: hash},
  ]));
  assert.deepEqual(assertCurrentPolicies(documents, accepted).privacy_notice, {
    version: "2026.07",
    contentSha256: hash,
  });
  assert.equal(acceptanceFingerprint(accepted).length, 64);
  documents.privacy_notice.version = "2026.08";
  assert.throws(() => assertCurrentPolicies(documents, accepted), /changed/);
});
