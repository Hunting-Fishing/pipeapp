"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  dispatchSubscriptionPublicStatus,
} = require("./dispatch_subscription_status_policy");

const DISPATCH_SUBSCRIPTIONS_COLLECTION = "dispatch_subscriptions";

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function createDispatchSubscriptionStatusCommands(admin, options = {}) {
  const db = admin.firestore();
  const authUid = options.authUid || requireAuth;
  const rateLimit = options.rateLimit || enforceUserRateLimit;

  const getDispatchSubscriptionStatus = async (request) => {
    try {
      const uid = authUid(request);
      await rateLimit({db, admin, request, scope: "account"});
      const snapshot = await db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
          .doc(uid)
          .get();
      const state = snapshot.exists ? snapshot.data() : {};
      return dispatchSubscriptionPublicStatus(state);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription status lookup failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch subscription status could not be loaded.",
      );
    }
  };

  return {getDispatchSubscriptionStatus};
}

module.exports = {
  DISPATCH_SUBSCRIPTIONS_COLLECTION,
  createDispatchSubscriptionStatusCommands,
};
