"use strict";

const {
  adjustedAffiliateCommission,
} = require("./marketplace_financial_resolution");

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

  async function holdAffiliateForFinalizedRefund({transactionId, sale, refundedMinor}) {
    const ledgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const ledgerSnapshot = await ledgerRef.get();
    if (!ledgerSnapshot.exists) return;
    const ledger = ledgerSnapshot.data();
    const commissionMinor = Number(ledger.commissionMinor || 0);
    const chargeAmountMinor = Number(sale.buyerChargedMinor || 0);
    if (!Number.isSafeInteger(commissionMinor) || commissionMinor <= 0 ||
        !Number.isSafeInteger(chargeAmountMinor) || chargeAmountMinor <= 0) {
      return;
    }
    const adjustedMinor = adjustedAffiliateCommission({
      commissionMinor,
      originalChargeAmountMinor: chargeAmountMinor,
      customerExposureMinor: refundedMinor,
    });
    const recoveryMinor = Math.max(0, commissionMinor - adjustedMinor);
    const referrerUid = String(ledger.referrerUid || "").trim();
    if (!referrerUid || recoveryMinor <= 0) return;
    const obligationRef = db.collection("affiliate_recovery_obligations")
        .doc(`marketplace_${transactionId}_${referrerUid}`);
    const existing = await obligationRef.get();
    const recoveredMinor = Math.max(0, Number(
        existing.exists ? existing.data().recoveredMinor || 0 : 0,
    ));
    const amountDueMinor = Math.max(0, recoveryMinor - recoveredMinor);
    await Promise.all([
      obligationRef.set({
        type: "marketplace_commission_recovery",
        transactionId,
        ledgerId: ledgerRef.id,
        referrerUid,
        currency: String(ledger.currency || sale.currency || "CAD").toUpperCase(),
        targetRecoveryMinor: recoveryMinor,
        recoveredMinor,
        amountDueMinor,
        reason: "finalized_refund_pending_seller_reconciliation",
        status: amountDueMinor > 0 ? "open" : "resolved",
        updatedAt: FieldValue.serverTimestamp(),
        ...(amountDueMinor === 0 ? {resolvedAt: FieldValue.serverTimestamp()} : {}),
      }, {merge: true}),
      ledgerRef.set({
        adjustedCommissionMinor: adjustedMinor,
        financialExposureMinor: refundedMinor,
        financialAdjustmentReason: "refund",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
      db.collection("payment_provider_accounts").doc(referrerUid).set({
        affiliatePayoutHold: amountDueMinor > 0,
        affiliatePayoutHoldReason: amountDueMinor > 0 ?
          "finalized_refund_pending_recovery" : null,
        affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
    ]);
  }

  async function recordRefundForManualRecovery(charge) {
    const chargeId = String(charge && charge.id || "").trim();
    if (!chargeId.startsWith("ch_")) return null;
    const match = await findMarketplaceTransaction(chargeId);
    if (!match) return null;
    const transactionId = match.document.id;
    const transactionRef = match.document.ref;
    const sale = match.document.data();
    const refundedMinor = Math.max(0, Number(charge.amount_refunded || 0));
    if (match.billingType === "marketplace_fee_only") {
      await transactionRef.set({
        marketplaceFeeStatus: charge.refunded ? "refunded" : "partially_refunded",
        marketplaceFeeRefundedMinor: refundedMinor,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {transactionId, billingType: match.billingType, reviewRequired: false};
    }
    if (refundedMinor <= 0) return {transactionId, billingType: match.billingType};
    const chargeAmount = Math.max(0, Number(charge.amount || sale.buyerChargedMinor || 0));
    const fullRefund = chargeAmount > 0 && refundedMinor >= chargeAmount;
    const caseId = `stripe_refund_review_${chargeId}_${refundedMinor}`;
    await Promise.all([
      transactionRef.set({
        refundedMinor,
        paymentProviderStatus: fullRefund ? "refunded" : "partially_refunded",
        financialStatus: fullRefund ? "refunded" : "partially_refunded",
        financialHold: true,
        sellerRecoveryReviewRequired: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true}),
      db.collection("marketplace_financial_cases").doc(caseId).set({
        type: "stripe_refund_manual_recovery_review",
        transactionId,
        listingId: String(sale.listingId || ""),
        buyerUid: String(sale.buyerUid || ""),
        sellerUid: String(sale.sellerUid || ""),
        currency: String(sale.currency || charge.currency || "CAD").toUpperCase(),
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
      holdAffiliateForFinalizedRefund({transactionId, sale, refundedMinor}),
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
  };
}

module.exports = {createMarketplaceRefundWebhookGate};
