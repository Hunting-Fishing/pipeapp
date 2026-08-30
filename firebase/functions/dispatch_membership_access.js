"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function paidMembershipCurrentForUser(
    membership,
    uid,
    nowMillis = Date.now(),
) {
  if (!membership || membership.ownerUid !== uid || membership.active !== true) {
    return false;
  }
  return timestampMillis(membership.currentPeriodEnd) > nowMillis;
}

const dispatchMembershipCurrentForUser = paidMembershipCurrentForUser;

function createDispatchMembershipAccess(admin) {
  const db = admin.firestore();

  async function requireCurrentDispatchMembership(request) {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      const [dispatchSnapshot, vipSnapshot] = await Promise.all([
        db.collection("dispatch_memberships").doc(identity.uid).get(),
        db.collection("vip_memberships").doc(identity.uid).get(),
      ]);
      const dispatchMembership = dispatchSnapshot.exists ? dispatchSnapshot.data() : null;
      const vipMembership = vipSnapshot.exists ? vipSnapshot.data() : null;
      const nowMillis = Date.now();
      const allowed = paidMembershipCurrentForUser(
          dispatchMembership,
          identity.uid,
          nowMillis,
      ) || paidMembershipCurrentForUser(
          vipMembership,
          identity.uid,
          nowMillis,
      );
      if (!allowed) {
        throw new HttpsError(
            "failed-precondition",
            "An active Monthly, Yearly, or VIP membership is required before bidding.",
        );
      }
      return identity.uid;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch membership access check failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch membership eligibility could not be verified.",
      );
    }
  }

  return {requireCurrentDispatchMembership};
}

module.exports = {
  createDispatchMembershipAccess,
  dispatchMembershipCurrentForUser,
  paidMembershipCurrentForUser,
  timestampMillis,
};
