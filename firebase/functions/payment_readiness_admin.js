"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  canadaSmallSupplierAssessmentDecision,
} = require("./canada_small_supplier_readiness_guard");

const READINESS_DOC = "payment_provider_readiness";
const CONFIG_COLLECTION = "platform_configuration";
const SMALL_SUPPLIER_ASSESSMENT_COLLECTION = "tax_threshold_assessments";
const SMALL_SUPPLIER_ASSESSMENT_DOC = "canada_gst_hst_current";
const MODES = new Set(["disabled", "sandbox", "production"]);
const BOOLEAN_FIELDS = Object.freeze([
  "stripeConnectOnboardingEnabled",
  "stripeCheckoutEnabled",
  "stripeFeeBillingEnabled",
  "stripeSubscriptionsEnabled",
  "stripeSubscriptionRecoveryVerified",
  "stripeSubscriptionLifecycleWebhookVerified",
  "dispatchAffiliateCommissionAccrualEnabled",
  "stripeWebhookVerified",
  "stripeTaxReady",
  "stripeTaxRegistrationPending",
  "stripeTaxPendingBillingApproved",
  "canadaGstHstSmallSupplier",
  "stripeReconciliationReady",
  "affiliatePayoutsEnabled",
  "marketplaceFinancialResolutionEnabled",
  "marketplaceDisputeAutomationEnabled",
  "marketplaceDisputeEvidenceEnabled",
  "platformFundedRefundOverrideEnabled",
]);
const URL_FIELDS = Object.freeze([
  "connectReturnUrl",
  "connectRefreshUrl",
  "checkoutSuccessUrl",
  "checkoutCancelUrl",
]);

function safeHttpsPipeBuyerUrl(value, field) {
  let url;
  try {
    url = new URL(String(value || ""));
  } catch (_) {
    throw new HttpsError("invalid-argument", `${field} must be a valid URL.`);
  }
  const host = url.hostname.toLowerCase();
  if (url.protocol !== "https:" ||
      !(host === "pipebuyer.com" || host.endsWith(".pipebuyer.com"))) {
    throw new HttpsError(
        "invalid-argument",
        `${field} must use HTTPS on pipebuyer.com or a subdomain.`,
    );
  }
  return url.toString();
}

function normalizeReadiness(data = {}) {
  const normalized = {
    stripeMode: MODES.has(String(data.stripeMode || "")) ?
      String(data.stripeMode) : "disabled",
  };
  for (const field of BOOLEAN_FIELDS) normalized[field] = data[field] === true;
  for (const field of URL_FIELDS) normalized[field] = String(data[field] || "");
  return normalized;
}

function taxBillingPrepared(next) {
  return next.stripeTaxReady === true ||
    next.canadaGstHstSmallSupplier === true ||
    (next.stripeTaxRegistrationPending === true &&
      next.stripeTaxPendingBillingApproved === true);
}

function validateReadiness(next, options = {}) {
  if (!MODES.has(next.stripeMode)) {
    throw new HttpsError("invalid-argument", "stripeMode is invalid.");
  }
  if (next.stripeMode === "production" && options.confirmProduction !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Production mode requires explicit confirmation.",
    );
  }
  const taxIdentityStates = [
    next.stripeTaxReady === true,
    next.stripeTaxRegistrationPending === true,
    next.canadaGstHstSmallSupplier === true,
  ].filter(Boolean).length;
  if (taxIdentityStates > 1) {
    throw new HttpsError(
        "failed-precondition",
        "GST/HST status must be exactly one of registered, registration pending, or Canadian small supplier.",
    );
  }
  if (next.stripeTaxRegistrationPending && next.stripeMode !== "production") {
    throw new HttpsError(
        "failed-precondition",
        "Pending tax registration may only be used with production billing.",
    );
  }
  if (next.canadaGstHstSmallSupplier && next.stripeMode !== "production") {
    throw new HttpsError(
        "failed-precondition",
        "Canadian small-supplier billing status may only be used with production billing.",
    );
  }
  if (next.stripeTaxPendingBillingApproved &&
      !next.stripeTaxRegistrationPending) {
    throw new HttpsError(
        "failed-precondition",
        "Pending-tax billing approval may only be enabled while tax registration is explicitly pending.",
    );
  }
  if (next.stripeCheckoutEnabled && !(
    next.stripeMode === "production" &&
    next.stripeConnectOnboardingEnabled &&
    next.stripeWebhookVerified &&
    next.stripeTaxReady &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Full marketplace checkout requires production mode, Connect onboarding, verified webhooks, active tax registration, and reconciliation readiness.",
    );
  }
  if (next.stripeFeeBillingEnabled && !(
    next.stripeMode === "production" &&
    next.stripeWebhookVerified &&
    taxBillingPrepared(next) &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Marketplace fee billing requires production mode, verified webhooks, reconciliation readiness, and an authorized GST/HST billing state.",
    );
  }
  if (next.stripeSubscriptionsEnabled && !(
    next.stripeMode === "production" &&
    next.stripeWebhookVerified &&
    next.stripeSubscriptionLifecycleWebhookVerified &&
    next.stripeSubscriptionRecoveryVerified &&
    taxBillingPrepared(next) &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Live Dispatch subscriptions require production mode, verified core and subscription lifecycle webhooks, verified subscription recovery settings, reconciliation readiness, and an authorized GST/HST billing state.",
    );
  }
  if (next.dispatchAffiliateCommissionAccrualEnabled && !(
    next.stripeMode === "production" &&
    next.stripeSubscriptionsEnabled &&
    next.stripeWebhookVerified &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Dispatch affiliate commission accrual requires live Dispatch subscriptions, production mode, verified webhooks, and reconciliation readiness.",
    );
  }
  if (next.marketplaceFinancialResolutionEnabled && !(
    next.stripeMode === "production" &&
    next.stripeWebhookVerified &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Marketplace financial resolution requires production mode, verified webhooks, and reconciliation readiness.",
    );
  }
  if (next.marketplaceDisputeAutomationEnabled &&
      !next.marketplaceFinancialResolutionEnabled) {
    throw new HttpsError(
        "failed-precondition",
        "Dispute automation requires marketplace financial resolution.",
    );
  }
  if (next.marketplaceDisputeEvidenceEnabled &&
      !next.marketplaceDisputeAutomationEnabled) {
    throw new HttpsError(
        "failed-precondition",
        "Dispute evidence submission requires dispute automation.",
    );
  }
  if (next.platformFundedRefundOverrideEnabled &&
      !next.marketplaceFinancialResolutionEnabled) {
    throw new HttpsError(
        "failed-precondition",
        "Platform-funded refund overrides require marketplace financial resolution.",
    );
  }
  if (next.affiliatePayoutsEnabled && !(
    next.stripeMode === "production" &&
    next.stripeConnectOnboardingEnabled &&
    next.stripeWebhookVerified &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Affiliate payouts require production mode, Connect onboarding, verified webhooks, and reconciliation readiness.",
    );
  }
  return next;
}

