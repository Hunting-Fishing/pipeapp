"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");
const {
  REPORT_REASON_PENALTIES,
  REPUTATION_MIN_COMPLETED_SALES,
  SERVER_OWNED_PUBLIC_TRUST_KEYS,
  USER_SCORE_VERSION,
  buildProfileUpdate,
  buildPublicTrustProjection,
  computeUserScore,
  createPublicTrustProjection,
  fulfillmentBonus,
  moderationPenaltyTotal,
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

test("fulfillment bonus is earned from completed vs seller-cancelled sales", () => {
  const bonus = (completed, cancelled) => fulfillmentBonus({completedTransactionCount: completed, sellerCancelledCount: cancelled});
  assert.equal(bonus(0, 0), 0);
  assert.equal(bonus(2, 0), 0, "needs the minimum number of completed sales first");
  assert.equal(bonus(3, 0), 5);
  assert.equal(bonus(9, 0), 5, "capped at +5");
  assert.equal(bonus(3, 1), 4);
  assert.equal(bonus(3, 3), 3);
  assert.equal(bonus(3, 30), 0);
});

test("moderation penalties count only administrator-confirmed outcomes", () => {
  const confirmed = (reason, extra = {}) => ({status: "violation_confirmed", reason, targetType: "listing", ...extra});
  assert.equal(moderationPenaltyTotal([]), 0);
  assert.equal(moderationPenaltyTotal(undefined), 0);
  for (const status of ["pending", "information_requested", "dismissed", "appealed", "overturned"]) {
    assert.equal(moderationPenaltyTotal([{status, reason: "fraud_or_scam", listingId: "L1"}]), 0, status);
  }
  assert.equal(moderationPenaltyTotal([confirmed("fraud_or_scam", {listingId: "L1"})]), REPORT_REASON_PENALTIES.fraud_or_scam);
  assert.equal(moderationPenaltyTotal([{status: "appeal_upheld", reason: "spam", listingId: "L2"}]), REPORT_REASON_PENALTIES.spam);
  assert.equal(moderationPenaltyTotal([confirmed("not_a_known_reason", {listingId: "L3"})]), REPORT_REASON_PENALTIES.other);
});

test("one incident produces one adjustment even when reported several times", () => {
  const same = [
    {status: "violation_confirmed", reason: "spam", targetType: "listing", listingId: "L1"},
    {status: "violation_confirmed", reason: "misleading_information", targetType: "listing", listingId: "L1"},
  ];
  assert.equal(moderationPenaltyTotal(same), REPORT_REASON_PENALTIES.misleading_information, "worst reason wins, not the sum");
  const different = [
    {status: "violation_confirmed", reason: "spam", targetType: "listing", listingId: "L1"},
    {status: "violation_confirmed", reason: "spam", targetType: "listing", listingId: "L2"},
  ];
  assert.equal(moderationPenaltyTotal(different), 2 * REPORT_REASON_PENALTIES.spam);
});

test("moderation penalties cannot push the penalty below the policy floor", () => {
  const many = Array.from({length: 10}, (_, i) => ({status: "violation_confirmed", reason: "fraud_or_scam", targetType: "listing", listingId: `L${i}`}));
  assert.equal(moderationPenaltyTotal(many), -100);
});

test("User Score v2 follows the policy inputs and caps", () => {
  const score = (o) => computeUserScore({accountVerified: false, completedTransactionCount: 0, ...o});
  assert.equal(USER_SCORE_VERSION, 2);
  assert.equal(score({}), 70);
  assert.equal(score({accountVerified: true}), 80);
  assert.equal(score({completedTransactionCount: 1}), 72);
  assert.equal(score({completedTransactionCount: 3}), 81, "70 + 6 sales + 5 fulfillment");
  assert.equal(score({completedTransactionCount: 3, sellerCancelledCount: 1}), 80);
  assert.equal(score({completedTransactionCount: 500}), 85, "sales +10, fulfillment +5");
  assert.equal(score({accountVerified: true, completedTransactionCount: 99}), 95);
  assert.equal(score({adjustmentTotal: -25}), 45);
  assert.equal(score({moderationPenalty: -40}), 30);
  assert.equal(score({adjustmentTotal: -30, moderationPenalty: -90}), 0, "clamped at 0");
  assert.equal(score({adjustmentTotal: 500}), 100, "clamped at 100");
  assert.equal(score({adjustmentTotal: Number.NaN, moderationPenalty: Number.NaN}), 70);
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
  assert.equal(three.scoreVersion, 2);
  assert.equal(three.reputationScore, 81);
  assert.equal(project({completedTransactionCount: 3, accountVerified: true}).reputationScore, 91);
  assert.equal(project({completedTransactionCount: 3, moderationPenalty: -15}).reputationScore, 66);
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

test("accounts scheduled for deletion are experienced but never publicly scored", () => {
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

function fakeAdmin({docs = {}, completed = 0, cancelled = 0, events = [], reports = [], userIds = []}) {
  const writes = [];
  const snapshotFor = (name, id) => {
    const data = docs[`${name}/${id}`];
    return {
      id,
      exists: data !== undefined,
      data: () => data,
      ref: {path: `${name}/${id}`, update: async (u) => writes.push([`${name}/${id}`, u])},
    };
  };
  const db = {
    collection: (name) => {
      const constraints = [];
      let cursor = "";
      let max = 1000;
      const query = {
        doc: (id) => ({get: async () => snapshotFor(name, id)}),
        where(field, op, value) {
          constraints.push([field, op, value]);
          return query;
        },
        orderBy() {
          return query;
        },
        limit(n) {
          max = n;
          return query;
        },
        startAfter(c) {
          cursor = c;
          return query;
        },
        count: () => ({
          get: async () => ({
            data: () => ({
              count: constraints.some(([f, , v]) => f === "status" && v === "cancelled") ? cancelled : completed,
            }),
          }),
        }),
        get: async () => {
          if (name === "user_score_events") return {docs: events.map((e) => ({data: () => e}))};
          if (name === "trust_reports") return {docs: reports.map((r, i) => ({id: `r${i}`, data: () => r}))};
          if (name === "users" && userIds.length) {
            const ids = userIds.filter((id) => id > cursor).slice(0, max);
            return {docs: ids.map((id) => snapshotFor("users", id))};
          }
          return {docs: []};
        },
      };
      return query;
    },
  };
  return {admin: {firestore: Object.assign(() => db, {FieldValue})}, writes};
}

const FULL_MEMBER = {
  completed: 4,
  cancelled: 1,
  events: [{change: -2}],
  reports: [
    {status: "violation_confirmed", reason: "misleading_information", targetType: "listing", listingId: "L1"},
    {status: "violation_confirmed", reason: "spam", targetType: "listing", listingId: "L1"},
    {status: "pending", reason: "fraud_or_scam", targetType: "user"},
  ],
};

test("syncUser derives the whole score from server data and writes private and public copies", async () => {
  const {admin, writes} = fakeAdmin({
    ...FULL_MEMBER,
    docs: {
      "users/u1": {accountVerified: true, accountStatus: "active", userScore: 70},
      "public_business_profiles/u1": {reputationScore: 100},
      "vip_memberships/u1": {ownerUid: "u1", active: true, currentPeriodEnd: FUTURE},
    },
  });
  const result = await createPublicTrustProjection(admin).syncUser("u1", {nowMillis: NOW});
  // 70 + 10 verified + 8 sales + 4 fulfillment (4 of 5) - 2 admin - 15 confirmed misleading listing
  assert.equal(result.userScore, 75);
  assert.deepEqual(result.updated.sort(), ["public_business_profiles/u1", "users/u1"]);
  const byPath = Object.fromEntries(writes);
  assert.equal(byPath["users/u1"].userScore, 75);
  assert.equal(byPath["users/u1"].userScoreVersion, 2);
  assert.equal(byPath["public_business_profiles/u1"].reputationScore, 75);
  assert.equal(byPath["public_business_profiles/u1"].reputationStatus, "emerging");
  assert.equal(byPath["public_business_profiles/u1"].membershipTier, "vip");
  assert.equal(byPath["public_business_profiles/u1"].scoreVersion, 2);
});

test("syncUser does not rewrite a private score that is already correct", async () => {
  const {admin, writes} = fakeAdmin({
    ...FULL_MEMBER,
    docs: {"users/u1": {accountVerified: true, userScore: 75}, "public_seller_profiles/u1": {}},
  });
  await createPublicTrustProjection(admin).syncUser("u1", {nowMillis: NOW});
  assert.equal(writes.some(([p]) => p === "users/u1"), false);
  assert.equal(writes.some(([p]) => p === "public_seller_profiles/u1"), true);
});

test("a member without a public profile still gets an automatic private score", async () => {
  const {admin, writes} = fakeAdmin({completed: 0, docs: {"users/u1": {accountVerified: true, userScore: 70}}});
  const result = await createPublicTrustProjection(admin).syncUser("u1", {nowMillis: NOW});
  assert.equal(result.userScore, 80);
  assert.deepEqual(writes.map(([p]) => p), ["users/u1"]);
});

test("syncUser removes a forged public score below the threshold, creates nothing, and supports dry runs", async () => {
  const forged = fakeAdmin({
    completed: 1,
    docs: {"public_seller_profiles/u1": {reputationScore: 100, reputationStatus: "established"}, "users/u1": {userScore: 72}},
  });
  await createPublicTrustProjection(forged.admin).syncUser("u1", {nowMillis: NOW});
  const publicWrite = forged.writes.find(([p]) => p === "public_seller_profiles/u1")[1];
  assert.equal(publicWrite.reputationScore, "__DELETE__");
  assert.equal(publicWrite.reputationStatus, "new");

  const none = fakeAdmin({});
  assert.deepEqual((await createPublicTrustProjection(none.admin).syncUser("u9")).updated, []);
  assert.equal(none.writes.length, 0);

  const dry = fakeAdmin({docs: {"users/u1": {userScore: 1}, "public_seller_profiles/u1": {}}});
  const dryResult = await createPublicTrustProjection(dry.admin).syncUser("u1", {dryRun: true});
  assert.equal(dryResult.updated.length, 2);
  assert.equal(dry.writes.length, 0);
});

test("reconcileBatch walks members in order and reports where to resume", async () => {
  const docs = {};
  const userIds = ["a", "b", "c"];
  for (const id of userIds) docs[`users/${id}`] = {userScore: 1};
  const {admin} = fakeAdmin({docs, userIds});
  const projection = createPublicTrustProjection(admin);
  const first = await projection.reconcileBatch({limit: 2, nowMillis: NOW, dryRun: true});
  assert.equal(first.inspected, 2);
  assert.equal(first.nextCursor, "b");
  const second = await projection.reconcileBatch({afterUid: "b", limit: 2, nowMillis: NOW, dryRun: true});
  assert.equal(second.inspected, 1);
  assert.equal(second.nextCursor, "", "an empty cursor means the pass is complete");
});

test("module key list stays identical to the Firestore rules deny-list", () => {
  const rules = fs.readFileSync(path.resolve(__dirname, "..", "..", "firestore.rules"), "utf8");
  const match = rules.match(/function serverOwnedPublicTrustKeys\(\) \{([\s\S]*?)\n    \}/);
  assert.ok(match, "serverOwnedPublicTrustKeys is missing from the rules");
  const ruleKeys = [...match[1].matchAll(/'([A-Za-z]+)'/g)].map((m) => m[1]).sort();
  assert.deepEqual(ruleKeys, [...SERVER_OWNED_PUBLIC_TRUST_KEYS].sort());
});

test("score automation is wired to every input that changes it", () => {
  const index = fs.readFileSync(path.resolve(__dirname, "..", "index.js"), "utf8");
  for (const name of [
    "syncPublicTrustOnVipChange",
    "syncPublicTrustOnTransactionChange",
    "syncPublicTrustOnScoreEvent",
    "syncPublicTrustOnAccountChange",
    "syncPublicTrustOnReport",
    "reconcilePublicTrust",
  ]) {
    assert.match(index, new RegExp(`exports\\.${name} = `), `${name} is not exported`);
  }
  assert.match(index, /"trust_reports\/\{reportId\}"/);
  assert.match(index, /const scored = \["completed", "cancelled"\]/);
  assert.match(index, /schedule: "every day 03:30"/);
});
