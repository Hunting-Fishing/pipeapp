"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  isStripeDisputeId,
  isStripeFileId,
  stripeFinancialRequest,
} = require("./marketplace_stripe_financial_api");

const TEXT_EVIDENCE_FIELDS = new Set([
  "billing_address",
  "customer_email_address",
  "customer_name",
  "customer_purchase_ip",
  "duplicate_charge_explanation",
  "duplicate_charge_id",
  "product_description",
  "refund_policy_disclosure",
  "refund_refusal_explanation",
  "service_date",
  "shipping_address",
  "shipping_carrier",
  "shipping_date",
  "shipping_tracking_number",
  "uncategorized_text",
]);

const FILE_EVIDENCE_FIELDS = new Set([
  "customer_communication",
  "customer_signature",
  "duplicate_charge_documentation",
  "receipt",
  "refund_policy",
  "service_documentation",
  "shipping_documentation",
  "uncategorized_file",
]);

const MAX_FIELD_CHARACTERS = 20000;
const MAX_TOTAL_TEXT_CHARACTERS = 120000;

function cleanCaseId(value) {
  const id = String(value || "").trim();
  if (!id || id.length > 180 || id.includes("/")) {
    throw new HttpsError("invalid-argument", "The financial case ID is invalid.");
  }
  return id;
}

function normalizeEvidence(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpsError("invalid-argument", "Evidence must be an object.");
  }
  const evidence = {};
  let totalText = 0;
  for (const [field, raw] of Object.entries(input)) {
    if (TEXT_EVIDENCE_FIELDS.has(field)) {
      const value = String(raw == null ? "" : raw).trim();
      if (!value || value.length > MAX_FIELD_CHARACTERS) {
        throw new HttpsError(
            "invalid-argument",
            `Evidence field ${field} is empty or too long.`,
        );
      }
      totalText += value.length;
      evidence[field] = value;
      continue;
    }
    if (FILE_EVIDENCE_FIELDS.has(field)) {
      const value = String(raw || "").trim();
      if (!isStripeFileId(value)) {
        throw new HttpsError(
            "invalid-argument",
            `Evidence field ${field} must use a Stripe dispute-evidence file ID.`,
        );
      }
      evidence[field] = value;
      continue;
    }
    throw new HttpsError(
        "invalid-argument",
        `Evidence field ${field} is not approved for Pipe Buyer dispute submissions.`,
    );
  }
  if (Object.keys(evidence).length === 0) {
    throw new HttpsError("invalid-argument", "At least one evidence field is required.");
  }
  if (totalText > MAX_TOTAL_TEXT_CHARACTERS) {
    throw new HttpsError(
        "invalid-argument",
        "The combined dispute evidence text is too long.",
    );
  }
  return evidence;
}

function evidenceHash(evidence) {
  return crypto.createHash("sha256")
      .update(JSON.stringify(Object.keys(evidence).sort().map((key) => [key, evidence[key]])))
      .digest("hex");
}

