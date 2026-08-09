"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeReferralCode,
  referralCodeForUid,
} = require("../affiliate_commands");

test("generates a stable Pipe Buyer referral code per user", () => {
  const first = referralCodeForUid("user-123");
  const second = referralCodeForUid("user-123");
  assert.equal(first, second);
  assert.match(first, /^PB[A-Z0-9]{10}$/);
});

test("different users receive different referral codes", () => {
  assert.notEqual(referralCodeForUid("user-a"), referralCodeForUid("user-b"));
});

test("normalizes customer-entered referral codes", () => {
  const code = referralCodeForUid("affiliate-owner");
  assert.equal(normalizeReferralCode(code.toLowerCase()), code);
});
