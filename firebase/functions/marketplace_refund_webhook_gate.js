"use strict";

const {
  adjustedAffiliateCommission,
} = require("./marketplace_financial_resolution");
const {
  financialMutationValues,
} = require("./marketplace_financial_epoch");
const {
  marketplaceTransactionCurrency,
} = require("./marketplace_command_policy");

function refundCurrency(saleCurrency, chargeCurrency) {
  const sale = String(saleCurrency || "").trim() ?
    marketplaceTransactionCurrency(saleCurrency) : null;
  const charge = String(chargeCurrency || "").trim() ?
    marketplaceTransactionCurrency(chargeCurrency) : null;
  if (sale && charge && sale !== charge) {
    throw new TypeError("Marketplace refund currencies do not match.");
  }
  return marketplaceTransactionCurrency(sale || charge);
}

function createMarketplaceRefundWebhookGate(admin, financialResolution) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function automationReady() {
    const snapshot = await db.collection("platform_configuration")
        .doc("payment_provider_readiness")
        .get();
    const data = snapshot.exists ? snapshot.data() : {};
    return data.marketplaceFinancialResolutionEnabled === true &&
      data.stripeWebhookVerified === true &&
      data.stripeReconciliationReady === true &&
      ["sandbox", "production"].includes(String(data.stripeMode || ""));
  }

  async function findMarketplaceTransaction(chargeId) {
    const sale = await db.collection("marketplace_transactions")
        .where("stripeChargeId", "==", chargeId)
        .limit(1)
        .get();
    if (!sale.empty) return {document: sale.docs[0], billingType: "marketplace_sale"};
    const feeOnly = await db.collection("marketplace_transactions")
        .where("stripeMarketplaceFeeChargeId", "==", chargeId)
        .limit(1)
        .get();
    if (feeOnly.empty) return null;
    return {document: feeOnly.docs[0], billingType: "marketplace_fee_only"};
  }

  async function reconcileMarketplaceAffiliateRefund({
    transactionId,
    transactionRef,
    billingType,
    charge,
  }) {
    const ledgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const chargeAmountMinor = Number(charge && charge.amount || 0);
    const incomingRefundedMinor = Math.max(
        0,
        Number(charge && charge.amount_refunded || 0),
    );
    if (!Number.isSafeInteger(chargeAmountMinor) || chargeAmountMinor <= 0 ||
        !Number.isSafeInteger(incomingRefundedMinor) ||
        incomingRefundedMinor <= 0) {
      return null;
    }
    return db.runTransaction(async (transaction) => {
      const saleSnapshot = await transaction.get(transactionRef);
      const ledgerSnapshot = await transaction.get(ledgerRef);
      if (!saleSnapshot.exists) return null;
      const currentSale = saleSnapshot.data();
      const storedRefundedMinor = Math.max(0, Number(
          billingType === "marketplace_fee_only" ?
            currentSale.marketplaceFeeRefundedMinor :
            currentSale.refundedMinor,
      ) || 0);
      const refundedMinor = Math.max(
          storedRefundedMinor,
          incomingRefundedMinor,
      );
      const fullRefund = refundedMinor >= chargeAmountMinor;
      const expectedStatus = fullRefund ? "refunded" : "partially_refunded";
      const currentStatus = String(
          billingType === "marketplace_fee_only" ?
            currentSale.marketplaceFeeStatus :
            currentSale.paymentProviderStatus,
      );
      const saleValues = billingType === "marketplace_fee_only" ? {
        marketplaceFeeStatus: expectedStatus,
        marketplaceFeeRefundedMinor: refundedMinor,
      } : {
        refundedMinor,
        paymentProviderStatus: expectedStatus,
        financialStatus: expectedStatus,
        sellerRecoveryReviewRequired: true,
      };
      const shouldMutateSale = refundedMinor > storedRefundedMinor ||
        currentStatus !== expectedStatus || currentSale.financialHold !== true;
      const salePatch = shouldMutateSale ? {
        ...financialMutationValues(currentSale, saleValues),
        updatedAt: FieldValue.serverTimestamp(),
      } : null;
      const protectedSale = salePatch ?
        {...currentSale, ...salePatch} : currentSale;
      if (!ledgerSnapshot.exists) {
        if (salePatch) {
          transaction.set(transactionRef, salePatch, {merge: true});
        }
        return {
          sale: protectedSale,
          refundedMinor,
          fullRefund,
          financialEpoch: Number(protectedSale.financialEpoch || 0),
        };
      }
      const ledger = ledgerSnapshot.data();
      const commissionMinor = Number(ledger.commissionMinor || 0);
      if (!Number.isSafeInteger(commissionMinor) || commissionMinor <= 0) {
        if (salePatch) {
          transaction.set(transactionRef, salePatch, {merge: true});
        }
        return {
          sale: protectedSale,
          refundedMinor,
          fullRefund,
          financialEpoch: Number(protectedSale.financialEpoch || 0),
        };
      }
      const adjustedMinor = adjustedAffiliateCommission({
        commissionMinor,
        originalChargeAmountMinor: chargeAmountMinor,
        customerExposureMinor: refundedMinor,
      });
      const recoveryMinor = Math.max(0, commissionMinor - adjustedMinor);
      const referrerUid = String(ledger.referrerUid || "").trim();
      const status = String(ledger.status || "");
      const potentiallyEscaped = [
        "paid",
        "payout_dispatching",
        "payout_outcome_unknown",
      ].includes(status) || status === "payout_retry" &&
        ledger.payoutFailureDefinitive !== true;
      const ledgerChanges = {
        adjustedCommissionMinor: adjustedMinor,
        financialExposureMinor: refundedMinor,
        financialRecoveryTargetMinor: recoveryMinor,
        financialAdjustmentReason: "refund",
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!potentiallyEscaped) {
        if (adjustedMinor === 0) {
          ledgerChanges.statusBeforeFinancialAdjustment = status;
          ledgerChanges.status = "void_refunded";
        } else if (["void_refunded", "void_financial_event"].includes(status)) {
          ledgerChanges.status = String(
              ledger.statusBeforeFinancialAdjustment || "pending_refund_window",
          );
        }
        if (salePatch) {
          transaction.set(transactionRef, salePatch, {merge: true});
        }
        transaction.set(ledgerRef, ledgerChanges, {merge: true});
        return {
          sale: protectedSale,
          refundedMinor,
          fullRefund,
          financialEpoch: Number(protectedSale.financialEpoch || 0),
        };
      }
      if (!referrerUid || recoveryMinor <= 0) {
        if (salePatch) {
          transaction.set(transactionRef, salePatch, {merge: true});
        }
        transaction.set(ledgerRef, ledgerChanges, {merge: true});
        return {
          sale: protectedSale,
          refundedMinor,
          fullRefund,
          financialEpoch: Number(protectedSale.financialEpoch || 0),
        };
      }
      const obligationRef = db.collection("affiliate_recovery_obligations")
          .doc(`marketplace_${transactionId}_${referrerUid}`);
      const existing = await transaction.get(obligationRef);
      const openObligations = await transaction.get(
          db.collection("affiliate_recovery_obligations")
              .where("referrerUid", "==", referrerUid)
              .where("status", "==", "open")
              .limit(100),
      );
      const recoveredMinor = Math.max(0, Number(
          existing.exists ? existing.data().recoveredMinor || 0 : 0,
      ));
      const amountDueMinor = Math.max(0, recoveryMinor - recoveredMinor);
      const hasOtherOpen = openObligations.docs.some((document) =>
        document.id !== obligationRef.id,
      );
      transaction.set(obligationRef, {
        type: "marketplace_commission_recovery",
        transactionId,
        ledgerId: ledgerRef.id,
        referrerUid,
        currency: refundCurrency(ledger.currency, currentSale.currency),
        targetRecoveryMinor: recoveryMinor,
        recoveredMinor,
        amountDueMinor,
        reason: "finalized_marketplace_refund",
        status: amountDueMinor > 0 ? "open" : "resolved",
        updatedAt: FieldValue.serverTimestamp(),
        ...(amountDueMinor === 0 ? {
          resolvedAt: FieldValue.serverTimestamp(),
        } : {}),
      }, {merge: true});
      if (salePatch) {
        transaction.set(transactionRef, salePatch, {merge: true});
      }
      transaction.set(ledgerRef, ledgerChanges, {merge: true});
      transaction.set(
          db.collection("payment_provider_accounts").doc(referrerUid),
          {
            affiliatePayoutHold: amountDueMinor > 0 || hasOtherOpen,
            affiliatePayoutHoldReason: amountDueMinor > 0 || hasOtherOpen ?
              "finalized_refund_pending_recovery" : null,
            affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      return {
        sale: protectedSale,
        refundedMinor,
        fullRefund,
        financialEpoch: Number(protectedSale.financialEpoch || 0),
      };
    });
  }

  async function recordRefundForManualRecovery(charge) {
    const chargeId = String(charge && charge.id || "").trim();
    if (!chargeId.startsWith("ch_")) return null;
    const match = await findMarketplaceTransaction(chargeId);
    if (!match) return null;
    const transactionId = match.document.id;
    const transactionRef = match.document.ref;
    const result = await reconcileMarketplaceAffiliateRefund({
      transactionId,
      transactionRef,
      billingType: match.billingType,
      charge,
    });
    if (!result) return null;
    const sale = result.sale;
    const refundedMinor = result.refundedMinor;
    if (match.billingType === "marketplace_fee_only") {
      return {transactionId, billingType: match.billingType, reviewRequired: false};
    }
    if (refundedMinor <= 0) return {transactionId, billingType: match.billingType};
    const caseId = `stripe_refund_review_${chargeId}_${refundedMinor}`;
    await Promise.all([
      db.collection("marketplace_financial_cases").doc(caseId).set({
        type: "stripe_refund_manual_recovery_review",
        transactionId,
        listingId: String(sale.listingId || ""),
        buyerUid: String(sale.buyerUid || ""),
        sellerUid: String(sale.sellerUid || ""),
        currency: refundCurrency(sale.currency, charge.currency),
        stripeChargeId: chargeId,
        refundedMinor,
        status: "seller_recovery_review_required",
        reason: "refund_received_while_financial_automation_disabled",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
      sale.sellerUid ?
        db.collection("payment_provider_accounts").doc(String(sale.sellerUid)).set({
          sellerPayoutHold: true,
          sellerPayoutHoldReason: "manual_refund_recovery_review",
          sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}) : Promise.resolve(),
    ]);
    return {transactionId, billingType: match.billingType, caseId, reviewRequired: true};
  }

  async function reconcileChargeRefund(charge) {
    if (await automationReady()) {
      return financialResolution.reconcileChargeRefund(charge);
    }
    return recordRefundForManualRecovery(charge);
  }

  return {
    handleDisputeEvent: financialResolution.handleDisputeEvent,
    handleRefundStatusEvent: financialResolution.handleRefundStatusEvent,
    reconcileChargeRefund,
    recordRefundForManualRecovery,
    reconcileMarketplaceAffiliateRefund,
  };
}

module.exports = {createMarketplaceRefundWebhookGate};
