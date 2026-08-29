"use strict";

const {
  lifecycleStatePatch,
  providerSubscriptionState,
  timestampMillis,
  validUid,
} = require("./dispatch_subscription_lifecycle");

function vipSubscriptionIdentity(subscription) {
  const subscriptionId = String(subscription && subscription.id || "").trim();
  const metadata = subscription && subscription.metadata || {};
  if (!subscriptionId.startsWith("sub_") ||
      metadata.billingType !== "vip_subscription") {
    return null;
  }
  const uid = validUid(metadata.pipeBuyerUid);
  if (!uid) return null;
  return {subscriptionId, uid, metadata};
}

function vipCheckoutIdentity(session) {
  const metadata = session && session.metadata || {};
  if (metadata.billingType !== "vip_subscription") return null;
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

function createVipSubscriptionLifecycle(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function handleVipCheckoutCompleted(session) {
    const identity = vipCheckoutIdentity(session);
    if (!identity) return;
    const providerStateRef = db.collection("vip_subscription_provider_state")
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
    const identity = vipSubscriptionIdentity(subscription);
    if (!identity) return;
    const membershipRef = db.collection("vip_memberships").doc(identity.uid);
    const providerStateRef = db.collection("vip_subscription_provider_state")
        .doc(identity.uid);
    const userRef = db.collection("users").doc(identity.uid);
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
        ...(deleted ? {deletedAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp(),
        ...(providerStateSnapshot.exists ? {} : {
          createdAt: FieldValue.serverTimestamp(),
        }),
      }, {merge: true});

      if (!membershipSnapshot.exists) {
        // A Checkout/subscription event records provider state only. invoice.paid
        // is the authority that establishes or extends paid VIP access.
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
      const paidThroughMillis = timestampMillis(existing.currentPeriodEnd);
      const vipExpiresAt = paidThroughMillis > 0 ?
        Timestamp.fromMillis(paidThroughMillis) : null;
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
      transaction.set(userRef, {
        vipActive: patch.active,
        vipStatus: patch.status,
        vipExpiresAt,
        vipSubscriptionId: identity.subscriptionId,
        vipUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  return {
    handleVipCheckoutCompleted,
    handleVipSubscriptionCreated: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: false}),
    handleVipSubscriptionDeleted: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: true}),
    handleVipSubscriptionUpdated: (subscription) =>
      applySubscriptionLifecycle(subscription, {deleted: false}),
  };
}

module.exports = {
  createVipSubscriptionLifecycle,
  vipCheckoutIdentity,
  vipSubscriptionIdentity,
};
