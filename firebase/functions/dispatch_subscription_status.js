"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function membershipStatusPayload(data, nowMillis = Date.now()) {
  if (!data) {
    return {
      active: false,
      status: "none",
      plan: "",
      currentPeriodStartMillis: null,
      currentPeriodEndMillis: null,
    };
  }
  const periodStart = timestampMillis(data.currentPeriodStart);
  const periodEnd = timestampMillis(data.currentPeriodEnd);
  const active = data.active === true && periodEnd > nowMillis;
  const status = active ?
    "active" :
    periodEnd > 0 && periodEnd <= nowMillis ?
      "expired" :
      String(data.status || "inactive");
  return {
    active,
    status,
    plan: String(data.plan || ""),
    currentPeriodStartMillis: periodStart > 0 ? periodStart : null,
    currentPeriodEndMillis: periodEnd > 0 ? periodEnd : null,
  };
}

function createDispatchSubscriptionStatus(admin) {
  const db = admin.firestore();

  const getDispatchSubscriptionStatus = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "account",
      });
      const snapshot = await db.collection("dispatch_memberships")
          .doc(identity.uid)
          .get();
      return membershipStatusPayload(
          snapshot.exists ? snapshot.data() : null,
          Date.now(),
      );
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription status failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch membership status could not be loaded.",
      );
    }
  };

  return {getDispatchSubscriptionStatus};
}

module.exports = {
  createDispatchSubscriptionStatus,
  membershipStatusPayload,
  timestampMillis,
};
