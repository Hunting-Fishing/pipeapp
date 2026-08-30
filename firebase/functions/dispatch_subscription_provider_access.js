"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  currentPolicyAcceptanceStatus,
} = require("./policy_acceptance_status");

const TERMINAL_PROVIDER_STATUSES = new Set([
  "canceled",
  "incomplete_expired",
]);

function providerStateBlocksNewCheckout(state) {
  if (!state) return false;
  const subscriptionId = String(state.subscriptionId || "").trim();
  if (!subscriptionId.startsWith("sub_")) return false;
  const status = String(state.providerStatus || "unknown").trim();
  return !TERMINAL_PROVIDER_STATUSES.has(status);
}

function createDispatchSubscriptionProviderAccess(admin) {
  const db = admin.firestore();

  async function requireNoBlockingProviderSubscription(request) {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});

      // Billing uses the same exact-version policy model as the rest of the
      // commercial app. When policy enforcement is on, stale or missing
      // acceptance fails before any provider lookup or money-creating operation.
      const policyStatus = await currentPolicyAcceptanceStatus(db, identity.uid);
      if (!policyStatus.current) {
        throw new HttpsError(
            "failed-precondition",
            "Review and accept the current Pipe Buyer policies before starting Dispatch billing.",
        );
      }

      const [dispatchSnapshot, vipSnapshot] = await Promise.all([
        db.collection("dispatch_subscription_provider_state").doc(identity.uid).get(),
        db.collection("vip_subscription_provider_state").doc(identity.uid).get(),
      ]);
      const dispatchBlocked = dispatchSnapshot.exists &&
        providerStateBlocksNewCheckout(dispatchSnapshot.data());
      const vipBlocked = vipSnapshot.exists &&
        providerStateBlocksNewCheckout(vipSnapshot.data());
      if (dispatchBlocked || vipBlocked) {
        throw new HttpsError(
            "failed-precondition",
            "An existing paid membership subscription already exists. Use Change plan instead of starting a second subscription.",
        );
      }
      return identity.uid;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription provider-state check failed", error);
      throw new HttpsError(
          "internal",
          "Existing membership subscription status could not be verified.",
      );
    }
  }

  return {requireNoBlockingProviderSubscription};
}

module.exports = {
  TERMINAL_PROVIDER_STATUSES,
  createDispatchSubscriptionProviderAccess,
  providerStateBlocksNewCheckout,
};
