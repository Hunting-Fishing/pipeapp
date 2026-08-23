"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  FOUNDING500_CODE,
  FOUNDING500_MAX_CLAIMS,
  FOUNDING500_TRIAL_MONTHS,
  founding500PriorSubscriptionExists,
  founding500TrialEndUnix,
  isFounding500Code,
  normalizeDispatchLaunchCode,
} = require("../dispatch_founding500_policy");

test("Founding 500 constants preserve the approved launch offer", () => {
  assert.equal(FOUNDING500_CODE, "FOUNDING500");
  assert.equal(FOUNDING500_MAX_CLAIMS, 500);
  assert.equal(FOUNDING500_TRIAL_MONTHS, 6);
});

test("Founding 500 launch code normalization is case-insensitive", () => {
  assert.equal(normalizeDispatchLaunchCode(" founding500 "), "FOUNDING500");
  assert.equal(isFounding500Code("Founding500"), true);
  assert.equal(isFounding500Code("other"), false);
});

test("Founding 500 trial end is exactly six UTC calendar months", () => {
  const start = Date.UTC(2026, 7, 23, 15, 30, 0);
  const end = founding500TrialEndUnix(start) * 1000;
  assert.equal(new Date(end).toISOString(), "2027-02-23T15:30:00.000Z");
});

test("Founding 500 calendar math clamps end-of-month safely", () => {
  const start = Date.UTC(2026, 7, 31, 12, 0, 0);
  const end = founding500TrialEndUnix(start) * 1000;
  assert.equal(new Date(end).toISOString(), "2027-02-28T12:00:00.000Z");
});

test("prior or retired Dispatch subscription blocks a second Founding grant", () => {
  assert.equal(founding500PriorSubscriptionExists({}), false);
  assert.equal(founding500PriorSubscriptionExists({
    stripeSubscriptionId: "sub_existing",
  }), true);
  assert.equal(founding500PriorSubscriptionExists({
    retiredStripeSubscriptionIds: ["sub_retired"],
  }), true);
  assert.equal(founding500PriorSubscriptionExists({status: "canceled"}), true);
});
