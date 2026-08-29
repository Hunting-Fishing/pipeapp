"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {membershipStatusPayload} = require("./dispatch_subscription_status");

function createVipSubscriptionStatus(admin) {
  const db = admin.firestore();

  const getVipSubscriptionStatus = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const [membershipSnapshot, providerSnapshot] = await Promise.all([
        db.collection("vip_memberships").doc(identity.uid).get(),
        db.collection("vip_subscription_provider_state").doc(identity.uid).get(),
      ]);
      const payload = membershipStatusPayload(
          membershipSnapshot.exists ? membershipSnapshot.data() : null,
          Date.now(),
      );
      const provider = providerSnapshot.exists ? providerSnapshot.data() : null;
      const canManageRenewal = Boolean(
          provider &&
          provider.ownerUid === identity.uid &&
          String(provider.subscriptionId || "").startsWith("sub_") &&
          !["canceled", "incomplete_expired"].includes(
              String(provider.providerStatus || ""),
          ),
      );
      return {
        ...payload,
        canManageRenewal,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Pipe Buyer VIP subscription status failed", error);
      throw new HttpsError(
          "internal",
          "Pipe Buyer VIP membership status could not be loaded.",
      );
    }
  };

  return {getVipSubscriptionStatus};
}

module.exports = {createVipSubscriptionStatus};