function createStripeDisputeResponse(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function requireEnabled() {
    const snapshot = await db.collection("platform_configuration")
        .doc("payment_provider_readiness").get();
    const data = snapshot.exists ? snapshot.data() : {};
    if (data.marketplaceDisputeEvidenceEnabled !== true ||
        data.stripeWebhookVerified !== true ||
        !["sandbox", "production"].includes(String(data.stripeMode || ""))) {
      throw new HttpsError(
          "failed-precondition",
          "Programmatic dispute evidence is not enabled yet.",
      );
    }
  }

  async function loadDisputeCase(caseId) {
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const snapshot = await caseRef.get();
    if (!snapshot.exists || snapshot.data().type !== "stripe_dispute") {
      throw new HttpsError("not-found", "The Stripe dispute case was not found.");
    }
    const financialCase = snapshot.data();
    const disputeId = String(financialCase.stripeDisputeId || "");
    if (!isStripeDisputeId(disputeId)) {
      throw new HttpsError("failed-precondition", "The Stripe dispute ID is invalid.");
    }
    return {caseRef, financialCase, disputeId};
  }

  async function retrieveOpenDispute(disputeId) {
    const dispute = await stripeFinancialRequest({
      secretKey: stripeSecretKey.value(),
      path: `/v1/disputes/${encodeURIComponent(disputeId)}`,
      method: "GET",
    });
    const status = String(dispute.status || "");
    const details = dispute.evidence_details || {};
    if (["won", "lost", "warning_closed"].includes(status)) {
      throw new HttpsError("failed-precondition", "This dispute is already closed.");
    }
    if (details.past_due === true) {
      throw new HttpsError(
          "failed-precondition",
          "Stripe's evidence submission deadline has passed.",
      );
    }
    return dispute;
  }

  async function stageMarketplaceDisputeEvidence(request) {
    let administratorUid = null;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({db, admin, request, scope: "administration"});
      await requireEnabled();
      const caseId = cleanCaseId(request.data && request.data.caseId);
      const evidence = normalizeEvidence(request.data && request.data.evidence);
      const {caseRef, financialCase, disputeId} = await loadDisputeCase(caseId);
      if (financialCase.finalEvidenceSubmittedAt) {
        throw new HttpsError(
            "failed-precondition",
            "Final evidence was already submitted for this dispute.",
        );
      }
      await retrieveOpenDispute(disputeId);
      const fields = {submit: "false"};
      for (const [field, value] of Object.entries(evidence)) {
        fields[`evidence[${field}]`] = value;
      }
      fields["metadata[pipeBuyerFinancialCaseId]"] = caseId;
      fields["metadata[pipeBuyerTransactionId]"] =
        String(financialCase.transactionId || "");
      const dispute = await stripeFinancialRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/disputes/${encodeURIComponent(disputeId)}`,
        fields,
      });
      const hash = evidenceHash(evidence);
      await caseRef.set({
        evidenceStatus: "staged",
        stagedEvidenceHash: hash,
        stagedEvidenceFields: Object.keys(evidence).sort(),
        stagedByUid: administratorUid,
        stagedAt: FieldValue.serverTimestamp(),
        stripeEvidenceSubmissionCount: Math.max(0, Number(
            dispute.evidence_details && dispute.evidence_details.submission_count || 0,
        )),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        caseId,
        disputeId,
        evidenceStatus: "staged",
        evidenceHash: hash,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe dispute evidence staging failed", {
        administratorUid,
        stripeCode: error && error.stripeCode || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "Stripe dispute evidence could not be staged.",
      );
    }
  }

  async function submitMarketplaceDisputeEvidence(request) {
    let administratorUid = null;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({db, admin, request, scope: "administration"});
      await requireEnabled();
      if (!request.data || request.data.confirmFinalSubmission !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Final dispute evidence submission requires explicit confirmation.",
        );
      }
      const caseId = cleanCaseId(request.data.caseId);
      const {caseRef, financialCase, disputeId} = await loadDisputeCase(caseId);
      if (!financialCase.stagedEvidenceHash) {
        throw new HttpsError(
            "failed-precondition",
            "Stage and review the evidence before final submission.",
        );
      }
      if (financialCase.finalEvidenceSubmittedAt) {
        return {
          caseId,
          disputeId,
          evidenceStatus: "submitted",
          alreadySubmitted: true,
        };
      }
      const before = await retrieveOpenDispute(disputeId);
      const submissionCount = Math.max(0, Number(
          before.evidence_details && before.evidence_details.submission_count || 0,
      ));
      if (submissionCount > 0) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe already records a final evidence submission for this dispute.",
        );
      }
      const dispute = await stripeFinancialRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/disputes/${encodeURIComponent(disputeId)}`,
        idempotencyKey: `pipebuyer-dispute-submit-${caseId}`,
        fields: {
          submit: "true",
          "metadata[pipeBuyerFinancialCaseId]": caseId,
          "metadata[pipeBuyerFinalEvidenceByUid]": administratorUid,
        },
      });
      await caseRef.set({
        evidenceStatus: "submitted",
        finalEvidenceSubmittedByUid: administratorUid,
        finalEvidenceSubmittedAt: FieldValue.serverTimestamp(),
        stripeEvidenceSubmissionCount: Math.max(0, Number(
            dispute.evidence_details && dispute.evidence_details.submission_count || 0,
        )),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        caseId,
        disputeId,
        evidenceStatus: "submitted",
        alreadySubmitted: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe final dispute evidence submission failed", {
        administratorUid,
        stripeCode: error && error.stripeCode || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "Final dispute evidence could not be submitted.",
      );
    }
  }

  async function acceptMarketplaceDispute(request) {
    let administratorUid = null;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({db, admin, request, scope: "administration"});
      await requireEnabled();
      if (!request.data || request.data.confirmIrreversibleLoss !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Accepting a dispute as lost requires explicit irreversible confirmation.",
        );
      }
      const caseId = cleanCaseId(request.data.caseId);
      const {caseRef, disputeId} = await loadDisputeCase(caseId);
      await retrieveOpenDispute(disputeId);
      const dispute = await stripeFinancialRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/disputes/${encodeURIComponent(disputeId)}/close`,
        idempotencyKey: `pipebuyer-dispute-accept-${caseId}`,
        fields: {},
      });
      await caseRef.set({
        evidenceStatus: "accepted_loss",
        acceptedLossByUid: administratorUid,
        acceptedLossAt: FieldValue.serverTimestamp(),
        stripeDisputeStatus: String(dispute.status || "lost"),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        caseId,
        disputeId,
        status: String(dispute.status || "lost"),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Accept Stripe dispute failed", {
        administratorUid,
        stripeCode: error && error.stripeCode || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "The Stripe dispute could not be accepted as lost.",
      );
    }
  }

  return {
    acceptMarketplaceDispute,
    stageMarketplaceDisputeEvidence,
    submitMarketplaceDisputeEvidence,
  };
}

module.exports = {
  FILE_EVIDENCE_FIELDS,
  MAX_FIELD_CHARACTERS,
  MAX_TOTAL_TEXT_CHARACTERS,
  TEXT_EVIDENCE_FIELDS,
  createStripeDisputeResponse,
  evidenceHash,
  normalizeEvidence,
};
