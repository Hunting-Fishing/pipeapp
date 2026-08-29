"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

function transactionIdForAuction(listingId) {
  return `auction_${String(listingId || "").trim()}`;
}

function releaseEligible(sale = {}) {
  const completionReached = sale.status === "completed" ||
    sale.auctionSettlementStatus === "completed";
  return completionReached &&
    sale.paymentProvider === "stripe" &&
    sale.paymentProviderStatus === "paid" &&
    sale.sellerPayoutStatus !== "released" &&
    !sale.stripeSellerTransferId &&
    sale.financialHold !== true &&
    String(sale.financialStatus || "") !== "disputed" &&
    String(sale.disputeStatus || "") !== "open" &&
    Number(sale.refundedMinor || 0) === 0;
}

function createMarketplacePaymentLifecycle(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function mirrorAuctionTransaction({listingId, transactionData}) {
    const sale = transactionData || {};
    const buyerUid = String(sale.buyerUid || "").trim();
    const sellerUid = String(sale.sellerUid || "").trim();
    if (!listingId || !buyerUid || !sellerUid) return {created: false};
    const mirrorId = transactionIdForAuction(listingId);
    const mirrorRef = db.collection("marketplace_transactions").doc(mirrorId);
    const existing = await mirrorRef.get();
    if (existing.exists) return {created: false, transactionId: mirrorId};
    const listingSnapshot = await db.collection("public_listings").doc(listingId).get();
    const listing = listingSnapshot.exists ? listingSnapshot.data() : {};
    const agreedQuantity = Math.max(1, Number(sale.agreedQuantity || 1));
    const agreedTotal = Number(sale.agreedTotal || sale.winningBidAmount || 0);
    if (!Number.isFinite(agreedTotal) || agreedTotal <= 0) return {created: false};
    const agreedUnitPrice = Number(sale.agreedUnitPrice || agreedTotal / agreedQuantity);
    await mirrorRef.create({
      listingId,
      listingTitle: String(listing.title || "Timed Buying purchase").slice(0, 240),
      buyerUid,
      sellerUid,
      source: "timed_buying_winner",
      paymentOrigin: "timed_buying",
      auctionTransactionId: listingId,
      status: "pending_payment",
      auctionSettlementStatus: String(sale.status || "pending_completion"),
      buyerConfirmed: sale.buyerConfirmed === true,
      sellerConfirmed: sale.sellerConfirmed === true,
      agreedUnitPrice,
      agreedQuantity,
      agreedTotal,
      currency: String(sale.currency || listing.currency || "CAD").toUpperCase(),
      priceBasis: String(sale.priceBasis || listing.priceBasis || "total"),
      revision: 1,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {created: true, transactionId: mirrorId};
  }

  async function syncAuctionTransaction({listingId, transactionData}) {
    const sale = transactionData || {};
    const mirrorId = transactionIdForAuction(listingId);
    const mirrorRef = db.collection("marketplace_transactions").doc(mirrorId);
    const mirrorSnapshot = await mirrorRef.get();
    if (!mirrorSnapshot.exists) {
      return mirrorAuctionTransaction({listingId, transactionData: sale});
    }
    const mirror = mirrorSnapshot.data();
    const auctionStatus = String(sale.status || "pending_completion");
    const terminalWithoutPayment = new Set([
      "cancelled", "disputed", "buyer_default_reported", "seller_default_reported",
    ]);
    let marketplaceStatus = String(mirror.status || "pending_payment");
    if (terminalWithoutPayment.has(auctionStatus)) marketplaceStatus = auctionStatus;
    else if (mirror.paymentProviderStatus === "paid") marketplaceStatus = auctionStatus;
    else marketplaceStatus = "pending_payment";
    await mirrorRef.set({
      status: marketplaceStatus,
      auctionSettlementStatus: auctionStatus,
      buyerConfirmed: sale.buyerConfirmed === true,
      sellerConfirmed: sale.sellerConfirmed === true,
      ...(String(sale.reason || "").trim() ? {reason: String(sale.reason).slice(0, 2000)} : {}),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {synced: true, transactionId: mirrorId};
  }

  async function releaseSellerFunds({transactionId}) {
    const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
    const snapshot = await transactionRef.get();
    if (!snapshot.exists) return {released: false, reason: "missing"};
    const sale = snapshot.data();
    if (!releaseEligible(sale)) return {released: false, reason: "not_ready"};
    const sellerProvider = await db.collection("payment_provider_accounts")
        .doc(String(sale.sellerUid || "")).get();
    if (!sellerProvider.exists || sellerProvider.data().transferStatus !== "active") {
      await transactionRef.set({
        sellerPayoutStatus: "blocked_seller_not_ready",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {released: false, reason: "seller_not_ready"};
    }
    if (sellerProvider.data().sellerPayoutHold === true) {
      await transactionRef.set({
        sellerPayoutStatus: "blocked_financial_hold",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {released: false, reason: "financial_hold"};
    }
    const destination = String(sellerProvider.data().stripeAccountId || "");
    const chargeId = String(sale.stripeChargeId || "");
    const amount = Number(sale.sellerProceedsMinor || 0);
    if (!destination.startsWith("acct_") || !chargeId.startsWith("ch_") ||
        !Number.isSafeInteger(amount) || amount < 0) {
      throw new Error("Paid marketplace transaction has invalid seller release data.");
    }
    if (amount === 0) {
      await transactionRef.set({
        sellerPayoutStatus: "released",
        financialStatus: "settled",
        sellerReleasedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {released: true, transferId: null};
    }
    const transferGroup = String(sale.stripeTransferGroup || `PB_${transactionId}`).slice(0, 200);
    const transfer = await stripeFormRequest({
      secretKey: stripeSecretKey.value(),
      path: "/v1/transfers",
      idempotencyKey: `pipebuyer-seller-release-${transactionId}`,
      fields: {
        amount,
        currency: String(sale.currency || "CAD").toLowerCase(),
        destination,
        source_transaction: chargeId,
        transfer_group: transferGroup,
        "metadata[pipeBuyerTransactionId]": transactionId,
        "metadata[listingId]": String(sale.listingId || ""),
        "metadata[releaseReason]": "confirmed_physical_goods_completion",
      },
    });
    const transferId = String(transfer.id || "");
    if (!transferId.startsWith("tr_")) {
      throw new Error("Stripe did not return a valid seller transfer.");
    }
    await transactionRef.set({
      stripeSellerTransferId: transferId,
      sellerPayoutStatus: "released",
      financialStatus: "settled",
      sellerReleasedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(sale.paymentOrigin === "timed_buying" &&
          sale.auctionSettlementStatus === "completed" ? {status: "completed"} : {}),
    }, {merge: true});
    return {released: true, transferId};
  }

  return {mirrorAuctionTransaction, syncAuctionTransaction, releaseSellerFunds};
}

module.exports = {createMarketplacePaymentLifecycle, releaseEligible, transactionIdForAuction};
