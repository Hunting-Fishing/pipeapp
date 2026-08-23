"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  dispatchBillingPortalProviderRecordReady,
} = require("./dispatch_billing_portal_policy");

const CONFIG_COLLECTION = "platform_configuration";
const PORTAL_DOC = "dispatch_billing_portal";

function normalizePortalConfig(data = {}) {
  const features = data.providerVerifiedFeatures &&
    typeof data.providerVerifiedFeatures === "object" ?
    data.providerVerifiedFeatures : {};
  const providerVerified = dispatchBillingPortalProviderRecordReady(data);
  return Object.freeze({
    enabled: data.enabled === true && providerVerified,
    returnUrl: String(data.returnUrl || ""),
    stripePortalConfigurationId:
      String(data.stripePortalConfigurationId || "").trim(),
    providerVerified,
    providerVerifiedConfigurationId:
      String(data.providerVerifiedConfigurationId || "").trim(),
    providerVerificationRevision:
      String(data.providerVerificationRevision || "").trim(),
    providerVerifiedFeatures: Object.freeze({
      paymentMethodUpdate: features.paymentMethodUpdate === true,
      invoiceHistory: features.invoiceHistory === true,
      subscriptionCancel: features.subscriptionCancel === true,
      subscriptionCancelMode: String(features.subscriptionCancelMode || ""),
      subscriptionCancelProration:
        String(features.subscriptionCancelProration || ""),
      subscriptionUpdate: features.subscriptionUpdate === true,
    }),
    revision: Math.max(0, Number(data.revision || 0)),
  });
}

function createDispatchBillingPortalAdmin(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function getDispatchBillingPortalReadiness(request) {
    try {
      requireAdministrator(request);
      const snapshot = await db.collection(CONFIG_COLLECTION).doc(PORTAL_DOC).get();
      return normalizePortalConfig(snapshot.exists ? snapshot.data() : {});
    } catch (error) {
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      throw error;
    }
  }

  async function setDispatchBillingPortalReadiness(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const reason = String(request.data && request.data.reason || "").trim();
      if (reason.length < 10 || reason.length > 1000) {
        throw new HttpsError(
            "invalid-argument",
            "A concise Billing Portal readiness reason is required.",
        );
      }
      if (request.data && request.data.enabled === true) {
        throw new HttpsError(
            "failed-precondition",
            "Live Dispatch Billing Portal readiness can only be enabled after server-side Stripe provider verification.",
        );
      }

      const ref = db.collection(CONFIG_COLLECTION).doc(PORTAL_DOC);
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const previous = normalizePortalConfig(snapshot.exists ? snapshot.data() : {});
        const revision = previous.revision + 1;
        const next = {
          enabled: false,
          returnUrl: "",
          stripePortalConfigurationId: "",
          providerVerified: false,
          providerVerifiedConfigurationId: "",
          providerVerificationRevision: "",
          providerVerifiedFeatures: {
            paymentMethodUpdate: false,
            invoiceHistory: false,
            subscriptionCancel: false,
            subscriptionCancelMode: "",
            subscriptionCancelProration: "",
            subscriptionUpdate: false,
          },
          revision,
        };
        transaction.set(ref, {
          ...next,
          lastChangedByUid: administratorUid,
          lastChangeReason: reason,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        transaction.create(db.collection("dispatch_billing_portal_audit").doc(), {
          administratorUid,
          reason,
          previous,
          next,
          createdAt: FieldValue.serverTimestamp(),
        });
        return next;
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch Billing Portal readiness update failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch Billing Portal readiness could not be updated.",
      );
    }
  }

  return {
    getDispatchBillingPortalReadiness,
    setDispatchBillingPortalReadiness,
  };
}

module.exports = {
  CONFIG_COLLECTION,
  PORTAL_DOC,
  createDispatchBillingPortalAdmin,
  normalizePortalConfig,
};
