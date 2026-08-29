"use strict";

const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {stripeSecretKey} = require("./stripe_marketplace_commands");

const AFFILIATE_REFUND_WINDOW_DAYS = 30;
const PAYMENT_PARTS = new Set(["deposit", "balance"]);

function billingType(session) {
  return String(session && session.metadata && session.metadata.billingType || "").trim();
}

function paymentPartIdentity(session) {
  if (billingType(session) !== "marketplace_payment_part") return null;
  const transactionId = String(
      session && session.metadata && session.metadata.pipeBuyerTransactionId || "",
  ).trim();
  const partId = String(
      session && session.metadata && session.metadata.paymentPartId || "",
  ).trim().toLowerCase();
  if (!transactionId || transactionId.length > 180 || transactionId.includes("/") ||
      !PAYMENT_PARTS.has(partId)) return null;
  return {transactionId, partId};
}

async function retrievePaymentIntent(paymentIntentId) {
  const response = await fetch(
      `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(paymentIntentId)}` +
      "?expand[]=latest_charge",
      {
        headers: {
          Authorization: `Bearer ${stripeSecretKey.value()}`,
          "Stripe-Version": stripeMarketplaceConfig.apiVersion,
        },
      },
  );
  const payload = await response.json();
  if (!response.ok) throw new Error("Stripe payment intent retrieval failed.");
  return payload;
}

