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
    const listingRef = db.collection("public_listings").doc(listingId);
    const classificationRef = db
        .collection("marketplace_fee_classifications").doc(listingId);
    const relationshipRef = db
        .collection("affiliate_relationships").doc(sellerUid);

    return db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      if (!current.exists) return null;
      const currentData = current.data();
      if (currentData.marketplaceFeeSnapshot) {
        return currentData.marketplaceFeeSnapshot;
      }
      if (String(currentData.listingId || "").trim() !== listingId ||
          String(currentData.sellerUid || "").trim() !== sellerUid) {
        console.error("Marketplace monetization transaction identity changed", {
          transactionId,
          listingId,
        });
        return null;
      }
      const listingSnapshot = await firestoreTransaction.get(listingRef);
      const classificationSnapshot =
        await firestoreTransaction.get(classificationRef);
      const relationshipSnapshot =
        await firestoreTransaction.get(relationshipRef);
      if (!listingSnapshot.exists) {
        console.error("Marketplace monetization listing unavailable", {
          transactionId,
          listingId,
        });
        return null;
      }
      const listing = {...listingSnapshot.data(), id: listingId};
      if (String(listing.sellerUid || "").trim() !== sellerUid) {
        console.error("Marketplace monetization seller mismatch", {
          transactionId,
          listingId,
        });
        return null;
      }
      let feeSnapshot;
      try {
        feeSnapshot = calculateMarketplaceFeeSnapshot({
          listing,
          feeClassification: classificationSnapshot.exists ?
            classificationSnapshot.data() : null,
          agreedQuantity: currentData.agreedQuantity,
          agreedTotal: currentData.agreedTotal,
          currency: currentData.currency,
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
        paymentProviderStatus:
          String(currentData.paymentProviderStatus || "").trim() ||
          "not_started",
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
          commissionShareBps: feeSnapshot.affiliateShareBps,
          commissionMinor: feeSnapshot.affiliateCommissionMinor,
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
