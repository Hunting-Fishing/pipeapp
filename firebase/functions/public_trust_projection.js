"use strict";

// Server-owned public trust projection.
//
// Public seller/business profile documents are owner-editable, so display
// fields that other members rely on (membership tier, reputation, completed
// sales) must be written here, by trusted Functions, and are blocked from
// client writes by firestore.rules (serverOwnedPublicTrustKeys).
//
// Policy boundaries (docs/DISPATCH_REPUTATION_DUAL_RING_VISUAL_SYSTEM.md):
//  - Membership never feeds reputation.
//  - Status is "new" below REPUTATION_MIN_COMPLETED_SALES completed sales and
//    "emerging" at or above it. A numeric score (scoreVersion 1, the USER_SCORE_*
//    constants above) is published only for "emerging" members whose account is
//    not scheduled for deletion. It is computed here from the policy inputs and
//    does not read users.userScore, which the server never adjusts (flat 70).
//    Below the threshold the client keeps the blue "Building reputation" state.
//  - Only "vip" and "standard" are published. Bronze/Silver/Gold are not live
//    billing products and must not be projected.

const PUBLIC_PROFILE_COLLECTIONS = Object.freeze([
  "public_seller_profiles",
  "public_business_profiles",
]);

const PROJECTION_VERSION = 1;

// Product decision (2026-10-08): a member leaves the blue "NEW" state only after
// at least this many completed marketplace sales.
const REPUTATION_MIN_COMPLETED_SALES = 3;

// User Score v1 (approved 2026-10-11), built only from inputs that
// firebase/USER_SCORE_POLICY.md already defines:
//   70 neutral start
//   + 10 when identity/business verification was approved by an administrator
//   + 2 per completed marketplace sale, capped at +10
//   + the sum of administrator-confirmed adjustments in user_score_events
//   clamped to 0..100.
// "Consistent response and fulfillment history (up to +5)" is not collected yet
// and contributes nothing. Reversals on appeal must be recorded as an offsetting
// user_score_events entry.
const USER_SCORE_BASE = 70;
const USER_SCORE_VERIFIED_BONUS = 10;
const USER_SCORE_POINTS_PER_SALE = 2;
const USER_SCORE_SALES_BONUS_CAP = 10;
const USER_SCORE_VERSION = 1;
const SCORE_EVENT_READ_LIMIT = 500;
const INELIGIBLE_ACCOUNT_STATUSES = Object.freeze(["deletion_scheduled"]);

// Must match serverOwnedPublicTrustKeys() in firebase/firestore.rules.
const SERVER_OWNED_PUBLIC_TRUST_KEYS = Object.freeze([
  "reputationScore", "reputationStatus", "reviewAverage", "reviewCount",
  "completedTransactionCount", "responseBand", "reliabilityBand",
  "scoreVersion", "membershipTier", "subscriptionTier", "membership",
  "vipActive", "isVip", "vipStatus", "vipExpiresAt", "verified",
  "accountVerified", "verificationStatus", "userScore", "userScoreStanding",
  "trustProjectionVersion", "lastCalculatedAt",
]);

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function vipMembershipCurrent(membership, uid, nowMillis = Date.now()) {
  return Boolean(membership) &&
    membership.ownerUid === uid &&
    membership.active === true &&
    timestampMillis(membership.currentPeriodEnd) > nowMillis;
}

function sumScoreAdjustments(events) {
  let total = 0;
  for (const event of events || []) {
    const change = Number(event && event.change);
    if (Number.isFinite(change)) total += change;
  }
  return total;
}

// Membership is deliberately not an input: paying never raises reputation.
function computeUserScoreV1({
  accountVerified,
  completedTransactionCount,
  adjustmentTotal,
}) {
  const sales = Number.isSafeInteger(completedTransactionCount) &&
    completedTransactionCount > 0 ? completedTransactionCount : 0;
  const adjustment = Number.isFinite(adjustmentTotal) ? adjustmentTotal : 0;
  const raw = USER_SCORE_BASE +
    (accountVerified === true ? USER_SCORE_VERIFIED_BONUS : 0) +
    Math.min(USER_SCORE_SALES_BONUS_CAP, USER_SCORE_POINTS_PER_SALE * sales) +
    adjustment;
  return Math.max(0, Math.min(100, Math.round(raw)));
}

