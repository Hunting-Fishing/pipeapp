"use strict";

const {
  subscriptionMembershipPlan,
} = require("./membership_plan_policy");

const TERMINAL_PROVIDER_STATUSES = new Set([
  "canceled",
  "incomplete_expired",
]);

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function stripeSecondsMillis(value) {
  const seconds = Number(value || 0);
  return Number.isFinite(seconds) && seconds > 0 ? seconds * 1000 : 0;
}

function validUid(value) {
  const uid = String(value || "").trim();
  return uid && !uid.includes("/") && uid.length <= 180 ? uid : "";
}

function dispatchSubscriptionIdentity(subscription) {
  const subscriptionId = String(subscription && subscription.id || "").trim();
  const metadata = subscription && subscription.metadata || {};
  const plan = subscriptionMembershipPlan(subscription);
  if (!subscriptionId.startsWith("sub_") || !plan || plan.tier !== "dispatch") {
    return null;
  }
  const uid = validUid(metadata.pipeBuyerUid);
  if (!uid) return null;
  return {subscriptionId, uid, metadata, plan};
}

function dispatchCheckoutIdentity(session) {
  const metadata = session && session.metadata || {};
  if (metadata.billingType !== "dispatch_subscription") return null;
  const uid = validUid(metadata.pipeBuyerUid || session.client_reference_id);
  const subscriptionId = typeof (session && session.subscription) === "string" ?
    session.subscription :
    String(session && session.subscription && session.subscription.id || "");
  if (!uid || !subscriptionId.startsWith("sub_")) return null;
  const customerId = typeof (session && session.customer) === "string" ?
    session.customer :
    String(session && session.customer && session.customer.id || "");
  return {
    uid,
    subscriptionId,
    stripeCustomerId: customerId.startsWith("cus_") ? customerId : "",
  };
}

function subscriptionCustomerId(subscription) {
  const customerId = typeof (subscription && subscription.customer) === "string" ?
    subscription.customer :
    String(subscription && subscription.customer && subscription.customer.id || "");
  return customerId.startsWith("cus_") ? customerId : "";
}

function subscriptionPeriodEndMillis(subscription) {
  const candidates = [
    stripeSecondsMillis(subscription && subscription.current_period_end),
    stripeSecondsMillis(subscription && subscription.cancel_at),
  ];
  const items = subscription && subscription.items && subscription.items.data;
  if (Array.isArray(items)) {
    for (const item of items) {
      candidates.push(stripeSecondsMillis(item && item.current_period_end));
    }
  }
  return Math.max(0, ...candidates);
}

function providerSubscriptionState(subscription, {deleted = false} = {}) {
  const providerStatus = deleted ?
    "canceled" : String(subscription && subscription.status || "unknown").trim();
  return {
    providerStatus,
    blocksNewCheckout: !TERMINAL_PROVIDER_STATUSES.has(providerStatus),
    cancelAtPeriodEnd: !deleted &&
      subscription && subscription.cancel_at_period_end === true,
    providerPeriodEndMillis: subscriptionPeriodEndMillis(subscription) || null,
    stripeCustomerId: subscriptionCustomerId(subscription) || null,
  };
}

function lifecycleStatePatch({
  subscription,
  existingMembership,
  deleted = false,
  nowMillis = Date.now(),
}) {
  const provider = providerSubscriptionState(subscription, {deleted});
  const providerStatus = provider.providerStatus;
  const paidThroughMillis = timestampMillis(
      existingMembership && existingMembership.currentPeriodEnd,
  );
  const stillPaid = paidThroughMillis > nowMillis;
  const cancelAtPeriodEnd = provider.cancelAtPeriodEnd;
  const providerEndMillis = provider.providerPeriodEndMillis || 0;
  const cancellationEffectiveMillis = cancelAtPeriodEnd ?
    (stripeSecondsMillis(subscription && subscription.cancel_at) ||
      providerEndMillis || paidThroughMillis) :
    deleted ? (providerEndMillis || paidThroughMillis) : 0;
  const paymentIssue = new Set(["past_due", "unpaid", "paused"]).has(providerStatus);

  let renewalStatus = providerStatus || "unknown";
  if (cancelAtPeriodEnd) renewalStatus = "cancel_at_period_end";
  if (deleted || providerStatus === "canceled") renewalStatus = "canceled";

  let status = String(existingMembership && existingMembership.status || "expired");
  if (stillPaid) {
    status = renewalStatus === "canceled" || renewalStatus === "cancel_at_period_end" ?
      "active_until_period_end" : "active";
  } else if (renewalStatus === "canceled") {
    status = "canceled";
  } else {
    status = "expired";
  }

  return {
    active: stillPaid,
    status,
    providerStatus,
    renewalStatus,
    paymentIssue,
    cancelAtPeriodEnd,
    cancellationEffectiveMillis: cancellationEffectiveMillis || null,
  };
}

