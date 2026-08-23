"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");

const INVOICE_COLLECTION = "dispatch_subscription_invoices";
const MAX_ADMIN_INVOICES = 50;

function safeInteger(value) {
  const number = Number(value);
  return Number.isSafeInteger(number) ? number : 0;
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  return 0;
}

function dispatchInvoiceAdminSummary(data = {}, id = "") {
  return Object.freeze({
    invoiceId: String(data.invoiceId || id || ""),
    uid: String(data.uid || ""),
    plan: String(data.plan || ""),
    currency: String(data.currency || "CAD").toUpperCase(),
    amountPaidMinor: safeInteger(data.amountPaidMinor),
    commissionBaseMinor: safeInteger(data.commissionBaseMinor),
    taxMinor: safeInteger(data.taxMinor),
    taxCollectionStatus: String(data.taxCollectionStatus || ""),
    affiliateCommissionAccrualStatus:
      String(data.affiliateCommissionAccrualStatus || ""),
    affiliateCommissionMinor: safeInteger(data.affiliateCommissionMinor),
    status: String(data.status || ""),
    reconciliationStatus: String(data.reconciliationStatus || "not_reconciled"),
    reconciliationFailedChecks: Array.isArray(data.reconciliationFailedChecks) ?
      data.reconciliationFailedChecks.map(String).slice(0, 40) : [],
    providerGrossMinor: safeInteger(data.providerGrossMinor),
    providerFeeMinor: safeInteger(data.providerFeeMinor),
    providerNetMinor: safeInteger(data.providerNetMinor),
    stripeBalanceTransactionId: String(data.stripeBalanceTransactionId || ""),
    paidAtMillis: timestampMillis(data.paidAt),
  });
}

function createDispatchSubscriptionAdminCommands(admin) {
  const db = admin.firestore();

  async function getDispatchSubscriptionReconciliationQueue(request) {
    try {
      requireAdministrator(request);
      const snapshot = await db.collection(INVOICE_COLLECTION)
          .orderBy("paidAt", "desc")
          .limit(MAX_ADMIN_INVOICES)
          .get();
      return {
        invoices: snapshot.docs.map((document) =>
          dispatchInvoiceAdminSummary(document.data(), document.id)),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription admin queue failed", error);
      throw new HttpsError(
          "internal",
          "The Dispatch subscription reconciliation queue could not be loaded.",
      );
    }
  }

  return {getDispatchSubscriptionReconciliationQueue};
}

module.exports = {
  INVOICE_COLLECTION,
  MAX_ADMIN_INVOICES,
  createDispatchSubscriptionAdminCommands,
  dispatchInvoiceAdminSummary,
  safeInteger,
  timestampMillis,
};
