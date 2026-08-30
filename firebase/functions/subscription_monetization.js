"use strict";

const {
  provisionalTaxReserveMinor,
} = require("./pending_tax_policy");
const {
  invoiceMembershipPlanResolution,
  subscriptionMembershipPlan,
} = require("./membership_plan_policy");

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

function invoicePeriodBounds(invoice) {
  const starts = [];
  const ends = [];
  const addPeriod = (period) => {
    const start = Number(period && period.start || 0);
    const end = Number(period && period.end || 0);
    if (Number.isFinite(start) && start > 0) starts.push(start);
    if (Number.isFinite(end) && end > 0) ends.push(end);
  };
  addPeriod({
    start: invoice && invoice.period_start,
    end: invoice && invoice.period_end,
  });
  const lines = invoice && invoice.lines && invoice.lines.data;
  if (Array.isArray(lines)) {
    for (const line of lines) addPeriod(line && line.period);
  }
  return {
    startMillis: starts.length ? Math.min(...starts) * 1000 : null,
    endMillis: ends.length ? Math.max(...ends) * 1000 : null,
  };
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

function stripeCustomerIdFromInvoice(invoice) {
  const customerId = typeof (invoice && invoice.customer) === "string" ?
    invoice.customer :
    String(invoice && invoice.customer && invoice.customer.id || "");
  return customerId.startsWith("cus_") ? customerId : "";
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

function validMembershipUid(value) {
  const uid = String(value || "").trim();
  return uid && !uid.includes("/") && uid.length <= 180 ? uid : "";
}

async function dispatchSubscriptionContextFromInvoice({
  invoice,
  secretKey,
  stripeConfig,
}) {
  const invoiceId = String(invoice && invoice.id || "");
  const identity = subscriptionIdentityFromInvoice(invoice);
  const subscriptionId = String(identity.subscriptionId || "");
  if (!invoiceId.startsWith("in_") || !subscriptionId.startsWith("sub_")) {
    return null;
  }

  const resolution = invoiceMembershipPlanResolution(invoice);
  if (resolution.ambiguous) return null;
  let plan = resolution.plan;
  let metadata = identity.metadata || null;
  let subscription = null;

  if (!metadata || !plan) {
    subscription = await retrieveStripeSubscription({
      secretKey,
      apiVersion: stripeConfig.apiVersion,
      subscriptionId,
    });
    const subscriptionPlan = subscriptionMembershipPlan(subscription);
    if (!plan && !resolution.hasApprovedPrice) plan = subscriptionPlan;
    const subscriptionMetadata = subscription.metadata || {};
    const invoiceUid = validMembershipUid(metadata && metadata.pipeBuyerUid);
    const subscriptionUid = validMembershipUid(subscriptionMetadata.pipeBuyerUid);
    if (invoiceUid && subscriptionUid && invoiceUid !== subscriptionUid) return null;
    metadata = {...subscriptionMetadata, ...(metadata || {})};
  }

  if (!plan || plan.tier !== "dispatch") return null;
  const uid = validMembershipUid(metadata && metadata.pipeBuyerUid);
  if (!uid) return null;
  metadata = {
    ...(metadata || {}),
    billingType: plan.billingType,
    pipeBuyerUid: uid,
    dispatchPlan: plan.dispatchPlan,
    vipPlan: "",
  };
  return {invoiceId, subscriptionId, metadata, uid, plan};
}

function createSubscriptionMonetization(admin, stripeConfig) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function handleDispatchInvoicePaid(invoice, secretKey) {
    const context = await dispatchSubscriptionContextFromInvoice({
      invoice,
      secretKey,
      stripeConfig,
    });
    if (!context) return;
    const {invoiceId, subscriptionId, metadata, uid, plan} = context;
    const referrerUid = String(metadata.affiliateReferrerUid || "").trim();
    const taxStatus = String(metadata.taxCollectionStatus || "registered").trim();
    const baseMinor = invoiceCommissionBaseMinor(invoice);
    const reserveMinor = provisionalTaxReserveMinor(baseMinor, taxStatus);
    const commissionMinor = Math.floor(
        baseMinor * SUBSCRIPTION_AFFILIATE_SHARE_BPS / BASIS_POINTS,
    );
    const invoiceRef = db.collection("dispatch_subscription_invoices").doc(invoiceId);
    const commissionRef = db.collection("affiliate_commission_ledger")
        .doc(`subscription_${invoiceId}`);
    const membershipRef = db.collection("dispatch_memberships").doc(uid);
    const sourceChargeId = sourceChargeFromInvoice(invoice);
    const customerId = stripeCustomerIdFromInvoice(invoice);
    const period = invoicePeriodBounds(invoice);
    const eligibleAfter = Timestamp.fromMillis(
        Date.now() + SUBSCRIPTION_REFUND_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
    await db.runTransaction(async (transaction) => {
      const existingInvoice = await transaction.get(invoiceRef);
      const existingMembership = await transaction.get(membershipRef);
      const existingCommission = referrerUid && commissionMinor > 0 ?
        await transaction.get(commissionRef) : null;
      transaction.set(invoiceRef, {
        invoiceId,
        subscriptionId,
        uid,
        stripeCustomerId: customerId || null,
        plan: plan.dispatchPlan,
        currency: String(invoice.currency || "cad").toUpperCase(),
        commissionBaseMinor: baseMinor,
        amountPaidMinor: Number(invoice.amount_paid || 0),
        amountDueMinor: Number(invoice.amount_due || 0),
        taxMinor: Math.max(0, Number(invoice.total || 0) - baseMinor),
        taxCollectionStatus: taxStatus,
        taxExposureReviewRequired: taxStatus === "registration_pending",
        provisionalTaxReserveMinor: reserveMinor,
        taxReserveStatus: taxStatus === "registration_pending" ?
          "provisional_pending_cra" :
          "not_required",
        sourceChargeId: sourceChargeId || null,
        status: "paid",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingInvoice.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});

      if (period.endMillis) {
        const currentEnd = existingMembership.exists &&
          existingMembership.data().currentPeriodEnd &&
          typeof existingMembership.data().currentPeriodEnd.toMillis === "function" ?
          existingMembership.data().currentPeriodEnd.toMillis() : 0;
        if (period.endMillis >= currentEnd) {
          transaction.set(membershipRef, {
            ownerUid: uid,
            active: period.endMillis > Date.now(),
            status: period.endMillis > Date.now() ? "active" : "expired",
            renewalStatus: "paid",
            paymentIssue: false,
            plan: plan.dispatchPlan,
            subscriptionId,
            stripeCustomerId: customerId ||
              (existingMembership.exists ?
                existingMembership.data().stripeCustomerId || null : null),
            currentPeriodStart: period.startMillis ?
              Timestamp.fromMillis(period.startMillis) : null,
            currentPeriodEnd: Timestamp.fromMillis(period.endMillis),
            lastPaidInvoiceId: invoiceId,
            updatedAt: FieldValue.serverTimestamp(),
            ...(existingMembership.exists ? {} : {
              createdAt: FieldValue.serverTimestamp(),
            }),
          }, {merge: true});
        }
      }

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

  async function handleDispatchInvoicePaymentFailed(invoice, secretKey) {
    const context = await dispatchSubscriptionContextFromInvoice({
      invoice,
      secretKey,
      stripeConfig,
    });
    if (!context) return;
    const {invoiceId, subscriptionId, uid, plan} = context;
    const invoiceRef = db.collection("dispatch_subscription_invoices").doc(invoiceId);
    const membershipRef = db.collection("dispatch_memberships").doc(uid);
    const customerId = stripeCustomerIdFromInvoice(invoice);
    const nextAttemptSeconds = Number(invoice && invoice.next_payment_attempt || 0);
    const nextPaymentAttempt = Number.isFinite(nextAttemptSeconds) &&
      nextAttemptSeconds > 0 ?
      Timestamp.fromMillis(nextAttemptSeconds * 1000) : null;

    await db.runTransaction(async (transaction) => {
      const [existingInvoice, existingMembership] = await Promise.all([
        transaction.get(invoiceRef),
        transaction.get(membershipRef),
      ]);
      transaction.set(invoiceRef, {
        invoiceId,
        subscriptionId,
        uid,
        stripeCustomerId: customerId || null,
        plan: plan.dispatchPlan,
        currency: String(invoice.currency || "cad").toUpperCase(),
        amountDueMinor: Number(invoice.amount_due || 0),
        amountPaidMinor: Number(invoice.amount_paid || 0),
        attemptCount: Number(invoice.attempt_count || 0),
        nextPaymentAttempt,
        status: "payment_failed",
        paymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingInvoice.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});

      // A failed renewal does not revoke a period that was already paid for.
      // Access remains governed by currentPeriodEnd. Once that date passes,
      // the status callable reports the membership expired even if the stored
      // active flag has not yet been changed by another lifecycle event.
      if (existingMembership.exists) {
        transaction.set(membershipRef, {
          renewalStatus: "payment_failed",
          paymentIssue: true,
          lastPaymentFailureInvoiceId: invoiceId,
          lastPaymentFailureAt: FieldValue.serverTimestamp(),
          nextPaymentAttempt,
          stripeCustomerId: customerId ||
            existingMembership.data().stripeCustomerId || null,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
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
    handleDispatchInvoicePaymentFailed,
    voidPendingCommissionForRefund,
  };
}

module.exports = {
  BASIS_POINTS,
  SUBSCRIPTION_AFFILIATE_SHARE_BPS,
  SUBSCRIPTION_REFUND_WINDOW_DAYS,
  createSubscriptionMonetization,
  dispatchSubscriptionContextFromInvoice,
  invoiceCommissionBaseMinor,
  invoicePeriodBounds,
  retrieveStripeSubscription,
  sourceChargeFromInvoice,
  stripeCustomerIdFromInvoice,
  subscriptionIdentityFromInvoice,
  validMembershipUid,
};
