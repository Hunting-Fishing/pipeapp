"use strict";

const {provisionalTaxReserveMinor} = require("./pending_tax_policy");
const {
  invoiceMembershipPlanResolution,
  subscriptionMembershipPlan,
} = require("./membership_plan_policy");
const {
  invoiceCommissionBaseMinor,
  invoicePeriodBounds,
  retrieveStripeSubscription,
  stripeCustomerIdFromInvoice,
  subscriptionIdentityFromInvoice,
  validMembershipUid,
} = require("./subscription_monetization");

async function vipSubscriptionContextFromInvoice({
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

  if (!metadata || !plan) {
    const subscription = await retrieveStripeSubscription({
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

  if (!plan || plan.tier !== "vip") return null;
  const uid = validMembershipUid(metadata && metadata.pipeBuyerUid);
  if (!uid) return null;
  metadata = {
    ...(metadata || {}),
    billingType: plan.billingType,
    pipeBuyerUid: uid,
    vipPlan: plan.vipPlan,
    dispatchPlan: "",
  };
  return {invoiceId, subscriptionId, metadata, uid, plan};
}

function createVipSubscriptionMonetization(admin, stripeConfig) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function handleVipInvoicePaid(invoice, secretKey) {
    const context = await vipSubscriptionContextFromInvoice({
      invoice,
      secretKey,
      stripeConfig,
    });
    if (!context) return;
    const {invoiceId, subscriptionId, metadata, uid, plan} = context;
    const baseMinor = invoiceCommissionBaseMinor(invoice);
    const taxStatus = String(metadata.taxCollectionStatus || "registered").trim();
    const reserveMinor = provisionalTaxReserveMinor(baseMinor, taxStatus);
    const invoiceRef = db.collection("vip_subscription_invoices").doc(invoiceId);
    const membershipRef = db.collection("vip_memberships").doc(uid);
    const userRef = db.collection("users").doc(uid);
    const customerId = stripeCustomerIdFromInvoice(invoice);
    const period = invoicePeriodBounds(invoice);

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
        plan: plan.vipPlan,
        currency: String(invoice.currency || "cad").toUpperCase(),
        revenueBaseMinor: baseMinor,
        amountPaidMinor: Number(invoice.amount_paid || 0),
        amountDueMinor: Number(invoice.amount_due || 0),
        taxMinor: Math.max(0, Number(invoice.total || 0) - baseMinor),
        taxCollectionStatus: taxStatus,
        taxExposureReviewRequired: taxStatus === "registration_pending",
        provisionalTaxReserveMinor: reserveMinor,
        taxReserveStatus: taxStatus === "registration_pending" ?
          "provisional_pending_cra" : "not_required",
        status: "paid",
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingInvoice.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});

      if (!period.endMillis) return;
      const currentEnd = existingMembership.exists &&
        existingMembership.data().currentPeriodEnd &&
        typeof existingMembership.data().currentPeriodEnd.toMillis === "function" ?
        existingMembership.data().currentPeriodEnd.toMillis() : 0;
      if (period.endMillis < currentEnd) return;
      const active = period.endMillis > Date.now();
      const currentPeriodEnd = Timestamp.fromMillis(period.endMillis);
      transaction.set(membershipRef, {
        ownerUid: uid,
        active,
        status: active ? "active" : "expired",
        renewalStatus: "paid",
        paymentIssue: false,
        plan: plan.vipPlan,
        subscriptionId,
        stripeCustomerId: customerId ||
          (existingMembership.exists ?
            existingMembership.data().stripeCustomerId || null : null),
        currentPeriodStart: period.startMillis ?
          Timestamp.fromMillis(period.startMillis) : null,
        currentPeriodEnd,
        lastPaidInvoiceId: invoiceId,
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingMembership.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      transaction.set(userRef, {
        vipActive: active,
        vipStatus: active ? "active" : "expired",
        vipExpiresAt: currentPeriodEnd,
        vipSubscriptionId: subscriptionId,
        vipUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  async function handleVipInvoicePaymentFailed(invoice, secretKey) {
    const context = await vipSubscriptionContextFromInvoice({
      invoice,
      secretKey,
      stripeConfig,
    });
    if (!context) return;
    const {invoiceId, subscriptionId, uid, plan} = context;
    const invoiceRef = db.collection("vip_subscription_invoices").doc(invoiceId);
    const membershipRef = db.collection("vip_memberships").doc(uid);
    const userRef = db.collection("users").doc(uid);
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
        plan: plan.vipPlan,
        currency: String(invoice.currency || "cad").toUpperCase(),
        amountDueMinor: Number(invoice.amount_due || 0),
        amountPaidMinor: Number(invoice.amount_paid || 0),
        attemptCount: Number(invoice.attempt_count || 0),
        nextPaymentAttempt,
        status: "payment_failed",
        paymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(existingInvoice.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});

      if (!existingMembership.exists) return;
      const membership = existingMembership.data();
      const endMillis = membership.currentPeriodEnd &&
        typeof membership.currentPeriodEnd.toMillis === "function" ?
        membership.currentPeriodEnd.toMillis() : 0;
      const active = membership.active === true && endMillis > Date.now();
      transaction.set(membershipRef, {
        active,
        status: active ? String(membership.status || "active") : "expired",
        renewalStatus: "payment_failed",
        paymentIssue: true,
        lastPaymentFailureInvoiceId: invoiceId,
        lastPaymentFailureAt: FieldValue.serverTimestamp(),
        nextPaymentAttempt,
        stripeCustomerId: customerId || membership.stripeCustomerId || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(userRef, {
        vipActive: active,
        vipStatus: active ? "active_payment_issue" : "expired",
        vipExpiresAt: membership.currentPeriodEnd || null,
        vipSubscriptionId: subscriptionId,
        vipUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  return {
    handleVipInvoicePaid,
    handleVipInvoicePaymentFailed,
  };
}

module.exports = {
  createVipSubscriptionMonetization,
  vipSubscriptionContextFromInvoice,
};
