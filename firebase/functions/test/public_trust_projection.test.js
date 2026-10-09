"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");
const {
  SERVER_OWNED_PUBLIC_TRUST_KEYS,
  buildProfileUpdate,
  buildPublicTrustProjection,
  createPublicTrustProjection,
  vipMembershipCurrent,
} = require("../public_trust_projection");

const FieldValue = {delete: () => "__DELETE__", serverTimestamp: () => "__TS__"};
const NOW = Date.UTC(2026, 9, 6);
const FUTURE = NOW + 86_400_000;

test("only a current VIP membership owned by the user publishes the vip tier", () => {
  const active = {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE};
  assert.equal(vipMembershipCurrent(active, "u1", NOW), true);
  assert.equal(vipMembershipCurrent({...active, ownerUid: "u2"}, "u1", NOW), false);
  assert.equal(vipMembershipCurrent({...active, active: false}, "u1", NOW), false);
  assert.equal(vipMembershipCurrent({...active, currentPeriodEnd: NOW - 1}, "u1", NOW), false);
  assert.equal(vipMembershipCurrent(null, "u1", NOW), false);
});

test("projection never publishes a numeric score or unlaunched tiers", () => {
  const vip = buildPublicTrustProjection({
    uid: "u1",
    vipMembership: {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE},
    completedTransactionCount: 7,
    nowMillis: NOW,
  });
  assert.equal(vip.membershipTier, "vip");
  assert.equal(vip.completedTransactionCount, 7);
  assert.equal(vip.reputationStatus, "new");
  assert.equal("reputationScore" in vip, false);
  const standard = buildPublicTrustProjection({uid: "u1", completedTransactionCount: -4, nowMillis: NOW});
  assert.equal(standard.membershipTier, "standard");
  assert.equal(standard.completedTransactionCount, 0);
});

test("profile update is null when current and deletes client-forged trust fields", () => {
  const projection = buildPublicTrustProjection({uid: "u1", completedTransactionCount: 0, nowMillis: NOW});
  assert.equal(buildProfileUpdate({...projection, displayName: "A"}, projection, FieldValue), null);
  const update = buildProfileUpdate(
      {displayName: "A", reputationScore: 100, reviewAverage: 5, membershipTier: "vip"},
      projection,
      FieldValue,
  );
  assert.equal(update.reputationScore, "__DELETE__");
  assert.equal(update.reviewAverage, "__DELETE__");
  assert.equal(update.membershipTier, "standard");
  assert.equal(update.lastCalculatedAt, "__TS__");
  assert.equal("displayName" in update, false);
});

function fakeAdmin({docs = {}, completed = 0}) {
  const writes = [];
  const db = {
    collection: (name) => ({
      doc: (id) => ({
        get: async () => {
          const data = docs[`${name}/${id}`];
          return {
            exists: data !== undefined,
            data: () => data,
            ref: {path: `${name}/${id}`, update: async (u) => writes.push([`${name}/${id}`, u])},
          };
        },
      }),
      where() {
        return this;
      },
      count: () => ({get: async () => ({data: () => ({count: completed})})}),
    }),
  };
  const admin = {firestore: Object.assign(() => db, {FieldValue})};
  return {admin, writes};
}

test("syncUser updates existing public profiles only and reads VIP from the server record", async () => {
  const {admin, writes} = fakeAdmin({
    completed: 3,
    docs: {
      "public_business_profiles/u1": {reputationScore: 100},
      "vip_memberships/u1": {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE},
    },
  });
  const result = await createPublicTrustProjection(admin).syncUser("u1", {nowMillis: NOW});
  assert.deepEqual(result.updated, ["public_business_profiles/u1"]);
  assert.equal(writes.length, 1);
  assert.equal(writes[0][1].membershipTier, "vip");
  assert.equal(writes[0][1].completedTransactionCount, 3);
  assert.equal(writes[0][1].reputationScore, "__DELETE__");
});

test("syncUser creates nothing when the user has no public profile and supports dry runs", async () => {
  const none = fakeAdmin({});
  assert.deepEqual((await createPublicTrustProjection(none.admin).syncUser("u9")).updated, []);
  assert.equal(none.writes.length, 0);
  const dry = fakeAdmin({docs: {"public_seller_profiles/u1": {}}});
  const result = await createPublicTrustProjection(dry.admin).syncUser("u1", {dryRun: true});
  assert.deepEqual(result.updated, ["public_seller_profiles/u1"]);
  assert.equal(dry.writes.length, 0);
});

test("module key list stays identical to the Firestore rules deny-list", () => {
  const rules = fs.readFileSync(path.resolve(__dirname, "..", "..", "firestore.rules"), "utf8");
  const match = rules.match(/function serverOwnedPublicTrustKeys\(\) \{([\s\S]*?)\n    \}/);
  assert.ok(match, "serverOwnedPublicTrustKeys is missing from the rules");
  const ruleKeys = [...match[1].matchAll(/'([A-Za-z]+)'/g)].map((m) => m[1]).sort();
  assert.deepEqual(ruleKeys, [...SERVER_OWNED_PUBLIC_TRUST_KEYS].sort());
});
