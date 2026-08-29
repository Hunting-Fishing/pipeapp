"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

function allocateMarketplaceFeeAcrossParts(marketplaceFeeMinor, partAmounts) {
  const fee = Number(marketplaceFeeMinor);
  const amounts = partAmounts.map(Number);
  const total = amounts.reduce((sum, amount) => sum + amount, 0);
  if (!Number.isSafeInteger(fee) || fee < 0 ||
      amounts.length < 2 || amounts.some((amount) =>
        !Number.isSafeInteger(amount) || amount <= 0) ||
      !Number.isSafeInteger(total) || total <= 0 || fee > total) {
    throw new TypeError("Split seller-release amounts are invalid.");
  }
  let allocated = 0;
  return amounts.map((amount, index) => {
    const partFee = index === amounts.length - 1 ?
      fee - allocated : Math.floor(fee * amount / total);
    allocated += partFee;
    if (partFee < 0 || partFee > amount) {
      throw new TypeError("Marketplace fee allocation exceeds a payment part.");
    }
    return partFee;
  });
}

function createMarketplaceSplitSellerRelease(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function releaseSplitSellerFunds({transactionId, sale, destination}) {
    const saleRef = db.collection("marketplace_transactions").doc(transactionId);
    const [depositSnapshot, balanceSnapshot] = await Promise.all([
      saleRef.collection("payment_parts").doc("deposit").get(),
      saleRef.collection("payment_parts").doc("balance").get(),
    ]);
    if (!depositSnapshot.exists || !balanceSnapshot.exists) {
      throw new Error("The split payment ledger is incomplete for seller release.");
    }
    const parts = [depositSnapshot.data(), balanceSnapshot.data()];
    if (parts.some((part) => part.status !== "paid")) {
      return {released: false, reason: "payment_parts_not_paid"};
    }
    const charges = parts.map((part) => String(part.stripeChargeId || ""));
    const amounts = parts.map((part) => Number(part.amountMinor || 0));
    if (charges.some((chargeId) => !chargeId.startsWith("ch_"))) {
      throw new Error("The split payment ledger is missing Stripe charges.");
    }
    const fee = sale.marketplaceFeeSnapshot || {};
    const marketplaceFeeMinor = Number(fee.marketplaceFeeMinor);
    const agreedTotalMinor = Number(fee.agreedTotalMinor);
    if (amounts.reduce((sum, amount) => sum + amount, 0) !== agreedTotalMinor) {
      throw new Error("The split payment ledger no longer matches the sale total.");
    }
    const allocatedFees = allocateMarketplaceFeeAcrossParts(
        marketplaceFeeMinor,
        amounts,
    );
    const transferGroup = String(sale.stripeTransferGroup || `PB_${transactionId}`)
        .slice(0, 200);
    const currency = String(sale.currency || fee.currency || "CAD").toLowerCase();
    const transferRecords = [];
    for (let index = 0; index < parts.length; index += 1) {
      const partId = index === 0 ? "deposit" : "balance";
      const amount = amounts[index] - allocatedFees[index];
      if (amount === 0) {
        transferRecords.push({
          partId,
          sourceChargeId: charges[index],
          amountMinor: 0,
          marketplaceFeeAllocatedMinor: allocatedFees[index],
          transferId: null,
        });
        continue;
      }
      const transfer = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/transfers",
        idempotencyKey: `pipebuyer-seller-release-${transactionId}-${partId}`,
        fields: {
          amount,
          currency,
          destination,
          source_transaction: charges[index],
          transfer_group: transferGroup,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[paymentPartId]": partId,
          "metadata[listingId]": String(sale.listingId || ""),
          "metadata[releaseReason]": "confirmed_physical_goods_completion",
        },
      });
      const transferId = String(transfer.id || "");
      if (!transferId.startsWith("tr_")) {
        throw new Error("Stripe did not return a valid split seller transfer.");
      }
      transferRecords.push({
        partId,
        sourceChargeId: charges[index],
        amountMinor: amount,
        marketplaceFeeAllocatedMinor: allocatedFees[index],
        transferId,
      });
    }
    const sellerReleasedMinor = transferRecords.reduce(
        (sum, record) => sum + record.amountMinor,
        0,
    );
    const expectedSellerProceeds = Number(fee.sellerProceedsBeforeTaxMinor);
    if (!Number.isSafeInteger(expectedSellerProceeds) ||
        sellerReleasedMinor !== expectedSellerProceeds) {
      throw new Error("Split seller transfers do not equal the immutable seller proceeds.");
    }
    await saleRef.set({
      stripeSellerTransfers: transferRecords,
      sellerPayoutStatus: "released",
      financialStatus: "settled",
      sellerReleasedMinor,
      sellerReleasedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(sale.paymentOrigin === "timed_buying" &&
          sale.auctionSettlementStatus === "completed" ? {status: "completed"} : {}),
    }, {merge: true});
    return {released: true, transfers: transferRecords};
  }

  return {releaseSplitSellerFunds};
}

module.exports = {
  allocateMarketplaceFeeAcrossParts,
  createMarketplaceSplitSellerRelease,
};
