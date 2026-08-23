"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  CONFIG_COLLECTION,
  PORTAL_DOC,
  normalizePortalConfig,
} = require("./dispatch_billing_portal_admin");
const {
  dispatchBillingPortalProviderAssessment,
  validStripeBillingPortalConfigurationId,
} = require("./dispatch_billing_portal_policy");
const {
  safeConfiguredUrl,
  stripeFormRequest,
} = require("./stripe_checkout_commands");
const {stripeSecretKey} = require("./stripe_marketplace_commands");

function createDispatchBillingPortalVerificationCommands(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretProvider = options.secretProvider || (() => stripeSecretKey.value());

  async function verifyDispatchBillingPortalConfiguration(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const configurationId = String(
          request.data && request.data.stripePortalConfigurationId || "",
      ).trim();
      if (!validStripeBillingPortalConfigurationId(configurationId)) {
        throw new HttpsError(
            "invalid-argument",
            "A valid Stripe Billing Portal configuration ID is required.",
        );
      }
      const returnUrl = safeConfiguredUrl(
          request.data && request.data.returnUrl,
          "Dispatch Billing Portal return URL",
      );
      const reason = String(request.data && request.data.reason || "").trim();
      if (reason.length < 10 || reason.length > 1000) {
        throw new HttpsError(
            "invalid-argument",
            "A concise Billing Portal verification reason is required.",
        );
      }
      if (request.data && request.data.confirmProduction !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Live Dispatch Billing Portal verification requires explicit production confirmation.",
        );
      }

      const providerConfiguration = await stripeRequest({
        secretKey: secretProvider(),
        path: `/v1/billing_portal/configurations/${encodeURIComponent(configurationId)}`,
        method: "GET",
      });
      const assessment = dispatchBillingPortalProviderAssessment(
          providerConfiguration,
      );
      if (assessment.configurationId !== configurationId) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe returned a different Billing Portal configuration identity.",
        );
      }
      if (!assessment.ready) {
        throw new HttpsError(
            "failed-precondition",
            `The live Stripe Billing Portal configuration is not launch-ready (${assessment.failedChecks.join(", ")}).`,
        );
      }

      const ref = db.collection(CONFIG_COLLECTION).doc(PORTAL_DOC);
      return await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const previous = normalizePortalConfig(
            snapshot.exists ? snapshot.data() : {},
        );
        const revision = previous.revision + 1;
        const next = {
          enabled: true,
          returnUrl,
          stripePortalConfigurationId: configurationId,
          providerVerified: true,
          providerVerifiedConfigurationId: configurationId,
          providerVerificationRevision: assessment.revision,
          providerVerifiedFeatures: assessment.features,
          revision,
        };
        transaction.set(ref, {
          ...next,
          providerVerifiedAt: FieldValue.serverTimestamp(),
          lastChangedByUid: administratorUid,
          lastChangeReason: reason,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        transaction.create(
            db.collection("dispatch_billing_portal_audit").doc(),
            {
              administratorUid,
              reason,
              previous,
              next,
              providerAssessment: {
                configurationId: assessment.configurationId,
                revision: assessment.revision,
                failedChecks: assessment.failedChecks,
                features: assessment.features,
              },
              createdAt: FieldValue.serverTimestamp(),
            },
        );
        return next;
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch Billing Portal provider verification failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch Billing Portal provider verification could not be completed.",
      );
    }
  }

  return {verifyDispatchBillingPortalConfiguration};
}

module.exports = {
  createDispatchBillingPortalVerificationCommands,
};
