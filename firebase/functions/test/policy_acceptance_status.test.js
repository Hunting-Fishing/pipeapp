"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  policyAcceptanceMatches,
} = require("../policy_acceptance_status");
const {REQUIRED_POLICY_IDS} = require("../policy_acceptance_policy");

function publishedPolicies() {
  return Object.fromEntries(REQUIRED_POLICY_IDS.map((id, index) => [
    id,
    {
      status: "published",
      version: `2026.08.${index + 1}`,
      contentSha256: String(index + 1).padStart(64, "a").slice(0, 64),
    },
  ]));
}

function matchingAcceptance(policies) {
  return {
    acceptedVersions: Object.fromEntries(
        REQUIRED_POLICY_IDS.map((id) => [id, policies[id].version]),
    ),
    acceptedHashes: Object.fromEntries(
        REQUIRED_POLICY_IDS.map((id) => [id, policies[id].contentSha256]),
    ),
  };
}

test("current policy acceptance requires every exact published version and hash", () => {
  const policies = publishedPolicies();
  const acceptance = matchingAcceptance(policies);
  assert.equal(policyAcceptanceMatches({acceptance, policies}), true);

  const staleVersion = matchingAcceptance(policies);
  staleVersion.acceptedVersions.terms_of_service = "2026.07.old";
  assert.equal(policyAcceptanceMatches({acceptance: staleVersion, policies}), false);

  const staleHash = matchingAcceptance(policies);
  staleHash.acceptedHashes.privacy_notice = "0".repeat(64);
  assert.equal(policyAcceptanceMatches({acceptance: staleHash, policies}), false);
});

test("missing acceptance or unpublished policy fails closed", () => {
  const policies = publishedPolicies();
  assert.equal(policyAcceptanceMatches({acceptance: null, policies}), false);

  const acceptance = matchingAcceptance(policies);
  const missing = {...policies};
  delete missing.communications;
  assert.equal(policyAcceptanceMatches({acceptance, policies: missing}), false);

  const draft = {...policies, mapping_location: {...policies.mapping_location, status: "draft"}};
  assert.equal(policyAcceptanceMatches({acceptance, policies: draft}), false);
});
