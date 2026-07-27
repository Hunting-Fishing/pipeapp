"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  AccountVerificationPolicyError,
  approvedAccountVerification,
  requireVerificationReadiness,
  validateVerificationDecision,
  verificationReadiness,
} = require("../account_verification_policy");

const readyInput = {
  identity: {emailVerified: true, phoneVerified: true},
  user: {accountType: "business", profileCompletion: 100},
  sellerProfile: {
    photoUrl: "https://storage.test/avatar.jpg",
    approvedTagIds: ["pipe", "hauling"],
  },
  businessProfile: {
    publicName: "Northern Pipe Services",
    description: "Industrial pipe and hauling services.",
    publicEmail: "dispatch@pipe.test",
    publicPhone: "+12505550123",
    serviceAreaLabel: "Northern Alberta",
  },
};

test("verification readiness requires owned contact methods and profile evidence", () => {
  const readiness = verificationReadiness(readyInput);
  assert.equal(readiness.ready, true);
  assert.equal(readiness.accountType, "business");
  assert.equal(readiness.checks.length, 9);

  assert.throws(
      () => requireVerificationReadiness({
        ...readyInput,
        identity: {emailVerified: true, phoneVerified: false},
      }),
      (error) => error instanceof AccountVerificationPolicyError &&
        error.code === "failed-precondition" &&
        error.message.includes("mobile ownership"),
  );
});

test("personal accounts do not inherit business-only requirements", () => {
  const readiness = verificationReadiness({
    ...readyInput,
    user: {accountType: "personal", profileCompletion: 100},
    sellerProfile: {
      ...readyInput.sellerProfile,
      displayName: "Alex Driver",
    },
    businessProfile: {},
  });
  assert.equal(readiness.ready, true);
  assert.equal(readiness.checks.length, 6);
});

test("administrator decisions require an approved state and durable note", () => {
  assert.deepEqual(validateVerificationDecision({
    decision: "approved",
    reason: "Ownership and public profile evidence reviewed.",
  }), {
    decision: "approved",
    reason: "Ownership and public profile evidence reviewed.",
  });
  assert.throws(
      () => validateVerificationDecision({decision: "maybe", reason: "no"}),
      /Choose approve/,
  );
  assert.throws(
      () => validateVerificationDecision({decision: "rejected", reason: "no"}),
      /clear review note/,
  );
});

test("legacy profile flags do not impersonate an approved identity review", () => {
  assert.equal(approvedAccountVerification({accountVerified: true}), false);
  assert.equal(approvedAccountVerification({
    accountVerified: true,
    accountVerificationReviewVersion: 1,
  }), true);
});
