"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");

const READINESS_DOC = "payment_provider_readiness";
const CONFIG_COLLECTION = "platform_configuration";
const MODES = new Set(["disabled", "sandbox", "production"]);
const BOOLEAN_FIELDS = Object.freeze([
  "stripeConnectOnboardingEnabled",
  "stripeCheckoutEnabled",
  "stripeFeeBillingEnabled",
  "stripeSubscriptionsEnabled",
  "stripeVipSubscriptionsEnabled",
  "stripeDispatchPortalEnabled",
  "stripeWebhookVerified",
  "stripeTaxReady",
  "stripeTaxRegistrationPending",
  "stripeTaxPendingBillingApproved",
  "marketplaceTaxCollectionDeferredApproved",
  "stripeReconciliationReady",
  "affiliatePayoutEconomicsReady",
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
  "dispatchPortalReturnUrl",
]);
const STRING_FIELDS = Object.freeze([
  "stripeDispatchPortalConfigurationId",
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

function safePortalConfigurationId(value) {
  const configurationId = String(value || "").trim();
  if (configurationId && !/^bpc_[A-Za-z0-9]+$/.test(configurationId)) {
    throw new HttpsError(
        "invalid-argument",
        "stripeDispatchPortalConfigurationId must be a Stripe billing portal configuration ID.",
    );
  }
  return configurationId;
}

function normalizeReadiness(data = {}) {
  const normalized = {
    stripeMode: MODES.has(String(data.stripeMode || "")) ?
      String(data.stripeMode) : "disabled",
  };
  for (const field of BOOLEAN_FIELDS) normalized[field] = data[field] === true;
  for (const field of URL_FIELDS) normalized[field] = String(data[field] || "");
  for (const field of STRING_FIELDS) normalized[field] = String(data[field] || "");
  return normalized;
}

function taxBillingPrepared(next) {
  return next.stripeTaxReady === true ||
    (next.stripeTaxRegistrationPending === true &&
      next.stripeTaxPendingBillingApproved === true);
}

function affiliateProviderReady(next) {
  return next.stripeMode === "production" &&
    next.stripeConnectOnboardingEnabled &&
    next.stripeWebhookVerified &&
    next.stripeReconciliationReady;
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
  if (next.stripeTaxReady && next.marketplaceTaxCollectionDeferredApproved) {
    throw new HttpsError(
        "failed-precondition",
        "Registered automatic tax and deferred marketplace tax collection cannot both be enabled.",
    );
  }
  if (next.stripeTaxReady && next.stripeTaxRegistrationPending) {
    throw new HttpsError(
        "failed-precondition",
        "Tax registration cannot be both pending and ready.",
    );
  }
  if (next.stripeTaxRegistrationPending && next.stripeMode !== "production") {
    throw new HttpsError(
        "failed-precondition",
        "Pending tax registration may only be used with production billing.",
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
    (next.stripeTaxReady || next.marketplaceTaxCollectionDeferredApproved) &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Full marketplace checkout requires production mode, Connect onboarding, verified webhooks, reconciliation readiness, and either registered automatic tax or an audited deferred tax-collection decision.",
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
        "Marketplace fee billing requires production mode, verified webhooks, reconciliation readiness, and either active tax readiness or a separately approved pending-registration billing decision.",
    );
  }
  if (next.stripeSubscriptionsEnabled && !(
    next.stripeMode === "production" &&
    next.stripeWebhookVerified &&
    taxBillingPrepared(next) &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Live Dispatch subscriptions require production mode, verified webhooks, reconciliation readiness, and either active tax readiness or a separately approved pending-registration billing decision.",
    );
  }
  if (next.stripeVipSubscriptionsEnabled && !(
    next.stripeSubscriptionsEnabled &&
    next.stripeMode === "production" &&
    next.stripeWebhookVerified &&
    taxBillingPrepared(next) &&
    next.stripeReconciliationReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Pipe Buyer VIP subscriptions require the verified production subscription billing gate.",
    );
  }
  if (next.stripeDispatchPortalEnabled && !(
    next.stripeMode === "production" &&
    next.stripeWebhookVerified &&
    /^bpc_[A-Za-z0-9]+$/.test(String(next.stripeDispatchPortalConfigurationId || "")) &&
    String(next.dispatchPortalReturnUrl || "").trim()
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Dispatch Customer Portal requires production mode, verified webhooks, an approved Stripe portal configuration, and a Pipe Buyer return URL.",
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
  if (next.affiliatePayoutEconomicsReady && !affiliateProviderReady(next)) {
    throw new HttpsError(
        "failed-precondition",
        "Affiliate payout economics approval requires production mode, Connect onboarding, verified webhooks, and reconciliation readiness.",
    );
  }
  if (next.affiliatePayoutsEnabled && !(
    affiliateProviderReady(next) &&
    next.affiliatePayoutEconomicsReady
  )) {
    throw new HttpsError(
        "failed-precondition",
        "Affiliate payouts require provider readiness and a separate approved affiliate payout economics gate.",
    );
  }
  return next;
}

function applyPatch(current, patch, options = {}) {
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
    throw new HttpsError("invalid-argument", "A readiness patch is required.");
  }
  const next = {...normalizeReadiness(current)};
  const allowed = new Set([
    "stripeMode",
    ...BOOLEAN_FIELDS,
    ...URL_FIELDS,
    ...STRING_FIELDS,
  ]);
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
  for (const field of STRING_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(patch, field)) {
      next[field] = field === "stripeDispatchPortalConfigurationId" ?
        safePortalConfigurationId(patch[field]) : String(patch[field] || "").trim();
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
        const revision = Math.max(0, Number(snapshot.exists && snapshot.data().revision || 0)) + 1;
        transaction.set(ref, {
          ...next,
          revision,
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
          createdAt: FieldValue.serverTimestamp(),
        });
        return {revision, readiness: next};
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
  STRING_FIELDS,
  URL_FIELDS,
  affiliateProviderReady,
  applyPatch,
  createPaymentReadinessAdmin,
  normalizeReadiness,
  safeHttpsPipeBuyerUrl,
  safePortalConfigurationId,
  taxBillingPrepared,
  validateReadiness,
};
