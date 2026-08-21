"use strict";

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

function dispatchSubscriptionIdentity(subscription) {
  const subscriptionId = String(subscription && subscription.id || "").trim();
  const metadata = subscription && subscription.metadata || {};
  if (!subscriptionId.startsWith("sub_") ||
      metadata.billingType !== "dispatch_subscription") {
    return null;
  }
  const uid = String(metadata.pipeBuyerUid || "").trim();
  if (!uid || uid.includes("/") || uid.length > 180) return null;
  return {subscriptionId, uid, metadata};
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

function lifecycleStatePatch({
  subscription,
  existingMembership,
  deleted = false,
  nowMillis = Date.now(),
}) {
  const providerStatus = deleted ?
    "canceled" : String(subscription && subscription.status || "unknown").trim();
  const paidThroughMillis = timestampMillis(
      existingMembership && existingMembership.currentPeriodEnd,
  );
  const stillPaid = paidThroughMillis > nowMillis;
  const cancelAtPeriodEnd = !deleted &&
    subscription && subscription.cancel_at_period_end === true;
  const providerEndMillis = subscriptionPeriodEndMillis(subscription);
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

  async function applySubscriptionLifecycle(subscription, {deleted = false} = {}) {
    const identity = dispatchSubscriptionIdentity(subscription);
    if (!identity) return;
    const membershipRef = db.collection("dispatch_memberships").doc(identity.uid);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(membershipRef);
      if (!snapshot.exists) {
        // Never create a paid entitlement from subscription lifecycle events.
        // invoice.paid remains the only authority that establishes/extends access.
        return;
      }
      const existing = snapshot.data();
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
        cancellationEffectiveAt: patch.cancellationEffectiveMillis ?
          Timestamp.fromMillis(patch.cancellationEffectiveMillis) : null,
        ...(deleted ? {canceledAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  return {
    handleDispatchSubscriptionDeleted: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: true}),
    handleDispatchSubscriptionUpdated: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: false}),
  };
}

module.exports = {
  createDispatchSubscriptionLifecycle,
  dispatchSubscriptionIdentity,
  lifecycleStatePatch,
  stripeSecondsMillis,
  subscriptionPeriodEndMillis,
  timestampMillis,
};
