"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");

function cleanId(value, fieldName) {
  const id = String(value || "").trim();
  if (!id || id.length > 180 || id.includes("/")) {
    throw new HttpsError("invalid-argument", `${fieldName} is invalid.`);
  }
  return id;
}

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  const seconds = Number(value.seconds);
  if (Number.isFinite(seconds)) return Math.trunc(seconds * 1000);
  return null;
}

function publicRefundStatus(financialCase) {
  const refundStatus = String(financialCase && financialCase.refundStatus || "");
  const status = String(financialCase && financialCase.status || "");
  if (refundStatus === "succeeded" || status === "completed") return "completed";
  if (refundStatus === "pending" || status === "refund_pending") return "processing";
  if (status === "cancelled") return "cancelled";
  if (status === "requested") return "submitted";
  return "under_review";
}

function participantRefundSummary(caseId, financialCase, uid) {
  if (!financialCase || financialCase.type !== "refund_request") return null;
  return {
    caseId,
    status: publicRefundStatus(financialCase),
    requestedRefundMinor: Math.max(
        0,
        Number(financialCase.requestedRefundMinor || 0),
    ),
    currency: String(financialCase.currency || "CAD").toUpperCase(),
    requestedByMe: String(financialCase.requestedByUid || "") === uid,
    canCancel: String(financialCase.requestedByUid || "") === uid &&
      String(financialCase.status || "") === "requested",
    updatedAtMillis: timestampMillis(financialCase.updatedAt),
    createdAtMillis: timestampMillis(financialCase.createdAt),
  };
}

function administratorFinancialCaseSummary(caseId, financialCase) {
  const type = String(financialCase && financialCase.type || "unknown");
  const summary = {
    caseId,
    type,
    transactionId: String(financialCase && financialCase.transactionId || ""),
    listingId: String(financialCase && financialCase.listingId || ""),
    status: String(financialCase && financialCase.status || "unknown"),
    currency: String(financialCase && financialCase.currency || "CAD").toUpperCase(),
    buyerUid: String(financialCase && financialCase.buyerUid || ""),
    sellerUid: String(financialCase && financialCase.sellerUid || ""),
    updatedAtMillis: timestampMillis(financialCase && financialCase.updatedAt),
    createdAtMillis: timestampMillis(financialCase && financialCase.createdAt),
  };
  if (type === "refund_request") {
    return {
      ...summary,
      requestedByUid: String(financialCase.requestedByUid || ""),
      requestedRefundMinor: Math.max(
          0,
          Number(financialCase.requestedRefundMinor || 0),
      ),
      reason: String(financialCase.reason || "").slice(0, 1600),
      refundStatus: String(financialCase.refundStatus || ""),
      sellerRecoveryOutstandingMinor: Math.max(
          0,
          Number(financialCase.sellerRecoveryOutstandingMinor || 0),
      ),
    };
  }
  if (type === "stripe_dispute") {
    return {
      ...summary,
      disputeAmountMinor: Math.max(
          0,
          Number(financialCase.disputeAmountMinor || 0),
      ),
      disputeReason: String(financialCase.disputeReason || "unknown").slice(0, 240),
      stripeDisputeStatus: String(financialCase.stripeDisputeStatus || "unknown"),
      outcome: String(financialCase.outcome || "open"),
      evidenceDueAtMillis: timestampMillis(financialCase.evidenceDueAt),
    };
  }
  return summary;
}

function isParticipant(transaction, uid) {
  return Boolean(transaction) &&
    [String(transaction.buyerUid || ""), String(transaction.sellerUid || "")]
        .includes(uid);
}

function createMarketplaceFinancialCaseViews(admin) {
  const db = admin.firestore();

  async function getMarketplaceRefundRequestStatus(request) {
    try {
      const uid = requireAuthenticatedIdentity(request, {
        requireEmail: false,
        requirePhone: false,
      }).uid;
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const transactionId = cleanId(
          request.data && request.data.transactionId,
          "transactionId",
      );
      const transactionSnapshot = await db.collection("marketplace_transactions")
          .doc(transactionId).get();
      if (!transactionSnapshot.exists ||
          !isParticipant(transactionSnapshot.data(), uid)) {
        throw new HttpsError(
            "not-found",
            "This marketplace transaction is unavailable.",
        );
      }
      const transaction = transactionSnapshot.data();
      const caseId = String(transaction.activeFinancialCaseId || "").trim();
      if (!caseId || caseId.length > 180 || caseId.includes("/")) {
        return {
          transactionId,
          hasRequest: false,
          financialStatus: String(transaction.financialStatus || ""),
        };
      }
      const caseSnapshot = await db.collection("marketplace_financial_cases")
          .doc(caseId).get();
      if (!caseSnapshot.exists) {
        return {
          transactionId,
          hasRequest: false,
          financialStatus: String(transaction.financialStatus || ""),
        };
      }
      const financialCase = caseSnapshot.data();
      if (String(financialCase.transactionId || "") !== transactionId) {
        throw new HttpsError(
            "failed-precondition",
            "The payment review reference is inconsistent.",
        );
      }
      const summary = participantRefundSummary(caseId, financialCase, uid);
      if (!summary) {
        return {
          transactionId,
          hasRequest: false,
          financialStatus: String(transaction.financialStatus || ""),
        };
      }
      return {
        transactionId,
        hasRequest: true,
        financialStatus: String(transaction.financialStatus || ""),
        request: summary,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace refund status lookup failed", error);
      throw new HttpsError(
          "internal",
          "The payment review status could not be loaded.",
      );
    }
  }

  async function listMarketplaceFinancialCases(request) {
    try {
      requireAdministrator(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "administration",
      });
      const requestedLimit = Number(request.data && request.data.limit || 50);
      const limit = Number.isSafeInteger(requestedLimit) ?
        Math.min(100, Math.max(1, requestedLimit)) : 50;
      const snapshot = await db.collection("marketplace_financial_cases")
          .limit(limit).get();
      const cases = snapshot.docs
          .map((document) => administratorFinancialCaseSummary(
              document.id,
              document.data(),
          ))
          .sort((a, b) =>
            Number(b.updatedAtMillis || b.createdAtMillis || 0) -
            Number(a.updatedAtMillis || a.createdAtMillis || 0));
      return {cases, count: cases.length};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace financial case list failed", error);
      throw new HttpsError(
          "internal",
          "Financial review cases could not be loaded.",
      );
    }
  }

  return {
    getMarketplaceRefundRequestStatus,
    listMarketplaceFinancialCases,
  };
}

module.exports = {
  administratorFinancialCaseSummary,
  createMarketplaceFinancialCaseViews,
  participantRefundSummary,
  publicRefundStatus,
  timestampMillis,
};