function buildPublicTrustProjection({
  uid,
  vipMembership,
  completedTransactionCount,
  accountVerified = false,
  accountStatus,
  adjustmentTotal = 0,
  nowMillis = Date.now(),
}) {
  const count = Number.isSafeInteger(completedTransactionCount) &&
    completedTransactionCount > 0 ? completedTransactionCount : 0;
  const experienced = count >= REPUTATION_MIN_COMPLETED_SALES;
  const scorable = experienced &&
    !INELIGIBLE_ACCOUNT_STATUSES.includes(accountStatus);
  const projection = {
    membershipTier: vipMembershipCurrent(vipMembership, uid, nowMillis) ?
      "vip" : "standard",
    reputationStatus: experienced ? "emerging" : "new",
    completedTransactionCount: count,
    scoreVersion: scorable ? USER_SCORE_VERSION : 0,
    trustProjectionVersion: PROJECTION_VERSION,
  };
  if (scorable) {
    projection.reputationScore = computeUserScoreV1({
      accountVerified,
      completedTransactionCount: count,
      adjustmentTotal,
    });
  }
  return projection;
}

// Returns the update to apply to one public profile, or null when the document
// already matches. Any other server-owned key found on the document (for
// example a value a client wrote before the rules guard shipped) is deleted.
function buildProfileUpdate(existing, projection, FieldValue) {
  const current = existing || {};
  const update = {};
  let changed = false;
  for (const [key, value] of Object.entries(projection)) {
    update[key] = value;
    if (current[key] !== value) changed = true;
  }
  for (const key of SERVER_OWNED_PUBLIC_TRUST_KEYS) {
    if (key in projection || key === "lastCalculatedAt") continue;
    if (Object.prototype.hasOwnProperty.call(current, key)) {
      update[key] = FieldValue.delete();
      changed = true;
    }
  }
  if (!changed) return null;
  update.lastCalculatedAt = FieldValue.serverTimestamp();
  return update;
}

function createPublicTrustProjection(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function completedSaleCount(uid) {
    const snapshot = await db.collection("marketplace_transactions")
        .where("sellerUid", "==", uid)
        .where("status", "==", "completed")
        .count()
        .get();
    return Number(snapshot.data().count) || 0;
  }

  async function syncUser(uid, {nowMillis = Date.now(), dryRun = false} = {}) {
    const id = String(uid || "").trim();
    if (!id) return {updated: [], projection: null};
    const snapshots = await Promise.all(
        PUBLIC_PROFILE_COLLECTIONS.map((name) =>
          db.collection(name).doc(id).get()),
    );
    const existing = snapshots.filter((snapshot) => snapshot.exists);
    if (existing.length === 0) return {updated: [], projection: null};

    const [membershipSnapshot, completed, userSnapshot, eventSnapshot] =
      await Promise.all([
        db.collection("vip_memberships").doc(id).get(),
        completedSaleCount(id),
        db.collection("users").doc(id).get(),
        db.collection("user_score_events")
            .where("userUid", "==", id)
            .limit(SCORE_EVENT_READ_LIMIT)
            .get(),
      ]);
    const user = userSnapshot.exists ? userSnapshot.data() : {};
    const projection = buildPublicTrustProjection({
      uid: id,
      vipMembership: membershipSnapshot.exists ?
        membershipSnapshot.data() : null,
      completedTransactionCount: completed,
      accountVerified: user.accountVerified === true,
      accountStatus: user.accountStatus,
      adjustmentTotal: sumScoreAdjustments(
          eventSnapshot.docs.map((document) => document.data()),
      ),
      nowMillis,
    });
    const updated = [];
    await Promise.all(existing.map(async (snapshot) => {
      const update = buildProfileUpdate(snapshot.data(), projection, FieldValue);
      if (!update) return;
      if (!dryRun) await snapshot.ref.update(update);
      updated.push(snapshot.ref.path);
    }));
    return {updated, projection};
  }

  return {completedSaleCount, syncUser};
}

module.exports = {
  PROJECTION_VERSION,
  PUBLIC_PROFILE_COLLECTIONS,
  REPUTATION_MIN_COMPLETED_SALES,
  SERVER_OWNED_PUBLIC_TRUST_KEYS,
  USER_SCORE_VERSION,
  buildProfileUpdate,
  buildPublicTrustProjection,
  computeUserScoreV1,
  createPublicTrustProjection,
  sumScoreAdjustments,
  vipMembershipCurrent,
};
