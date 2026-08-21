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

function dispatchMembershipCurrentForUser(
    membership,
    uid,
    nowMillis = Date.now(),
) {
  if (!membership || membership.ownerUid !== uid || membership.active !== true) {
    return false;
  }
  return timestampMillis(membership.currentPeriodEnd) > nowMillis;
}

function createDispatchMembershipAccess(admin) {
  const db = admin.firestore();

  async function requireCurrentDispatchMembership(request) {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      const snapshot = await db.collection("dispatch_memberships")
          .doc(identity.uid)
          .get();
      const membership = snapshot.exists ? snapshot.data() : null;
      if (!dispatchMembershipCurrentForUser(
          membership,
          identity.uid,
          Date.now(),
      )) {
        throw new HttpsError(
            "failed-precondition",
            "An active Dispatch monthly or yearly membership is required before bidding.",
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
  timestampMillis,
};
