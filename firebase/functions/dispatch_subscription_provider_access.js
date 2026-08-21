"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  createPolicyAcceptanceCommands,
} = require("./policy_acceptance_commands");

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
  const policyAcceptance = createPolicyAcceptanceCommands(admin);
  const requirePolicies = policyAcceptance.requireCurrentPolicies(
      async () => ({current: true}),
  );

  async function requireNoBlockingProviderSubscription(request) {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});

      // Billing must respect the same exact-version policy acceptance control as
      // other protected commercial actions. When production policy enforcement
      // is enabled, an account with missing or stale policy acceptance cannot
      // reach Stripe Checkout. This check intentionally occurs before any
      // provider lookup or money-creating operation.
      await requirePolicies(request);

      const snapshot = await db.collection("dispatch_subscription_provider_state")
          .doc(identity.uid)
          .get();
      if (snapshot.exists && providerStateBlocksNewCheckout(snapshot.data())) {
        throw new HttpsError(
            "failed-precondition",
            "An existing Stripe Dispatch subscription must be resolved before starting another checkout.",
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
          "Existing Dispatch subscription status could not be verified.",
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
