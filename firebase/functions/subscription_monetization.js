"use strict";

const SUBSCRIPTION_AFFILIATE_SHARE_BPS = 2000;
const BASIS_POINTS = 10000;
const SUBSCRIPTION_REFUND_WINDOW_DAYS = 30;

async function retrieveStripeSubscription({secretKey, apiVersion, subscriptionId}) {
  const response = await fetch(
      `https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subscriptionId)}`,
      {
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Stripe-Version": apiVersion,
        },
      },
  );
  const payload = await response.json();
  if (!response.ok) throw new Error("Stripe subscription retrieval failed.");
  return payload;
}

function invoiceCommissionBaseMinor(invoice) {
  const excludingTax = Number(invoice && invoice.subtotal_excluding_tax);
  if (Number.isSafeInteger(excludingTax) && excludingTax >= 0) return excludingTax;
  const subtotal = Number(invoice && invoice.subtotal);
  return Number.isSafeInteger(subtotal) && subtotal >= 0 ? subtotal : 0;
}

function createSubscriptionMonetization(admin, stripeConfig) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function handleDispatchInvoicePaid(invoice, secretKey) {
    const invoiceId = String(invoice && invoice.id || "");
    const subscriptionId = typeof invoice.subscription === "string" ?
      invoice.subscription :
      String(invoice.subscription && invoice.subscription.id || "");
    if (!invoiceId.startsWith("in_") || !subscriptionId.startsWith("sub_")) return;
    const subscription = await retrieveStripeSubscription({
      secretKey,
      apiVersion: stripeConfig.apiVersion,
      subscriptionId,
    });
    const metadata = subscription.metadata || {};
    if (metadata.billingType !== "dispatch_subscription") return;
    const uid = String(metadata.pipeBuyerUid || "").trim();
    const referrerUid = String(metadata.affiliateReferrerUid || "").trim();
    const baseMinor = invoiceCommissionBaseMinor(invoice);
    const commissionMinor = Math.floor(
        baseMinor * SUBSCRIPTION_AFFILIATE_SHARE_BPS / BASIS_POINTS,
    );
    const invoiceRef = db.collection("dispatch_subscription_invoices").doc(invoiceId);
    const commissionRef = db.collection("affiliate_commission_ledger")
        .doc(`subscription_${invoiceId}`);
    const sourceChargeId = typeof invoice.charge === "string" ?
      invoice.charge : String(invoice.charge && invoice.charge.id || "");
    const eligibleAfter = Timestamp.fromMillis(
        Date.now() + SUBSCRIPTION_REFUND_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
    await db.runTransaction(async (transaction) => {
      const existingInvoice = await transaction.get(invoiceRef);
      const existingCommission = referrerUid && commissionMinor > 0 ?
        await transaction.get(commissionRef) : null;
      transaction.set(invoiceRef, {
        invoiceId,
        subscriptionId,
        uid: uid || null,
        plan: String(metadata.dispatchPlan || ""),
        currency: String(invoice.currency || "cad").toUpperCase(),
        commissionBaseMinor: baseMinor,
        amountPaidMinor: Number(invoice.amount_paid || 0),
        taxMinor: Math.max(0, Number(invoice.total || 0) - baseMinor),
        sourceChargeId: sourceChargeId || null,
        status: "paid",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingInvoice.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});
      if (referrerUid && commissionMinor > 0 &&
          existingCommission && !existingCommission.exists) {
        transaction.create(commissionRef, {
          type: "dispatch_subscription_share",
          invoiceId,
          subscriptionId,
          referredUid: uid,
          referrerUid,
          currency: String(invoice.currency || "cad").toUpperCase(),
          revenueBaseMinor: baseMinor,
          commissionShareBps: SUBSCRIPTION_AFFILIATE_SHARE_BPS,
          commissionMinor,
          sourceChargeId: sourceChargeId || null,
          status: "pending_refund_window",
          eligibleAfter,
          payoutProvider: "stripe_connect",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  async function voidPendingCommissionForRefund(charge) {
    const chargeId = String(charge && charge.id || "");
    if (!chargeId.startsWith("ch_") || charge.refunded !== true) return;
    const snapshot = await db.collection("affiliate_commission_ledger")
        .where("sourceChargeId", "==", chargeId)
        .limit(50)
        .get();
    if (snapshot.empty) return;
    const writer = db.bulkWriter();
    for (const document of snapshot.docs) {
      const status = String(document.data().status || "");
      if (["paid", "void_refunded"].includes(status)) continue;
      writer.update(document.ref, {
        status: "void_refunded",
        refundedChargeId: chargeId,
        voidedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await writer.close();
  }

  return {
    handleDispatchInvoicePaid,
    voidPendingCommissionForRefund,
  };
}

module.exports = {
  BASIS_POINTS,
  SUBSCRIPTION_AFFILIATE_SHARE_BPS,
  SUBSCRIPTION_REFUND_WINDOW_DAYS,
  createSubscriptionMonetization,
  invoiceCommissionBaseMinor,
  retrieveStripeSubscription,
};
