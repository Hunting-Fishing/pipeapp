"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  portalReady,
  providerStateSupportsPortal,
} = require("./dispatch_subscription_portal");

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
      paymentIssue: false,
      cancelAtPeriodEnd: false,
      providerStatus: "",
      renewalStatus: "",
    };
  }
  const periodStart = timestampMillis(data.currentPeriodStart);
  const periodEnd = timestampMillis(data.currentPeriodEnd);
  const active = data.active === true && periodEnd > nowMillis;
  const status = active ?
    String(data.status || "active") :
    periodEnd > 0 && periodEnd <= nowMillis ?
      "expired" :
      String(data.status || "inactive");
  return {
    active,
    status,
    plan: String(data.plan || ""),
    currentPeriodStartMillis: periodStart > 0 ? periodStart : null,
    currentPeriodEndMillis: periodEnd > 0 ? periodEnd : null,
    paymentIssue: data.paymentIssue === true,
    cancelAtPeriodEnd: data.cancelAtPeriodEnd === true,
    providerStatus: String(data.providerStatus || ""),
    renewalStatus: String(data.renewalStatus || ""),
  };
}

function managementAvailable({readiness, providerState, uid}) {
  return portalReady(readiness) &&
    providerStateSupportsPortal(providerState, uid);
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
      const [membershipSnapshot, readinessSnapshot, providerSnapshot] =
        await Promise.all([
          db.collection("dispatch_memberships").doc(identity.uid).get(),
          db.collection("platform_configuration")
              .doc("payment_provider_readiness")
              .get(),
          db.collection("dispatch_subscription_provider_state")
              .doc(identity.uid)
              .get(),
        ]);
      const payload = membershipStatusPayload(
          membershipSnapshot.exists ? membershipSnapshot.data() : null,
          Date.now(),
      );
      return {
        ...payload,
        managementAvailable: managementAvailable({
          readiness: readinessSnapshot.exists ? readinessSnapshot.data() : {},
          providerState: providerSnapshot.exists ? providerSnapshot.data() : null,
          uid: identity.uid,
        }),
      };
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
  managementAvailable,
  membershipStatusPayload,
  timestampMillis,
};
