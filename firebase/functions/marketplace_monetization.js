"use strict";

const {
  MarketplaceFeePolicyError,
  calculateMarketplaceFeeSnapshot,
} = require("./marketplace_fee_policy");

function createMarketplaceMonetization(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function snapshotAcceptedTransaction({transactionId, transactionData}) {
    if (!transactionId || !transactionData) return null;
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    const listingId = String(transactionData.listingId || "").trim();
    const sellerUid = String(transactionData.sellerUid || "").trim();
    if (!listingId || !sellerUid) {
      console.error("Marketplace monetization snapshot missing required identity", {
        transactionId,
      });
      return null;
    }
    const [listingSnapshot, relationshipSnapshot] = await Promise.all([
      db.collection("public_listings").doc(listingId).get(),
      db.collection("affiliate_relationships").doc(sellerUid).get(),
    ]);
    if (!listingSnapshot.exists) {
      console.error("Marketplace monetization listing unavailable", {
        transactionId,
        listingId,
      });
      return null;
    }

    let feeSnapshot;
    try {
      feeSnapshot = calculateMarketplaceFeeSnapshot({
        listing: listingSnapshot.data(),
        agreedQuantity: transactionData.agreedQuantity,
        agreedTotal: transactionData.agreedTotal,
        currency: transactionData.currency,
      });
    } catch (error) {
      if (error instanceof MarketplaceFeePolicyError) {
        console.error("Marketplace fee snapshot rejected", {
          transactionId,
          code: error.code,
          message: error.message,
        });
        return null;
      }
      throw error;
    }

    const relationship = relationshipSnapshot.exists ?
      relationshipSnapshot.data() : null;
    const referrerUid = String(
        relationship && relationship.referrerUid || "",
    ).trim();
    const affiliateLedgerRef = referrerUid ?
      db.collection("affiliate_commission_ledger")
          .doc(`marketplace_${transactionId}`) :
      null;

    return db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      if (!current.exists) return null;
      const currentData = current.data();
      if (currentData.marketplaceFeeSnapshot) {
        return currentData.marketplaceFeeSnapshot;
      }
      const existingLedger = affiliateLedgerRef ?
        await firestoreTransaction.get(affiliateLedgerRef) :
        null;
      const storedSnapshot = {
        ...feeSnapshot,
        source: "server_fee_policy",
        capturedAt: FieldValue.serverTimestamp(),
      };
      firestoreTransaction.update(transactionRef, {
        marketplaceFeeSnapshot: storedSnapshot,
        marketplaceFeeStatus: "pending_collection",
        paymentProviderStatus: "not_started",
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (
        affiliateLedgerRef &&
        feeSnapshot.affiliateCommissionMinor > 0 &&
        existingLedger &&
        !existingLedger.exists
      ) {
        firestoreTransaction.create(affiliateLedgerRef, {
          type: "marketplace_fee_share",
          transactionId,
          listingId,
          referredUid: sellerUid,
          referrerUid,
          currency: feeSnapshot.currency,
          feeScheduleRevision: feeSnapshot.scheduleRevision,
          platformFeeMinor: feeSnapshot.marketplaceFeeMinor,
          grossPlatformRevenueMinor: feeSnapshot.marketplaceFeeMinor,
          commissionBasis: feeSnapshot.affiliateCommissionBasis,
          commissionShareBps: feeSnapshot.affiliateShareBps,
          commissionMinor: feeSnapshot.affiliateCommissionMinor,
          adjustedCommissionMinor: feeSnapshot.affiliateCommissionMinor,
          commissionProvisional: true,
          status: "pending_platform_fee_payment",
          payoutProvider: "stripe_connect",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return storedSnapshot;
    });
  }

  return {snapshotAcceptedTransaction};
}

module.exports = {createMarketplaceMonetization};
