"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  isStripeTransferId,
  stripeFinancialRequest,
} = require("./marketplace_stripe_financial_api");

function proportionalRecoveryTarget({
  transferAmountMinor,
  originalChargeAmountMinor,
  customerExposureMinor,
}) {
  const transfer = Number(transferAmountMinor);
  const charge = Number(originalChargeAmountMinor);
  const exposure = Number(customerExposureMinor);
  if (!Number.isSafeInteger(transfer) || transfer < 0 ||
      !Number.isSafeInteger(charge) || charge <= 0 ||
      !Number.isSafeInteger(exposure) || exposure < 0) {
    throw new TypeError("Financial recovery amounts must use valid minor units.");
  }
  if (exposure >= charge) return transfer;
  return Math.floor(transfer * exposure / charge);
}

function uniqueSellerTransferIds(sale) {
  const values = [
    String(sale && sale.stripeSellerTransferId || ""),
    ...(Array.isArray(sale && sale.sellerPayoutTransferIds) ?
      sale.sellerPayoutTransferIds.map((value) => String(value || "")) : []),
  ];
  return [...new Set(values.filter(isStripeTransferId))];
}

function originalSellerProceedsMinor(sale) {
  const explicit = Number(sale && sale.originalSellerProceedsMinor);
  if (Number.isSafeInteger(explicit) && explicit >= 0) return explicit;
  const settled = Number(sale && sale.sellerProceedsMinor);
  if (Number.isSafeInteger(settled) && settled >= 0) return settled;
  const snapshot = Number(
      sale && sale.marketplaceFeeSnapshot &&
      sale.marketplaceFeeSnapshot.sellerProceedsBeforeTaxMinor,
  );
  return Number.isSafeInteger(snapshot) && snapshot >= 0 ? snapshot : 0;
}

function desiredSellerNetMinor({sale, customerExposureMinor}) {
  const sellerProceeds = originalSellerProceedsMinor(sale);
  const chargeAmount = Number(sale && sale.buyerChargedMinor || 0);
  if (!Number.isSafeInteger(chargeAmount) || chargeAmount <= 0) {
    throw new TypeError("The original buyer charge amount is unavailable.");
  }
  const recovery = proportionalRecoveryTarget({
    transferAmountMinor: sellerProceeds,
    originalChargeAmountMinor: chargeAmount,
    customerExposureMinor: Math.max(0, Number(customerExposureMinor || 0)),
  });
  return Math.max(0, sellerProceeds - recovery);
}

