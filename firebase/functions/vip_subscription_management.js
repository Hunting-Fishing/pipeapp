"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  loadProviderReadiness,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

function requestedRenewalAction(value) {
  const action = String(value || "").trim();
  if (!new Set(["cancel_at_period_end", "resume_renewal"]).has(action)) {
    throw new HttpsError("invalid-argument", "The VIP renewal action is invalid.");
  }
  return action;
}

function requireVipManagementReady(readiness) {
  if (readiness.stripeMode !== "production" ||
      readiness.stripeWebhookVerified !== true ||
      readiness.stripeSubscriptionsEnabled !== true ||
      readiness.stripeVipSubscriptionsEnabled !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Pipe Buyer VIP subscription management is not enabled yet.",
    );
  }
}

function createVipSubscriptionManagement(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const updateVipSubscriptionRenewal = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const action = requestedRenewalAction(request.data && request.data.action);
      const [readinessSnapshot, providerSnapshot] = await Promise.all([
        db.collection("platform_configuration")
            .doc("payment_provider_readiness")
            .get(),
        db.collection("vip_subscription_provider_state")
            .doc(identity.uid)
            .get(),
      ]);
      const data = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: data.stripeSubscriptionsEnabled === true,
        stripeVipSubscriptionsEnabled: data.stripeVipSubscriptionsEnabled === true,
      };
      requireVipManagementReady(readiness);
      if (!providerSnapshot.exists ||
          providerSnapshot.data().ownerUid !== identity.uid) {
        throw new HttpsError(
            "failed-precondition",
            "No Pipe Buyer VIP subscription is available to manage.",
        );
      }
      const provider = providerSnapshot.data();
      const subscriptionId = String(provider.subscriptionId || "");
      if (!subscriptionId.startsWith("sub_")) {
        throw new HttpsError(
            "failed-precondition",
            "No Pipe Buyer VIP subscription is available to manage.",
        );
      }
      const cancelAtPeriodEnd = action === "cancel_at_period_end";
      const subscription = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
        fields: {
          cancel_at_period_end: cancelAtPeriodEnd ? "true" : "false",
        },
      });
      if (String(subscription.id || "") !== subscriptionId) {
        throw new HttpsError(
            "internal",
            "Stripe did not confirm the VIP renewal change.",
        );
      }
      await db.collection("vip_subscription_provider_state")
          .doc(identity.uid).set({
            cancelAtPeriodEnd,
            providerStatus: String(subscription.status || provider.providerStatus || ""),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      // Paid access is not changed here. Verified Stripe lifecycle webhooks and
      // invoice.paid remain authoritative for VIP access and expiration.
      return {
        cancelAtPeriodEnd,
        status: String(subscription.status || ""),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Pipe Buyer VIP renewal management failed", error);
      throw new HttpsError(
          "internal",
          "Pipe Buyer VIP renewal could not be updated.",
      );
    }
  };

  return {updateVipSubscriptionRenewal};
}

module.exports = {
  createVipSubscriptionManagement,
  requestedRenewalAction,
  requireVipManagementReady,
};