function createDispatchSubscriptionLifecycle(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function handleDispatchCheckoutCompleted(session) {
    const identity = dispatchCheckoutIdentity(session);
    if (!identity) return;
    const providerStateRef = db.collection("dispatch_subscription_provider_state")
        .doc(identity.uid);
    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(providerStateRef);
      transaction.set(providerStateRef, {
        ownerUid: identity.uid,
        subscriptionId: identity.subscriptionId,
        stripeCustomerId: identity.stripeCustomerId || null,
        providerStatus: "checkout_completed",
        blocksNewCheckout: true,
        cancelAtPeriodEnd: false,
        updatedAt: FieldValue.serverTimestamp(),
        ...(existing.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
    });
  }

  async function applySubscriptionLifecycle(subscription, {deleted = false} = {}) {
    const identity = dispatchSubscriptionIdentity(subscription);
    if (!identity) return;
    const membershipRef = db.collection("dispatch_memberships").doc(identity.uid);
    const providerStateRef = db.collection("dispatch_subscription_provider_state")
        .doc(identity.uid);
    await db.runTransaction(async (transaction) => {
      const [membershipSnapshot, providerStateSnapshot] = await Promise.all([
        transaction.get(membershipRef),
        transaction.get(providerStateRef),
      ]);
      const provider = providerSubscriptionState(subscription, {deleted});
      transaction.set(providerStateRef, {
        ownerUid: identity.uid,
        subscriptionId: identity.subscriptionId,
        stripeCustomerId: provider.stripeCustomerId,
        providerStatus: provider.providerStatus,
        blocksNewCheckout: provider.blocksNewCheckout,
        cancelAtPeriodEnd: provider.cancelAtPeriodEnd,
        providerPeriodEnd: provider.providerPeriodEndMillis ?
          Timestamp.fromMillis(provider.providerPeriodEndMillis) : null,
        currentPlanId: identity.plan.id,
        currentPriceId: identity.plan.priceId,
        ...(deleted ? {deletedAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp(),
        ...(providerStateSnapshot.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});

      if (!membershipSnapshot.exists) {
        // Provider state is tracked even before payment, but paid access is not.
        // invoice.paid remains the only authority that establishes/extends access.
        return;
      }
      const existing = membershipSnapshot.data();
      const existingSubscriptionId = String(existing.subscriptionId || "").trim();
      if (existingSubscriptionId &&
          existingSubscriptionId !== identity.subscriptionId) {
        return;
      }
      const patch = lifecycleStatePatch({
        subscription,
        existingMembership: existing,
        deleted,
        nowMillis: Date.now(),
      });
      transaction.set(membershipRef, {
        providerStatus: patch.providerStatus,
        renewalStatus: patch.renewalStatus,
        paymentIssue: patch.paymentIssue,
        cancelAtPeriodEnd: patch.cancelAtPeriodEnd,
        active: patch.active,
        status: patch.status,
        plan: identity.plan.id === "dispatch_yearly" ? "yearly" : "monthly",
        billingProvider: "stripe",
        cancellationEffectiveAt: patch.cancellationEffectiveMillis ?
          Timestamp.fromMillis(patch.cancellationEffectiveMillis) : null,
        ...(deleted ? {canceledAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  return {
    handleDispatchCheckoutCompleted,
    handleDispatchSubscriptionCreated: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: false}),
    handleDispatchSubscriptionDeleted: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: true}),
    handleDispatchSubscriptionUpdated: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: false}),
  };
}

module.exports = {
  TERMINAL_PROVIDER_STATUSES,
  createDispatchSubscriptionLifecycle,
  dispatchCheckoutIdentity,
  dispatchSubscriptionIdentity,
  lifecycleStatePatch,
  providerSubscriptionState,
  stripeSecondsMillis,
  subscriptionCustomerId,
  subscriptionPeriodEndMillis,
  timestampMillis,
  validUid,
};