function createMarketplacePaymentPartSettlement(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  function affiliateEligibleAfter() {
    return Timestamp.fromMillis(
        Date.now() + AFFILIATE_REFUND_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
  }

  async function markPaymentPartFailure(session) {
    const identity = paymentPartIdentity(session);
    if (!identity) return false;
    const saleRef = db.collection("marketplace_transactions").doc(identity.transactionId);
    const partRef = saleRef.collection("payment_parts").doc(identity.partId);
    await partRef.set({
      status: "payment_failed",
      stripeCheckoutSessionId: String(session.id || ""),
      paymentFailedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (identity.partId === "deposit") {
      await saleRef.set({
        paymentProviderStatus: "pending_payment",
        financialStatus: "awaiting_payment",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  }

  async function markPaymentPartProcessing(session) {
    const identity = paymentPartIdentity(session);
    if (!identity) return false;
    const saleRef = db.collection("marketplace_transactions").doc(identity.transactionId);
    await saleRef.collection("payment_parts").doc(identity.partId).set({
      status: "processing",
      stripeCheckoutSessionId: String(session.id || ""),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (identity.partId === "deposit") {
      await saleRef.set({
        paymentProviderStatus: "processing",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  }

  async function settleSuccessfulPaymentPart(session) {
    const identity = paymentPartIdentity(session);
    if (!identity) return false;
    const saleRef = db.collection("marketplace_transactions").doc(identity.transactionId);
    const partRef = saleRef.collection("payment_parts").doc(identity.partId);
    const [saleSnapshot, partSnapshot] = await Promise.all([
      saleRef.get(),
      partRef.get(),
    ]);
    if (!saleSnapshot.exists || !partSnapshot.exists) {
      throw new Error("Pipe Buyer split-payment transaction was not found.");
    }
    const sale = saleSnapshot.data();
    const part = partSnapshot.data();
    if (sale.paymentPlan !== "deposit_balance" || sale.paymentPlanStatus !== "active") {
      throw new Error("Stripe split payment does not match an active payment plan.");
    }
    if (part.status === "paid") return true;
    const expectedAmount = Number(part.amountMinor);
    const subtotalMinor = Number(session.amount_subtotal || 0);
    if (!Number.isSafeInteger(expectedAmount) || expectedAmount <= 0 ||
        subtotalMinor !== expectedAmount) {
      throw new Error("Stripe split payment does not match the immutable payment part.");
    }
    const paymentIntentId = typeof session.payment_intent === "string" ?
      session.payment_intent :
      String(session.payment_intent && session.payment_intent.id || "");
    if (!paymentIntentId.startsWith("pi_")) {
      throw new Error("The split payment has no Stripe payment intent.");
    }
    const paymentIntent = await retrievePaymentIntent(paymentIntentId);
    if (paymentIntent.status !== "succeeded") return true;
    const latestCharge = paymentIntent.latest_charge;
    const chargeId = typeof latestCharge === "string" ?
      latestCharge : String(latestCharge && latestCharge.id || "");
    if (!chargeId.startsWith("ch_")) {
      throw new Error("The successful split payment has no Stripe charge.");
    }
    const amountTotal = Number(session.amount_total || 0);
    const taxCollectedMinor = Number(
        session.total_details && session.total_details.amount_tax || 0,
    );
    if (!Number.isSafeInteger(amountTotal) || amountTotal < expectedAmount ||
        !Number.isSafeInteger(taxCollectedMinor) || taxCollectedMinor < 0) {
      throw new Error("The successful split payment totals are invalid.");
    }

    const depositRef = saleRef.collection("payment_parts").doc("deposit");
    const balanceRef = saleRef.collection("payment_parts").doc("balance");
    const affiliateLedgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${identity.transactionId}`);
    await db.runTransaction(async (transaction) => {
      const [currentSaleSnapshot, depositSnapshot, balanceSnapshot, affiliateLedger] =
        await Promise.all([
          transaction.get(saleRef),
          transaction.get(depositRef),
          transaction.get(balanceRef),
          transaction.get(affiliateLedgerRef),
        ]);
      if (!currentSaleSnapshot.exists || !depositSnapshot.exists || !balanceSnapshot.exists) {
        throw new Error("The split payment ledger is incomplete.");
      }
      const currentSale = currentSaleSnapshot.data();
      const deposit = depositSnapshot.data();
      const balance = balanceSnapshot.data();
      const currentPart = identity.partId === "deposit" ? deposit : balance;
      if (currentPart.status === "paid") return;
      if (identity.partId === "balance" && deposit.status !== "paid") {
        throw new Error("The remaining balance cannot settle before the deposit.");
      }
      const totalRequired = Number(currentSale.paymentRequiredMinor || 0);
      const depositAmount = Number(deposit.amountMinor || 0);
      const balanceAmount = Number(balance.amountMinor || 0);
      if (!Number.isSafeInteger(totalRequired) || totalRequired <= 0 ||
          depositAmount + balanceAmount !== totalRequired) {
        throw new Error("The split payment ledger no longer matches the sale total.");
      }

      const currentPartRef = identity.partId === "deposit" ? depositRef : balanceRef;
      transaction.set(currentPartRef, {
        status: "paid",
        paymentProvider: "stripe",
        stripeCheckoutSessionId: String(session.id || ""),
        stripePaymentIntentId: paymentIntentId,
        stripeChargeId: chargeId,
        buyerChargedMinor: amountTotal,
        taxCollectedMinor,
        refundedMinor: Number(currentPart.refundedMinor || 0),
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      if (identity.partId === "deposit") {
        transaction.set(balanceRef, {
          status: balance.status === "blocked_until_deposit_paid" ? "pending" : balance.status,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(saleRef, {
          paymentMethod: "stripe_checkout",
          paymentProvider: "stripe",
          paymentProviderStatus: "partially_paid",
          amountPaidMinor: depositAmount,
          balanceRemainingMinor: balanceAmount,
          buyerChargedMinor: amountTotal,
          taxCollectedMinor,
          stripeCheckoutSessionIds: [String(session.id || "")],
          stripePaymentIntentIds: [paymentIntentId],
          stripeChargeIds: [chargeId],
          sellerPayoutStatus: "awaiting_full_payment",
          financialStatus: "deposit_paid_pending_balance",
          depositPaidAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }

      const fee = currentSale.marketplaceFeeSnapshot || {};
      const marketplaceFeeMinor = Number(fee.marketplaceFeeMinor);
      const sellerProceedsMinor = Number(fee.sellerProceedsBeforeTaxMinor);
      if (!Number.isSafeInteger(marketplaceFeeMinor) || marketplaceFeeMinor < 0 ||
          !Number.isSafeInteger(sellerProceedsMinor) || sellerProceedsMinor < 0) {
        throw new Error("The immutable Pipe Buyer fee snapshot is unavailable.");
      }
      const depositChargeId = String(deposit.stripeChargeId || "");
      const depositIntentId = String(deposit.stripePaymentIntentId || "");
      const depositSessionId = String(deposit.stripeCheckoutSessionId || "");
      if (!depositChargeId.startsWith("ch_") || !depositIntentId.startsWith("pi_") ||
          !depositSessionId.startsWith("cs_")) {
        throw new Error("The paid deposit ledger is missing Stripe identifiers.");
      }
      const depositBuyerCharged = Number(deposit.buyerChargedMinor || depositAmount);
      const depositTax = Number(deposit.taxCollectedMinor || 0);
      const aggregateCharged = depositBuyerCharged + amountTotal;
      const aggregateTax = depositTax + taxCollectedMinor;
      transaction.set(saleRef, {
        paymentMethod: "stripe_checkout",
        paymentProvider: "stripe",
        paymentProviderStatus: "paid",
        marketplaceFeeStatus: "collected",
        amountPaidMinor: totalRequired,
        balanceRemainingMinor: 0,
        buyerChargedMinor: aggregateCharged,
        taxCollectedMinor: aggregateTax,
        stripeCheckoutSessionIds: [depositSessionId, String(session.id || "")],
        stripePaymentIntentIds: [depositIntentId, paymentIntentId],
        stripeChargeIds: [depositChargeId, chargeId],
        stripeSellerTransferId: null,
        sellerPayoutStatus: "pending_release",
        sellerProceedsMinor,
        platformMarketplaceFeeMinor: marketplaceFeeMinor,
        refundedMinor: Number(currentSale.refundedMinor || 0),
        financialStatus: "paid_pending_fulfillment",
        financialHold: false,
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (affiliateLedger.exists &&
          affiliateLedger.data().status === "pending_platform_fee_payment") {
        transaction.update(affiliateLedgerRef, {
          status: "pending_refund_window",
          eligibleAfter: affiliateEligibleAfter(),
          sourceChargeId: chargeId,
          sourceChargeIds: [depositChargeId, chargeId],
          platformFeeCollectedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return true;
  }

  return {
    markPaymentPartFailure,
    markPaymentPartProcessing,
    settleSuccessfulPaymentPart,
  };
}

module.exports = {
  billingType,
  createMarketplacePaymentPartSettlement,
  paymentPartIdentity,
};
