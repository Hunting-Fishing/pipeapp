"use strict";

// Server-owned public trust projection and automated User Score.
//
// Public seller/business profile documents are owner-editable, so display
// fields other members rely on (membership tier, reputation, completed sales)
// are written here, by trusted Functions, and are blocked from client writes by
// firestore.rules (serverOwnedPublicTrustKeys).
//
// Policy boundaries (docs/DISPATCH_REPUTATION_DUAL_RING_VISUAL_SYSTEM.md,
// firebase/USER_SCORE_POLICY.md):
//  - Membership never feeds reputation.
//  - Only "vip" and "standard" tiers are published.
//  - Status is "new" below REPUTATION_MIN_COMPLETED_SALES completed sales and
//    "emerging" at or above it. The numeric score is published only for
//    "emerging" members whose account is not scheduled for deletion.
//  - The score is computed here from server data only and is also written to
//    users/{uid}.userScore (private, used by auction thresholds). Nothing in
//    it is hand-entered, but administrators may still add exceptional
//    adjustments as user_score_events.

const {FieldPath} = require("firebase-admin/firestore");

const PUBLIC_PROFILE_COLLECTIONS = Object.freeze([
  "public_seller_profiles",
  "public_business_profiles",
]);

const PROJECTION_VERSION = 1;

// Product decision (2026-10-08): a member leaves the blue "NEW" state only after
// at least this many completed marketplace sales.
const REPUTATION_MIN_COMPLETED_SALES = 3;

// User Score v2 (automated). Inputs, all derived by the server:
//   70 neutral start
//   + 10 administrator-approved identity/business verification
//   + 2 per completed marketplace sale, capped at +10
//   + up to 5 for fulfillment: completed / (completed + cancelled by the
//     seller), once the member has REPUTATION_MIN_COMPLETED_SALES sales.
//     Disputes are accusations, not proof, so they are not counted.
//   + confirmed moderation outcomes from trust_reports (an administrator's
//     decision is the trigger; the points are applied automatically and are
//     reversed automatically when an appeal is overturned)
//   + any administrator-entered user_score_events (exceptional cases)
//   clamped to 0..100.
const USER_SCORE_BASE = 70;
const USER_SCORE_VERIFIED_BONUS = 10;
const USER_SCORE_POINTS_PER_SALE = 2;
const USER_SCORE_SALES_BONUS_CAP = 10;
const FULFILLMENT_BONUS_CAP = 5;
const USER_SCORE_VERSION = 2;
const SCORE_EVENT_READ_LIMIT = 500;
const REPORT_READ_LIMIT = 200;
const MODERATION_PENALTY_FLOOR = -100;
const INELIGIBLE_ACCOUNT_STATUSES = Object.freeze(["deletion_scheduled"]);

// A report only counts once an administrator confirmed it (or upheld it on
// appeal). Pending, dismissed, appealed-and-under-review, and overturned
// reports never change a score (USER_SCORE_POLICY.md).
const CONFIRMED_REPORT_STATUSES = Object.freeze([
  "violation_confirmed",
  "appeal_upheld",
]);

// Points per confirmed incident, chosen inside the policy ranges:
//   minor conduct -2..-8, misleading listing or spam -10..-25,
//   fraud, threats, stolen goods -25..-100.
const REPORT_REASON_PENALTIES = Object.freeze({
  fraud_or_scam: -40,
  hate_or_racist_content: -25,
  prohibited_or_unsafe_item: -25,
  misleading_information: -15,
  reused_photos: -15,
  duplicate_listing: -10,
  spam: -10,
  vulgar_or_harassing_content: -5,
  other: -3,
});
const DEFAULT_REPORT_PENALTY = REPORT_REASON_PENALTIES.other;

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

