"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  TAX_REGISTRATION_REVIEW_DAYS,
  effectiveVerificationStatus,
  isRegistrationVerificationCurrent,
} = require("../marketplace_tax_registration_admin");

function timestamp(ms) {
  return {toMillis: () => ms};
}

test("tax registrations use a 180-day Pipe Buyer re-verification cadence", () => {
  assert.equal(TAX_REGISTRATION_REVIEW_DAYS, 180);
});

test("verified registration becomes review-required after its review date", () => {
  const now = Date.now();
  const current = {
    pstBcNumber: "PST-1234-5678",
    pstBcStatus: "verified",
    pstBcNumberReviewDueAt: timestamp(now + 60_000),
  };
  const expired = {
    ...current,
    pstBcNumberReviewDueAt: timestamp(now - 1),
  };
  assert.equal(isRegistrationVerificationCurrent(current, "pstBcNumber", now), true);
  assert.equal(isRegistrationVerificationCurrent(expired, "pstBcNumber", now), false);
  assert.equal(effectiveVerificationStatus(expired, "pstBcNumber", now), "review_required");
});

test("missing registration values cannot remain verified", () => {
  const now = Date.now();
  const profile = {
    gstHstNumber: "",
    gstHstStatus: "verified",
    gstHstNumberReviewDueAt: timestamp(now + 60_000),
  };
  assert.equal(isRegistrationVerificationCurrent(profile, "gstHstNumber", now), false);
  assert.equal(effectiveVerificationStatus(profile, "gstHstNumber", now), "review_required");
});
