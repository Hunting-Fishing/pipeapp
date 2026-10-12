"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");
const {
  REPUTATION_MIN_COMPLETED_SALES,
  SERVER_OWNED_PUBLIC_TRUST_KEYS,
  buildProfileUpdate,
  buildPublicTrustProjection,
  computeUserScoreV1,
  createPublicTrustProjection,
  sumScoreAdjustments,
  vipMembershipCurrent,
} = require("../public_trust_projection");

const FieldValue = {delete: () => "__DELETE__", serverTimestamp: () => "__TS__"};
const NOW = Date.UTC(2026, 9, 6);
const FUTURE = NOW + 86_400_000;
const project = (overrides) => buildPublicTrustProjection({
  uid: "u1", completedTransactionCount: 0, nowMillis: NOW, ...overrides,
});

test("only a current VIP membership owned by the user publishes the vip tier", () => {
  const active = {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE};
  assert.equal(vipMembershipCurrent(active, "u1", NOW), true);
  assert.equal(vipMembershipCurrent({...active, ownerUid: "u2"}, "u1", NOW), false);
  assert.equal(vipMembershipCurrent({...active, active: false}, "u1", NOW), false);
  assert.equal(vipMembershipCurrent({...active, currentPeriodEnd: NOW - 1}, "u1", NOW), false);
  assert.equal(vipMembershipCurrent(null, "u1", NOW), false);
});

test("User Score v1 follows the policy inputs and caps", () => {
  const score = (o) => computeUserScoreV1({accountVerified: false, completedTransactionCount: 0, adjustmentTotal: 0, ...o});
  assert.equal(score({}), 70);
  assert.equal(score({accountVerified: true}), 80);
  assert.equal(score({completedTransactionCount: 1}), 72);
  assert.equal(score({completedTransactionCount: 3}), 76);
  assert.equal(score({completedTransactionCount: 5}), 80);
  assert.equal(score({completedTransactionCount: 500}), 80, "sales bonus is capped at +10");
  assert.equal(score({accountVerified: true, completedTransactionCount: 5}), 90);
  assert.equal(score({accountVerified: true, completedTransactionCount: 99, adjustmentTotal: 40}), 100);
  assert.equal(score({adjustmentTotal: -25}), 45);
  assert.equal(score({adjustmentTotal: -500}), 0, "clamped at 0");
  assert.equal(score({adjustmentTotal: 500}), 100, "clamped at 100");
  assert.equal(score({adjustmentTotal: Number.NaN}), 70);
  assert.equal(score({completedTransactionCount: 2.5}), 70, "non-integer counts are ignored");
});

test("score adjustments sum only numeric administrator changes", () => {
  assert.equal(sumScoreAdjustments([{change: -8}, {change: 2}, {change: "x"}, {}, null, {change: 3}]), -3);
  assert.equal(sumScoreAdjustments([]), 0);
  assert.equal(sumScoreAdjustments(undefined), 0);
});

test("three completed sales leave NEW; below that no score is published", () => {
  assert.equal(REPUTATION_MIN_COMPLETED_SALES, 3);
  for (const count of [0, 1, 2]) {
    const projection = project({completedTransactionCount: count});
    assert.equal(projection.reputationStatus, "new");
    assert.equal(projection.scoreVersion, 0);
    assert.equal("reputationScore" in projection, false);
  }
  const three = project({completedTransactionCount: 3});
  assert.equal(three.reputationStatus, "emerging");
  assert.equal(three.scoreVersion, 1);
  assert.equal(three.reputationScore, 76);
  assert.equal(project({completedTransactionCount: 3, accountVerified: true}).reputationScore, 86);
  assert.equal(project({completedTransactionCount: 3, adjustmentTotal: -10}).reputationScore, 66);
});

test("membership never changes the score, and Dispatch/VIP are not inputs", () => {
  const vip = {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE};
  const plain = project({completedTransactionCount: 4, accountVerified: true});
  const paid = project({completedTransactionCount: 4, accountVerified: true, vipMembership: vip});
  assert.equal(paid.membershipTier, "vip");
  assert.equal(plain.membershipTier, "standard");
  assert.equal(paid.reputationScore, plain.reputationScore);
  assert.equal(paid.reputationStatus, plain.reputationStatus);
});

test("accounts scheduled for deletion are experienced but never scored", () => {
  const leaving = project({completedTransactionCount: 9, accountStatus: "deletion_scheduled"});
  assert.equal(leaving.reputationStatus, "emerging");
  assert.equal(leaving.scoreVersion, 0);
  assert.equal("reputationScore" in leaving, false);
  assert.equal("reputationScore" in project({completedTransactionCount: 9, accountStatus: "active"}), true);
  assert.equal("reputationScore" in project({completedTransactionCount: 9}), true);
});

test("profile update is null when current, deletes forged and no-longer-eligible trust fields", () => {
  const projection = project({completedTransactionCount: 0});
  assert.equal(buildProfileUpdate({...projection, displayName: "A"}, projection, FieldValue), null);
  const forged = buildProfileUpdate(
      {displayName: "A", reputationScore: 100, reviewAverage: 5, membershipTier: "vip"},
      projection,
      FieldValue,
  );
  assert.equal(forged.reputationScore, "__DELETE__");
  assert.equal(forged.reviewAverage, "__DELETE__");
  assert.equal(forged.membershipTier, "standard");
  assert.equal(forged.lastCalculatedAt, "__TS__");
  assert.equal("displayName" in forged, false);
  const scored = project({completedTransactionCount: 3});
  assert.equal(buildProfileUpdate({...scored}, scored, FieldValue), null);
});

function fakeAdmin({docs = {}, completed = 0, events = []}) {
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
      limit() {
        return this;
      },
      get: async () => ({docs: name === "user_score_events" ? events.map((e) => ({data: () => e})) : []}),
      count: () => ({get: async () => ({data: () => ({count: completed})})}),
    }),
  };
  return {admin: {firestore: Object.assign(() => db, {FieldValue})}, writes};
}

test("syncUser publishes a policy-based score from verification, sales and admin adjustments", async () => {
  const {admin, writes} = fakeAdmin({
    completed: 4,
    events: [{change: -5}, {change: 2}],
    docs: {
      "public_business_profiles/u1": {reputationScore: 100},
      "users/u1": {accountVerified: true, accountStatus: "active"},
      "vip_memberships/u1": {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE},
    },
  });
  const result = await createPublicTrustProjection(admin).syncUser("u1", {nowMillis: NOW});
  assert.deepEqual(result.updated, ["public_business_profiles/u1"]);
  assert.equal(writes.length, 1);
  const update = writes[0][1];
  assert.equal(update.membershipTier, "vip");
  assert.equal(update.completedTransactionCount, 4);
  assert.equal(update.reputationStatus, "emerging");
  assert.equal(update.scoreVersion, 1);
  assert.equal(update.reputationScore, 85, "70 + 10 verified + 8 sales - 3 adjustments");
});

test("syncUser removes a forged score from a member below the threshold", async () => {
  const {admin, writes} = fakeAdmin({
    completed: 1,
    docs: {"public_seller_profiles/u1": {reputationScore: 100, reputationStatus: "established"}, "users/u1": {}},
  });
  await createPublicTrustProjection(admin).syncUser("u1", {nowMillis: NOW});
  assert.equal(writes[0][1].reputationScore, "__DELETE__");
  assert.equal(writes[0][1].reputationStatus, "new");
});

test("syncUser creates nothing without a public profile and supports dry runs", async () => {
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