function nonNegativeInteger(value) {
  return Number.isSafeInteger(value) && value > 0 ? value : 0;
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

// One incident produces one adjustment even if it was reported several times:
// reports are grouped by their target and only the most serious one counts.
function moderationPenaltyTotal(reports) {
  const worstByIncident = new Map();
  for (const report of reports || []) {
    if (!report || !CONFIRMED_REPORT_STATUSES.includes(report.status)) continue;
    const reason = String(report.reason || "");
    const penalty = Object.prototype.hasOwnProperty.call(
        REPORT_REASON_PENALTIES, reason) ?
      REPORT_REASON_PENALTIES[reason] : DEFAULT_REPORT_PENALTY;
    const targetId = report.listingId || report.messageId || report.offerId ||
      report.conversationId || report.targetId;
    const incident = targetId ?
      `${report.targetType || "target"}:${targetId}` :
      `report:${report.id || reason}`;
    const current = worstByIncident.get(incident);
    if (current === undefined || penalty < current) {
      worstByIncident.set(incident, penalty);
    }
  }
  let total = 0;
  for (const penalty of worstByIncident.values()) total += penalty;
  return Math.max(MODERATION_PENALTY_FLOOR, total);
}

function fulfillmentBonus({completedTransactionCount, sellerCancelledCount}) {
  const completed = nonNegativeInteger(completedTransactionCount);
  const cancelled = nonNegativeInteger(sellerCancelledCount);
  if (completed < REPUTATION_MIN_COMPLETED_SALES) return 0;
  return Math.round(FULFILLMENT_BONUS_CAP * completed / (completed + cancelled));
}

// Membership is deliberately not an input: paying never raises reputation.
function computeUserScore({
  accountVerified,
  completedTransactionCount,
  sellerCancelledCount = 0,
  adjustmentTotal = 0,
  moderationPenalty = 0,
}) {
  const sales = nonNegativeInteger(completedTransactionCount);
  const adjustment = Number.isFinite(adjustmentTotal) ? adjustmentTotal : 0;
  const penalty = Number.isFinite(moderationPenalty) ? moderationPenalty : 0;
  const raw = USER_SCORE_BASE +
    (accountVerified === true ? USER_SCORE_VERIFIED_BONUS : 0) +
    Math.min(USER_SCORE_SALES_BONUS_CAP, USER_SCORE_POINTS_PER_SALE * sales) +
    fulfillmentBonus({
      completedTransactionCount: sales,
      sellerCancelledCount,
    }) +
    adjustment +
    penalty;
  return Math.max(0, Math.min(100, Math.round(raw)));
}

function buildPublicTrustProjection({
  uid,
  vipMembership,
  completedTransactionCount,
  accountVerified = false,
  accountStatus,
  sellerCancelledCount = 0,
  adjustmentTotal = 0,
  moderationPenalty = 0,
  nowMillis = Date.now(),
}) {
  const count = nonNegativeInteger(completedTransactionCount);
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
    projection.reputationScore = computeUserScore({
      accountVerified,
      completedTransactionCount: count,
      sellerCancelledCount,
      adjustmentTotal,
      moderationPenalty,
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

  async function countTransactions(uid, status, extraField) {
    let query = db.collection("marketplace_transactions")
        .where("sellerUid", "==", uid)
        .where("status", "==", status);
    if (extraField) query = query.where(extraField, "==", uid);
    const snapshot = await query.count().get();
    return Number(snapshot.data().count) || 0;
  }

  const completedSaleCount = (uid) => countTransactions(uid, "completed");
  const sellerCancelledCount = (uid) =>
    countTransactions(uid, "cancelled", "cancelledByUid");

  async function syncUser(uid, {nowMillis = Date.now(), dryRun = false} = {}) {
    const id = String(uid || "").trim();
    if (!id) return {updated: [], projection: null, userScore: null};

    const [
      userSnapshot,
      membershipSnapshot,
      completed,
      cancelled,
      eventSnapshot,
      reportSnapshot,
      ...profileSnapshots
    ] = await Promise.all([
      db.collection("users").doc(id).get(),
      db.collection("vip_memberships").doc(id).get(),
      completedSaleCount(id),
      sellerCancelledCount(id),
      db.collection("user_score_events")
          .where("userUid", "==", id)
          .limit(SCORE_EVENT_READ_LIMIT)
          .get(),
      db.collection("trust_reports")
          .where("reportedUid", "==", id)
          .limit(REPORT_READ_LIMIT)
          .get(),
      ...PUBLIC_PROFILE_COLLECTIONS.map((name) =>
        db.collection(name).doc(id).get()),
    ]);

    const user = userSnapshot.exists ? userSnapshot.data() : {};
    const scoreInputs = {
      accountVerified: user.accountVerified === true,
      completedTransactionCount: completed,
      sellerCancelledCount: cancelled,
      adjustmentTotal: sumScoreAdjustments(
          eventSnapshot.docs.map((document) => document.data()),
      ),
      moderationPenalty: moderationPenaltyTotal(
          reportSnapshot.docs.map((document) => ({
            id: document.id,
            ...document.data(),
          })),
      ),
    };
    const userScore = computeUserScore(scoreInputs);
    const projection = buildPublicTrustProjection({
      uid: id,
      vipMembership: membershipSnapshot.exists ?
        membershipSnapshot.data() : null,
      accountStatus: user.accountStatus,
      nowMillis,
      ...scoreInputs,
    });

    const updated = [];
    if (userSnapshot.exists && user.userScore !== userScore) {
      if (!dryRun) {
        await userSnapshot.ref.update({
          userScore,
          userScoreVersion: USER_SCORE_VERSION,
          userScoreUpdatedAt: FieldValue.serverTimestamp(),
        });
      }
      updated.push(userSnapshot.ref.path);
    }
    await Promise.all(profileSnapshots
        .filter((snapshot) => snapshot.exists)
        .map(async (snapshot) => {
          const update = buildProfileUpdate(
              snapshot.data(), projection, FieldValue);
          if (!update) return;
          if (!dryRun) await snapshot.ref.update(update);
          updated.push(snapshot.ref.path);
        }));
    return {updated, projection, userScore};
  }

  // Walks users in id order so a scheduled run can resume where it stopped.
  async function reconcileBatch({
    afterUid = "",
    limit = 200,
    nowMillis = Date.now(),
    dryRun = false,
  } = {}) {
    let query = db.collection("users")
        .orderBy(FieldPath.documentId())
        .limit(limit);
    if (afterUid) query = query.startAfter(afterUid);
    const page = await query.get();
    let changed = 0;
    let lastUid = "";
    for (const document of page.docs) {
      const result = await syncUser(document.id, {nowMillis, dryRun});
      changed += result.updated.length;
      lastUid = document.id;
    }
    return {
      inspected: page.docs.length,
      changed,
      nextCursor: page.docs.length < limit ? "" : lastUid,
    };
  }

  return {
    completedSaleCount,
    reconcileBatch,
    sellerCancelledCount,
    syncUser,
  };
}

module.exports = {
  CONFIRMED_REPORT_STATUSES,
  PROJECTION_VERSION,
  PUBLIC_PROFILE_COLLECTIONS,
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
};
