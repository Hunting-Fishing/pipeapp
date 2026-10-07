"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const firebaseRoot = path.resolve(__dirname, "..", "..");
const rules = fs.readFileSync(path.join(firebaseRoot, "firestore.rules"), "utf8");

const usersBlock = rules.match(/match \/users\/\{uid\} \{([\s\S]*?)\n      match \/saved_listings/);

test("users rules block exists", () => {
  assert.ok(usersBlock, "users/{uid} rules block is missing");
});

test("owners cannot self-write server-owned membership/VIP fields", () => {
  const owner = usersBlock[1].match(/allow update: if owns\(uid\) &&([\s\S]*?)\]\);/);
  assert.ok(owner, "owner update rule is missing");
  for (const field of [
    "isVip", "vipActive", "vipStatus", "vipExpiresAt", "vipUntil",
    "vipSubscriptionId", "vipUpdatedAt", "membership", "membershipTier",
    "subscriptionTier", "subscriptionStatus",
    // existing protections must not regress
    "userScore", "accountVerified", "accountStatus", "phoneE164",
  ]) {
    assert.ok(owner[1].includes(`'${field}'`), `${field} must be in the owner update deny-list`);
  }
});

test("clients cannot create notification documents in any inbox", () => {
  const block = rules.match(/match \/notifications\/\{notificationId\} \{([\s\S]*?)\n      \}/);
  assert.ok(block, "notifications rules block is missing");
  assert.match(block[1], /allow create: if false;/);
  assert.equal(block[1].includes("recipientUid"), false);
});

for (const [collection, variable] of [
  ["public_business_profiles", "businessId"],
  ["public_seller_profiles", "sellerId"],
]) {
  test(`${collection} owners cannot write server-owned trust fields`, () => {
    const block = rules.match(new RegExp(
        `match /${collection}/\\{${variable}\\} \\{([\\s\\S]*?)\\n    \\}`,
    ));
    assert.ok(block, `${collection} rules block is missing`);
    assert.match(block[1], new RegExp(`allow create: if ownerMayCreatePublicProfile\\(${variable}\\)`));
    assert.match(block[1], new RegExp(`allow update: if ownerMayUpdatePublicProfile\\(${variable}\\)`));
    assert.equal(/allow create, update, delete: if owns/.test(block[1]), false);
  });
}

test("public profile trust deny-list covers reputation, tier, and verification fields", () => {
  const list = rules.match(/function serverOwnedPublicTrustKeys\(\) \{([\s\S]*?)\n    \}/);
  assert.ok(list, "serverOwnedPublicTrustKeys is missing");
  for (const field of [
    "reputationScore", "reviewAverage", "reviewCount", "completedTransactionCount",
    "membershipTier", "vipActive", "isVip", "verified", "accountVerified", "userScore",
  ]) {
    assert.ok(list[1].includes(`'${field}'`), `${field} must be server-owned`);
  }
});

test("location requests are bounded, target the real listing owner, and cap the note", () => {
  const block = rules.match(/match \/location_requests\/\{requestId\} \{([\s\S]*?)\n    \}/);
  assert.ok(block, "location_requests rules block is missing");
  const create = block[1].match(/allow create:([\s\S]*?);\s*allow read/);
  assert.ok(create, "location_requests create rule is missing");
  assert.match(create[1], /keys\(\)\.hasOnly\(\[/);
  assert.match(create[1], /sellerUid != request\.auth\.uid/);
  assert.match(create[1], /status == 'pending'/);
  assert.match(create[1], /note\.size\(\) <= 500/);
  assert.match(create[1], /public_listings\/\$\(request\.resource\.data\.listingId\)/);
});
