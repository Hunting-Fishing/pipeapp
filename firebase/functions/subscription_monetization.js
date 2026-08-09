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
  const totalExcludingTax = Number(invoice && invoice.total_excluding_tax);
  if (Number.isSafeInteger(totalExcludingTax) && totalExcludingTax >= 0) {
    return totalExcludingTax;
  }
  const total = Number(invoice && invoice.total);
  const tax = Number(invoice && invoice.tax);
  if (Number.isSafeInteger(total) && total >= 0 &&
      Number.isSafeInteger(tax) && tax >= 0) {
    return Math.max(0, total - tax);
  }
  const subtotal = Number(invoice && invoice.subtotal);
  const discounts = Array.isArray(invoice && invoice.total_discount_amounts) ?
    invoice.total_discount_amounts.reduce(
        (sum, discount) => sum + Math.max(0, Number(discount.amount || 0)),
        0,
    ) : 0;
  return Number.isSafeInteger(subtotal) && subtotal >= 0 ?
    Math.max(0, subtotal - discounts) : 0;
}

function subscriptionIdentityFromInvoice(invoice) {
  const parent = invoice && invoice.parent;
  const details = parent && parent.subscription_details;
  const parentSubscription = details && details.subscription;
  const subscriptionId = typeof parentSubscription === "string" ?
    parentSubscription :
    typeof invoice.subscription === "string" ? invoice.subscription :
    String(invoice.subscription && invoice.subscription.id || "");
  const metadata = details && details.metadata ? details.metadata : null;
  return {subscriptionId, metadata};
}

function sourceChargeFromInvoice(invoice) {
  if (typeof invoice.charge === "string") return invoice.charge;
  if (invoice.charge && invoice.charge.id) return String(invoice.charge.id);
  const payments = invoice && invoice.payments && invoice.payments.data;
  if (!Array.isArray(payments)) return "";
  for (const invoicePayment of payments) {
    const payment = invoicePayment && invoicePayment.payment;
    if (payment && typeof payment.charge === "string") return payment.charge;
  }
  return "";
}

function createSubscriptionMonetization(admin, stripeConfig) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function handleDispatchInvoicePaid(invoice, secretKey) {
    const invoiceId = String(invoice && invoice.id || "");
    const identity = subscriptionIdentityFromInvoice(invoice);
    const subscriptionId = String(identity.subscriptionId || "");
    if (!invoiceId.startsWith("in_") || !subscriptionId.startsWith("sub_")) return;
    let metadata = identity.metadata;
    if (!metadata) {
      const subscription = await retrieveStripeSubscription({
        secretKey,
        apiVersion: stripeConfig.apiVersion,
        subscriptionId,
      });
      metadata = subscription.metadata || {};
    }
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
    const sourceChargeId = sourceChargeFromInvoice(invoice);
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
  sourceChargeFromInvoice,
  subscriptionIdentityFromInvoice,
};
