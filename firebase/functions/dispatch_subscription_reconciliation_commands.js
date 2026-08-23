"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  dispatchSubscriptionInvoiceReconciliationState,
} = require("./dispatch_subscription_reconciliation_policy");
const {
  invoicePaymentIntentId,
  invoicePaymentsPath,
  objectId,
  paidInvoicePayments,
} = require("./dispatch_subscription_invoice_payment_policy");

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

function reconciliationRecord({invoiceId, administratorUid, state}) {
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
    providerPlan: state.providerPlan || null,
    providerStripePriceId: state.providerStripePriceId || null,
    providerCatalogRevision: state.providerCatalogRevision || null,
    providerGrossMinor: state.providerGrossMinor,
    providerFeeMinor: state.providerFeeMinor,
    providerNetMinor: state.providerNetMinor,
    invoiceDifferenceMinor: state.invoiceDifferenceMinor,
    providerDifferenceMinor: state.providerDifferenceMinor,
    zeroAmount: state.zeroAmount,
    stripeInvoicePaymentId: state.stripeInvoicePaymentId || null,
    stripePaymentIntentId: state.stripePaymentIntentId || null,
    stripeChargeId: state.stripeChargeId || null,
    stripeBalanceTransactionId: state.stripeBalanceTransactionId || null,
    reconciliationRevision: "2026-08-23-p2-v3-provider-price-plan",
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
      const [providerInvoice, invoicePaymentList] = await Promise.all([
        stripeRequest({
          secretKey,
          path: `/v1/invoices/${encodeURIComponent(invoiceId)}`,
          method: "GET",
        }),
        stripeRequest({
          secretKey,
          path: invoicePaymentsPath(invoiceId),
          method: "GET",
        }),
      ]);

      if (invoicePaymentList && invoicePaymentList.has_more === true) {
        throw new HttpsError(
            "failed-precondition",
            "This Dispatch invoice has more provider payment records than the automatic-subscription reconciliation model supports. Manual financial review is required.",
        );
      }

      const paidPayments = paidInvoicePayments(invoicePaymentList, invoiceId);
      const providerAmountPaidMinor = Number(providerInvoice.amount_paid);
      const providerPositivePayment = Number.isSafeInteger(providerAmountPaidMinor) &&
        providerAmountPaidMinor > 0;
      if (paidPayments.length > 1) {
        throw new HttpsError(
            "failed-precondition",
            "This Dispatch invoice has multiple paid Stripe InvoicePayment records. Manual financial review is required before reconciliation.",
        );
      }
      if (providerPositivePayment && paidPayments.length !== 1) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe has not exposed the single paid InvoicePayment required to reconcile this Dispatch invoice yet.",
        );
      }

      const invoicePayment = paidPayments[0] || null;
      let paymentIntent = null;
      let charge = null;
      let balanceTransaction = null;

      if (providerPositivePayment) {
        const paymentIntentId = requiredProviderId(
            invoicePaymentIntentId(invoicePayment),
            "pi_",
            "The paid Stripe InvoicePayment is not backed by a PaymentIntent that Pipe Buyer can reconcile.",
        );
        paymentIntent = await stripeRequest({
          secretKey,
          path: `/v1/payment_intents/${encodeURIComponent(paymentIntentId)}`,
          method: "GET",
        });
        const chargeId = requiredProviderId(
            objectId(paymentIntent.latest_charge),
            "ch_",
            "Stripe has not attached a Charge to this paid Dispatch PaymentIntent yet.",
        );
        charge = await stripeRequest({
          secretKey,
          path: `/v1/charges/${encodeURIComponent(chargeId)}`,
          method: "GET",
        });
        const balanceTransactionId = requiredProviderId(
            objectId(charge.balance_transaction),
            "txn_",
            "Stripe has not attached a Balance Transaction to this paid Dispatch Charge yet.",
        );
        balanceTransaction = await stripeRequest({
          secretKey,
          path: `/v1/balance_transactions/${encodeURIComponent(balanceTransactionId)}`,
          method: "GET",
        });
      }

      const state = dispatchSubscriptionInvoiceReconciliationState({
        stored,
        invoice: providerInvoice,
        invoicePayment,
        paymentIntent,
        charge,
        balanceTransaction,
      });
      const record = reconciliationRecord({
        invoiceId,
        administratorUid,
        state,
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
          reconciledProviderPlan: record.providerPlan,
          reconciledStripePriceId: record.providerStripePriceId,
          reconciledProviderCatalogRevision: record.providerCatalogRevision,
          stripeInvoicePaymentId: record.stripeInvoicePaymentId,
          stripePaymentIntentId: record.stripePaymentIntentId,
          sourceChargeId: record.stripeChargeId,
          stripeBalanceTransactionId: record.stripeBalanceTransactionId,
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
