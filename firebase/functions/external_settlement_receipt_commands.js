"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

function transactionIdFromRequest(request) {
  const value = String(request.data && request.data.transactionId || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "The transaction is invalid.");
  }
  return value;
}

function validStripeReceiptUrl(value) {
  const normalized = String(value || "").trim();
  if (!normalized) return false;
  try {
    const url = new URL(normalized);
    const host = url.hostname.toLowerCase();
    return url.protocol === "https:" &&
      (host === "stripe.com" || host.endsWith(".stripe.com"));
  } catch (_) {
    return false;
  }
}

function verifiedReceiptAmount(sale, charge) {
  const expectedMinor = Number(sale && sale.marketplaceFeeBuyerChargedMinor);
  const chargedMinor = Number(charge && charge.amount);
  const expectedCurrency = String(
      sale && sale.marketplaceFeeSnapshot &&
      sale.marketplaceFeeSnapshot.currency || sale && sale.currency || "",
  ).trim().toLowerCase();
  const chargedCurrency = String(charge && charge.currency || "")
      .trim().toLowerCase();
  return Number.isSafeInteger(expectedMinor) && expectedMinor > 0 &&
    Number.isSafeInteger(chargedMinor) && chargedMinor === expectedMinor &&
    expectedCurrency.length === 3 && chargedCurrency === expectedCurrency;
}

function createExternalSettlementReceiptCommands(admin) {
  const db = admin.firestore();

  const getExternalSettlementFeeReceipt = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "offers",
      });
      const transactionId = transactionIdFromRequest(request);
      const snapshot = await db.collection("marketplace_transactions")
          .doc(transactionId).get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "This marketplace transaction is unavailable.");
      }
      const sale = snapshot.data();
      if (sale.sellerUid !== identity.uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the seller who paid the Pipe Buyer fee can open its receipt.",
        );
      }
      if (sale.marketplaceFeeStatus !== "collected") {
        throw new HttpsError(
            "failed-precondition",
            "The Pipe Buyer marketplace fee is not recorded as paid yet.",
        );
      }
      const chargeId = String(sale.stripeMarketplaceFeeChargeId || "").trim();
      if (!chargeId.startsWith("ch_")) {
        throw new HttpsError(
            "failed-precondition",
            "The paid marketplace fee does not have a Stripe charge reference yet.",
        );
      }

      const charge = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/charges/${encodeURIComponent(chargeId)}`,
        method: "GET",
      });
      if (String(charge.id || "") !== chargeId || charge.paid !== true) {
        throw new HttpsError(
            "failed-precondition",
            "Stripe has not verified this marketplace fee charge as paid.",
        );
      }
      if (!verifiedReceiptAmount(sale, charge)) {
        throw new HttpsError(
            "failed-precondition",
            "The Stripe charge does not match the recorded Pipe Buyer fee total.",
        );
      }

      const receiptUrl = String(charge.receipt_url || "").trim();
      return {
        transactionId,
        chargeId,
        amountMinor: Number(charge.amount),
        currency: String(charge.currency || "").toUpperCase(),
        receiptUrl: validStripeReceiptUrl(receiptUrl) ? receiptUrl : "",
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("External settlement fee receipt lookup failed", error);
      throw new HttpsError(
          "internal",
          "The Pipe Buyer marketplace fee receipt could not be loaded.",
      );
    }
  };

  return {getExternalSettlementFeeReceipt};
}

module.exports = {
  createExternalSettlementReceiptCommands,
  validStripeReceiptUrl,
  verifiedReceiptAmount,
};