function applyPatch(current, patch, options = {}) {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
    throw new HttpsError("invalid-argument", "A readiness patch is required.");
  }
  const next = {...normalizeReadiness(current)};
  const allowed = new Set(["stripeMode", ...BOOLEAN_FIELDS, ...URL_FIELDS]);
  for (const key of Object.keys(patch)) {
    if (!allowed.has(key)) {
      throw new HttpsError("invalid-argument", `Unsupported readiness field: ${key}`);
    }
  }
  if (Object.prototype.hasOwnProperty.call(patch, "stripeMode")) {
    next.stripeMode = String(patch.stripeMode || "");
  }
  for (const field of BOOLEAN_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(patch, field)) {
      if (typeof patch[field] !== "boolean") {
        throw new HttpsError("invalid-argument", `${field} must be boolean.`);
      }
      next[field] = patch[field];
    }
  }
  for (const field of URL_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(patch, field)) {
      next[field] = safeHttpsPipeBuyerUrl(patch[field], field);
    }
  }
  return validateReadiness(next, options);
}

function createPaymentReadinessAdmin(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function getPaymentProviderReadiness(request) {
    try {
      requireAdministrator(request);
      const snapshot = await db.collection(CONFIG_COLLECTION).doc(READINESS_DOC).get();
      return normalizeReadiness(snapshot.exists ? snapshot.data() : {});
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      throw error;
    }
  }

  async function setPaymentProviderReadiness(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const reason = String(request.data && request.data.reason || "").trim();
      if (reason.length < 10 || reason.length > 1000) {
        throw new HttpsError(
            "invalid-argument",
            "A concise readiness change reason is required.",
        );
      }
      const ref = db.collection(CONFIG_COLLECTION).doc(READINESS_DOC);
      return await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const current = normalizeReadiness(snapshot.exists ? snapshot.data() : {});
        const next = applyPatch(
            current,
            request.data && request.data.patch,
            {confirmProduction: request.data && request.data.confirmProduction === true},
        );
        let smallSupplierAssessmentRevision = null;
        if (next.canadaGstHstSmallSupplier) {
          const assessmentRef = db.collection(SMALL_SUPPLIER_ASSESSMENT_COLLECTION)
              .doc(SMALL_SUPPLIER_ASSESSMENT_DOC);
          const assessmentSnapshot = await transaction.get(assessmentRef);
          const decision = canadaSmallSupplierAssessmentDecision(
              assessmentSnapshot.exists ? assessmentSnapshot.data() : null,
          );
          if (!decision.authorized) {
            throw new HttpsError(
                "failed-precondition",
                `Canadian small-supplier billing requires a valid audited threshold assessment (${decision.reason}).`,
            );
          }
          smallSupplierAssessmentRevision = decision.revision;
        }
        const revision = Math.max(
            0,
            Number(snapshot.exists && snapshot.data().revision || 0),
        ) + 1;
        transaction.set(ref, {
          ...next,
          revision,
          canadaGstHstSmallSupplierAssessmentRevision:
            smallSupplierAssessmentRevision,
          lastChangedByUid: administratorUid,
          lastChangeReason: reason,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        const auditRef = db.collection("payment_readiness_audit").doc();
        transaction.create(auditRef, {
          administratorUid,
          reason,
          revision,
          previous: current,
          next,
          canadaGstHstSmallSupplierAssessmentRevision:
            smallSupplierAssessmentRevision,
          createdAt: FieldValue.serverTimestamp(),
        });
        return {
          revision,
          readiness: next,
          canadaGstHstSmallSupplierAssessmentRevision:
            smallSupplierAssessmentRevision,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Payment readiness update failed", error);
      throw new HttpsError("internal", "Payment readiness could not be updated.");
    }
  }

  return {
    getPaymentProviderReadiness,
    setPaymentProviderReadiness,
  };
}

module.exports = {
  BOOLEAN_FIELDS,
  CONFIG_COLLECTION,
  READINESS_DOC,
  SMALL_SUPPLIER_ASSESSMENT_COLLECTION,
  SMALL_SUPPLIER_ASSESSMENT_DOC,
  URL_FIELDS,
  applyPatch,
  createPaymentReadinessAdmin,
  normalizeReadiness,
  safeHttpsPipeBuyerUrl,
  taxBillingPrepared,
  validateReadiness,
};