function createMarketplaceSellerFunds(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function retrieveTransfers(sale) {
    const ids = uniqueSellerTransferIds(sale);
    const transfers = [];
    for (const id of ids) {
      const transfer = await stripeFinancialRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/transfers/${encodeURIComponent(id)}`,
        method: "GET",
      });
      transfers.push({
        id,
        amountMinor: Math.max(0, Number(transfer.amount || 0)),
        reversedMinor: Math.max(0, Number(transfer.amount_reversed || 0)),
        raw: transfer,
      });
    }
    return transfers;
  }

  function netSellerTransferredMinor(transfers) {
    return transfers.reduce((total, transfer) =>
      total + Math.max(0, transfer.amountMinor - transfer.reversedMinor), 0);
  }

  async function sellerDestination(sale) {
    const sellerUid = String(sale && sale.sellerUid || "").trim();
    if (!sellerUid) return null;
    const snapshot = await db.collection("payment_provider_accounts")
        .doc(sellerUid).get();
    if (!snapshot.exists) return null;
    const data = snapshot.data();
    const accountId = String(data.stripeAccountId || "");
    if (data.transferStatus !== "active" || !accountId.startsWith("acct_")) {
      return null;
    }
    return {sellerUid, accountId, providerRef: snapshot.ref, provider: data};
  }

  async function setSellerRecoveryState({
    transactionId,
    sale,
    caseId,
    outstandingRecoveryMinor,
    outstandingRestorationMinor,
    desiredNetMinor,
    actualNetMinor,
    reason,
  }) {
    const sellerUid = String(sale && sale.sellerUid || "");
    const obligationRef = db.collection("marketplace_seller_recovery_obligations")
        .doc(caseId);
    const recoveryDue = Math.max(0, Number(outstandingRecoveryMinor || 0));
    const restorationDue = Math.max(0, Number(outstandingRestorationMinor || 0));
    await obligationRef.set({
      transactionId,
      caseId,
      sellerUid,
      buyerUid: String(sale && sale.buyerUid || ""),
      currency: String(sale && sale.currency || "CAD").toUpperCase(),
      desiredSellerNetMinor: desiredNetMinor,
      actualSellerNetMinor: actualNetMinor,
      amountDueMinor: recoveryDue,
      restorationDueMinor: restorationDue,
      reason,
      status: recoveryDue > 0 ? "open" :
        restorationDue > 0 ? "seller_restoration_pending" : "resolved",
      updatedAt: FieldValue.serverTimestamp(),
      ...(recoveryDue === 0 && restorationDue === 0 ? {
        resolvedAt: FieldValue.serverTimestamp(),
      } : {}),
    }, {merge: true});
    if (sellerUid) {
      const openOther = await db.collection("marketplace_seller_recovery_obligations")
          .where("sellerUid", "==", sellerUid)
          .where("status", "==", "open")
          .limit(2)
          .get();
      const hasOpenRecovery = recoveryDue > 0 || openOther.docs.some(
          (document) => document.id !== caseId,
      );
      await db.collection("payment_provider_accounts").doc(sellerUid).set({
        sellerPayoutHold: hasOpenRecovery,
        sellerPayoutHoldReason: hasOpenRecovery ? reason : null,
        sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }

  async function rebalanceSellerFunds({
    transactionId,
    sale,
    caseId,
    customerExposureMinor,
    reason,
    allowRestoration = false,
  }) {
    const originalProceeds = originalSellerProceedsMinor(sale);
    const desiredNet = desiredSellerNetMinor({sale, customerExposureMinor});
    const transfers = await retrieveTransfers(sale);
    let actualNet = netSellerTransferredMinor(transfers);
    const reversalIds = [];
    const failures = [];

    if (actualNet > desiredNet) {
      let remaining = actualNet - desiredNet;
      const candidates = [...transfers].reverse();
      for (const transfer of candidates) {
        if (remaining <= 0) break;
        const reversible = Math.max(
            0,
            transfer.amountMinor - transfer.reversedMinor,
        );
        if (reversible <= 0) continue;
        const amount = Math.min(remaining, reversible);
        try {
          const reversal = await stripeFinancialRequest({
            secretKey: stripeSecretKey.value(),
            path: `/v1/transfers/${encodeURIComponent(transfer.id)}/reversals`,
            idempotencyKey:
              `pipebuyer-seller-recovery-${caseId}-${transfer.id}-${desiredNet}`,
            fields: {
              amount,
              "metadata[pipeBuyerTransactionId]": transactionId,
              "metadata[pipeBuyerFinancialCaseId]": caseId,
              "metadata[reason]": String(reason || "financial_recovery").slice(0, 200),
            },
          });
          reversalIds.push(String(reversal.id || ""));
          remaining -= amount;
          actualNet -= amount;
        } catch (error) {
          failures.push({
            transferId: transfer.id,
            amountMinor: amount,
            stripeCode: String(error.stripeCode || "provider_error"),
          });
        }
      }
    }

    let restorationTransferId = null;
    let restorationMinor = 0;
    if (allowRestoration && actualNet < desiredNet) {
      const destination = await sellerDestination(sale);
      const amount = desiredNet - actualNet;
      if (destination && amount > 0) {
        try {
          const transfer = await stripeFinancialRequest({
            secretKey: stripeSecretKey.value(),
            path: "/v1/transfers",
            idempotencyKey:
              `pipebuyer-seller-restoration-${caseId}-${desiredNet}`,
            fields: {
              amount,
              currency: String(sale.currency || "CAD").toLowerCase(),
              destination: destination.accountId,
              transfer_group: String(
                  sale.stripeTransferGroup || `PB_${transactionId}`,
              ).slice(0, 200),
              "metadata[pipeBuyerTransactionId]": transactionId,
              "metadata[pipeBuyerFinancialCaseId]": caseId,
              "metadata[type]": "seller_financial_restoration",
            },
          });
          restorationTransferId = String(transfer.id || "");
          restorationMinor = amount;
          actualNet += amount;
          if (restorationTransferId) {
            await db.collection("marketplace_transactions")
                .doc(transactionId).set({
                  sellerPayoutTransferIds:
                    FieldValue.arrayUnion(restorationTransferId),
                  updatedAt: FieldValue.serverTimestamp(),
                }, {merge: true});
          }
        } catch (error) {
          failures.push({
            transferId: null,
            amountMinor: amount,
            operation: "restoration",
            stripeCode: String(error.stripeCode || "provider_error"),
          });
        }
      }
    }

    const outstandingRecovery = Math.max(0, actualNet - desiredNet);
    const outstandingRestoration = Math.max(0, desiredNet - actualNet);
    await setSellerRecoveryState({
      transactionId,
      sale,
      caseId,
      outstandingRecoveryMinor: outstandingRecovery,
      outstandingRestorationMinor: outstandingRestoration,
      desiredNetMinor: desiredNet,
      actualNetMinor: actualNet,
      reason,
    });
    await db.collection("marketplace_transactions").doc(transactionId).set({
      originalSellerProceedsMinor: originalProceeds,
      sellerNetTransferredMinor: actualNet,
      sellerDesiredNetMinor: desiredNet,
      sellerRecoveryOutstandingMinor: outstandingRecovery,
      sellerRestorationOutstandingMinor: outstandingRestoration,
      financialHold: outstandingRecovery > 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    return {
      desiredNetMinor: desiredNet,
      actualNetMinor: actualNet,
      outstandingRecoveryMinor: outstandingRecovery,
      outstandingRestorationMinor: outstandingRestoration,
      reversalIds,
      restorationTransferId,
      restorationMinor,
      failures,
    };
  }

  return {
    rebalanceSellerFunds,
    retrieveTransfers,
    sellerDestination,
  };
}

module.exports = {
  createMarketplaceSellerFunds,
  desiredSellerNetMinor,
  netSellerTransferredMinor: (transfers) => transfers.reduce((total, transfer) =>
    total + Math.max(0,
        Number(transfer.amountMinor || 0) - Number(transfer.reversedMinor || 0)), 0),
  originalSellerProceedsMinor,
  proportionalRecoveryTarget,
  uniqueSellerTransferIds,
};
