"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");
const {
  externalFeeReconciliationState,
  objectId,
} = require("./external_settlement_reconciliation_policy");

const RECONCILIATION_COLLECTION = "marketplace_fee_reconciliations";
const RECONCILIATION_AUDIT_COLLECTION = "marketplace_fee_reconciliation_audit";

function transactionIdFromRequest(request) {
  const transactionId = String(
      request && request.data && request.data.transactionId || "",
  ).trim();
  if (!transactionId || transactionId.length > 180 || transactionId.includes("/")) {
    throw new HttpsError("invalid-argument", "The marketplace transaction is invalid.");
  }
  return transactionId;
}

function requiredProviderId(value, prefix, message) {
  const id = String(value || "").trim();
  if (!id.startsWith(prefix)) {
    throw new HttpsError("failed-precondition", message);
  }
  return id;
}

function reconciliationRecord({
  transactionId,
  administratorUid,
  state,
  sessionId,
  paymentIntentId,
  chargeId,
  balanceTransactionId,
}) {
  return {
    transactionId,
    administratorUid,
    status: state.balanced ? "balanced" : "mismatch",
    balanced: state.balanced,
    failedChecks: state.failedChecks,
    currency: state.currency,
    expectedFeeMinor: state.expectedFeeMinor,
    expectedTaxMinor: state.expectedTaxMinor,
    expectedTotalMinor: state.expectedTotalMinor,
    providerGrossMinor: state.providerGrossMinor,
    providerFeeMinor: state.providerFeeMinor,
    providerNetMinor: state.providerNetMinor,
    firestoreDifferenceMinor: state.firestoreDifferenceMinor,
    providerDifferenceMinor: state.providerDifferenceMinor,
    stripeCheckoutSessionId: sessionId,
    stripePaymentIntentId: paymentIntentId,
    stripeChargeId: chargeId,
    stripeBalanceTransactionId: balanceTransactionId,
    reconciliationRevision: "2026-08-23-p3-v1",
  };
}

function createExternalSettlementReconciliationCommands(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const stripeRequest = options.stripeRequest || stripeFormRequest;
  const secretKeyProvider = options.secretKeyProvider || (() => stripeSecretKey.value());

  async function reconcileExternalSettlementFee(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const transactionId = transactionIdFromRequest(request);
      const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
      const snapshot = await transactionRef.get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
      }
      const storedSale = snapshot.data() || {};
      if (storedSale.marketplaceFeeStatus !== "collected") {
        throw new HttpsError(
            "failed-precondition",
            "The Pipe Buyer marketplace fee must be collected before reconciliation.",
        );
      }

      const sessionId = requiredProviderId(
          storedSale.stripeMarketplaceFeeSessionId,
          "cs_",
          "The collected fee has no Stripe Checkout Session reference.",
      );
      const paymentIntentId = requiredProviderId(
          storedSale.stripeMarketplaceFeePaymentIntentId,
          "pi_",
          "The collected fee has no Stripe PaymentIntent reference.",
      );
      const chargeId = requiredProviderId(
          storedSale.stripeMarketplaceFeeChargeId,
          "ch_",
          "The collected fee has no Stripe Charge reference.",
      );
      const secretKey = secretKeyProvider();

      const [session, paymentIntent, charge] = await Promise.all([
        stripeRequest({
          secretKey,
          path: `/v1/checkout/sessions/${encodeURIComponent(sessionId)}`,
          method: "GET",
        }),
        stripeRequest({
          secretKey,
          path: `/v1/payment_intents/${encodeURIComponent(paymentIntentId)}`,
          method: "GET",
        }),
        stripeRequest({
          secretKey,
          path: `/v1/charges/${encodeURIComponent(chargeId)}`,
          method: "GET",
        }),
      ]);

      const balanceTransactionId = requiredProviderId(
          objectId(charge.balance_transaction),
          "txn_",
          "Stripe has not attached a Balance Transaction to this paid fee yet.",
      );
      const balanceTransaction = await stripeRequest({
        secretKey,
        path: `/v1/balance_transactions/${encodeURIComponent(balanceTransactionId)}`,
        method: "GET",
      });

      const sale = {...storedSale, transactionId};
      const state = externalFeeReconciliationState({
        sale,
        session,
        paymentIntent,
        charge,
        balanceTransaction,
      });
      const record = reconciliationRecord({
        transactionId,
        administratorUid,
        state,
        sessionId,
        paymentIntentId,
        chargeId,
        balanceTransactionId,
      });
      const timestamp = FieldValue.serverTimestamp();
      const reconciliationRef = db.collection(RECONCILIATION_COLLECTION)
          .doc(transactionId);
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
        transaction.set(transactionRef, {
          marketplaceFeeReconciliationStatus: record.status,
          marketplaceFeeReconciliationFailedChecks: record.failedChecks,
          stripeMarketplaceFeeBalanceTransactionId: balanceTransactionId,
          marketplaceFeeProviderGrossMinor: state.providerGrossMinor,
          marketplaceFeeProviderFeeMinor: state.providerFeeMinor,
          marketplaceFeeProviderNetMinor: state.providerNetMinor,
          marketplaceFeeReconciledAt: timestamp,
          updatedAt: timestamp,
        }, {merge: true});
      });

      return record;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement fee reconciliation failed", error);
      throw new HttpsError(
          "internal",
          "The Pipe Buyer marketplace fee could not be reconciled.",
      );
    }
  }

  return {reconcileExternalSettlementFee};
}

module.exports = {
  RECONCILIATION_AUDIT_COLLECTION,
  RECONCILIATION_COLLECTION,
  createExternalSettlementReconciliationCommands,
  reconciliationRecord,
  requiredProviderId,
  transactionIdFromRequest,
};
