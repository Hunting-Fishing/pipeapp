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
//  - No numeric reputation score is published until a reviewed scoring policy
//    defines the confidence threshold; until then the status stays "new" and the
//    client renders the blue "Building reputation" state.
//  - Only "vip" and "standard" are published. Bronze/Silver/Gold are not live
//    billing products and must not be projected.

const PUBLIC_PROFILE_COLLECTIONS = Object.freeze([
  "public_seller_profiles",
  "public_business_profiles",
]);

const PROJECTION_VERSION = 1;

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

function buildPublicTrustProjection({
  uid,
  vipMembership,
  completedTransactionCount,
  nowMillis = Date.now(),
}) {
  const count = Number.isSafeInteger(completedTransactionCount) &&
    completedTransactionCount > 0 ? completedTransactionCount : 0;
  return {
    membershipTier: vipMembershipCurrent(vipMembership, uid, nowMillis) ?
      "vip" : "standard",
    reputationStatus: "new",
    completedTransactionCount: count,
    scoreVersion: 0,
    trustProjectionVersion: PROJECTION_VERSION,
  };
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

    const [membershipSnapshot, completed] = await Promise.all([
      db.collection("vip_memberships").doc(id).get(),
      completedSaleCount(id),
    ]);
    const projection = buildPublicTrustProjection({
      uid: id,
      vipMembership: membershipSnapshot.exists ?
        membershipSnapshot.data() : null,
      completedTransactionCount: completed,
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
  SERVER_OWNED_PUBLIC_TRUST_KEYS,
  buildProfileUpdate,
  buildPublicTrustProjection,
  createPublicTrustProjection,
  vipMembershipCurrent,
};
