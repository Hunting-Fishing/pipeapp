"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  dispatchSubscriptionInvoiceReconciliationState,
  objectId,
} = require("./dispatch_subscription_reconciliation_policy");
const {sourceChargeFromInvoice} = require("./subscription_monetization");

const INVOICE_COLLECTION = "dispatch_subscription_invoices";
const RECONCILIATION_COLLECTION = "dispatch_subscription_reconciliations";
const RECONCILIATION_AUDIT_COLLECTION =
  "dispatch_subscription_reconciliation_audit";

function invoiceIdFromRequest(request) {
  const invoiceId = String(
      request && request.data && request.data.invoiceId || "",
  ).trim();
  if (!/^in_[A-Za-z0-9_]+$/u.test(invoiceId) || invoiceId.length > 180) {
    throw new HttpsError("invalid-argument", "The Dispatch Stripe invoice is invalid.");
  }
  return invoiceId;
}

function requiredProviderId(value, prefix, message) {
  const id = String(value || "").trim();
  if (!id.startsWith(prefix)) {
    throw new HttpsError("failed-precondition", message);
  }
  return id;
}

function defaultStripeRequest(args) {
  const {stripeFormRequest} = require("./stripe_checkout_commands");
  return stripeFormRequest(args);
}

function defaultSecretKeyProvider() {
  const {stripeSecretKey} = require("./stripe_marketplace_commands");
  return stripeSecretKey.value();
}

function reconciliationRecord({
  invoiceId,
  administratorUid,
  state,
  chargeId,
  balanceTransactionId,
}) {
  return {
    invoiceId,
    administratorUid,
    status: state.balanced ? "balanced" : "mismatch",
    balanced: state.balanced,
    failedChecks: state.failedChecks,
    currency: state.currency,
    expectedAmountPaidMinor: state.expectedAmountPaidMinor,
    expectedCommissionBaseMinor: state.expectedCommissionBaseMinor,
    expectedTaxMinor: state.expectedTaxMinor,
    providerInvoiceTotalMinor: state.providerInvoiceTotalMinor,
    providerInvoiceAmountPaidMinor: state.providerInvoiceAmountPaidMinor,
    providerGrossMinor: state.providerGrossMinor,
    providerFeeMinor: state.providerFeeMinor,
    providerNetMinor: state.providerNetMinor,
    invoiceDifferenceMinor: state.invoiceDifferenceMinor,
    providerDifferenceMinor: state.providerDifferenceMinor,
    zeroAmount: state.zeroAmount,
    stripeChargeId: chargeId || null,
    stripeBalanceTransactionId: balanceTransactionId || null,
    reconciliationRevision: "2026-08-23-p2-v1",
  };
}

function createDispatchSubscriptionReconciliationCommands(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const stripeRequest = options.stripeRequest || defaultStripeRequest;
  const secretKeyProvider = options.secretKeyProvider || defaultSecretKeyProvider;

  async function reconcileDispatchSubscriptionInvoice(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const invoiceId = invoiceIdFromRequest(request);
      const invoiceRef = db.collection(INVOICE_COLLECTION).doc(invoiceId);
      const snapshot = await invoiceRef.get();
      if (!snapshot.exists) {
        throw new HttpsError(
            "not-found",
            "This Dispatch subscription invoice is unavailable.",
        );
      }
      const stored = snapshot.data() || {};
      if (stored.status !== "paid") {
        throw new HttpsError(
            "failed-precondition",
            "The Dispatch subscription invoice must be paid before reconciliation.",
        );
      }
      if (String(stored.invoiceId || "") !== invoiceId) {
        throw new HttpsError(
            "failed-precondition",
            "The stored Dispatch invoice identity needs review before reconciliation.",
        );
      }

      const secretKey = secretKeyProvider();
      const providerInvoice = await stripeRequest({
        secretKey,
        path: `/v1/invoices/${encodeURIComponent(invoiceId)}`,
        method: "GET",
      });

      const providerChargeId = sourceChargeFromInvoice(providerInvoice);
      const storedAmountPaidMinor = Number(stored.amountPaidMinor);
      const positivePayment = Number.isSafeInteger(storedAmountPaidMinor) &&
        storedAmountPaidMinor > 0;
      let charge = null;
      let balanceTransaction = null;
      let balanceTransactionId = "";

      if (providerChargeId) {
        const chargeId = requiredProviderId(
            providerChargeId,
            "ch_",
            "Stripe returned an invalid Charge reference for this Dispatch invoice.",
        );
        charge = await stripeRequest({
          secretKey,
          path: `/v1/charges/${encodeURIComponent(chargeId)}`,
          method: "GET",
        });
        const providerBalanceTransactionId = objectId(charge.balance_transaction);
        if (providerBalanceTransactionId) {
          balanceTransactionId = requiredProviderId(
              providerBalanceTransactionId,
              "txn_",
              "Stripe returned an invalid Balance Transaction reference for this Dispatch invoice.",
          );
          balanceTransaction = await stripeRequest({
            secretKey,
            path: `/v1/balance_transactions/${encodeURIComponent(balanceTransactionId)}`,
            method: "GET",
          });
        } else if (positivePayment) {
          throw new HttpsError(
              "failed-precondition",
              "Stripe has not attached a Balance Transaction to this paid Dispatch invoice yet.",
          );
        }
      } else if (positivePayment) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe has not attached a Charge to this paid Dispatch invoice yet.",
        );
      }

      const state = dispatchSubscriptionInvoiceReconciliationState({
        stored,
        invoice: providerInvoice,
        charge,
        balanceTransaction,
      });
      const record = reconciliationRecord({
        invoiceId,
        administratorUid,
        state,
        chargeId: providerChargeId,
        balanceTransactionId,
      });
      const timestamp = FieldValue.serverTimestamp();
      const reconciliationRef = db.collection(RECONCILIATION_COLLECTION)
          .doc(invoiceId);
      const auditRef = db.collection(RECONCILIATION_AUDIT_COLLECTION).doc();
      const persistedRecord = {
        ...record,
        reconciledAt: timestamp,
        updatedAt: timestamp,
      };

      await db.runTransaction(async (transaction) => {
        transaction.set(reconciliationRef, persistedRecord, {merge: false});
        transaction.create(auditRef, {
          ...persistedRecord,
          createdAt: timestamp,
        });
        transaction.set(invoiceRef, {
          reconciliationStatus: record.status,
          reconciliationFailedChecks: record.failedChecks,
          reconciliationRevision: record.reconciliationRevision,
          stripeBalanceTransactionId: balanceTransactionId || null,
          providerGrossMinor: state.providerGrossMinor,
          providerFeeMinor: state.providerFeeMinor,
          providerNetMinor: state.providerNetMinor,
          reconciledAt: timestamp,
          updatedAt: timestamp,
        }, {merge: true});
      });

      return record;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription invoice reconciliation failed", error);
      throw new HttpsError(
          "internal",
          "The Dispatch subscription invoice could not be reconciled.",
      );
    }
  }

  return {reconcileDispatchSubscriptionInvoice};
}

module.exports = {
  INVOICE_COLLECTION,
  RECONCILIATION_AUDIT_COLLECTION,
  RECONCILIATION_COLLECTION,
  createDispatchSubscriptionReconciliationCommands,
  defaultSecretKeyProvider,
  defaultStripeRequest,
  invoiceIdFromRequest,
  reconciliationRecord,
  requiredProviderId,
};
