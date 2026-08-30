"use strict";

const TERMINAL_PROVIDER_STATUSES = new Set(["canceled", "incomplete_expired"]);

function providerSubscriptionId(data) {
  const id = String(data && data.subscriptionId || "").trim();
  return id.startsWith("sub_") ? id : "";
}

function providerTerminal(data) {
  return TERMINAL_PROVIDER_STATUSES.has(
      String(data && data.providerStatus || "").trim(),
  );
}

function createMembershipProviderStateSync(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function mirrorTerminalState({uid, sourceCollection, targetCollection}) {
    const sourceSnapshot = await db.collection(sourceCollection).doc(uid).get();
    if (!sourceSnapshot.exists || !providerTerminal(sourceSnapshot.data())) return;
    const source = sourceSnapshot.data();
    const subscriptionId = providerSubscriptionId(source);
    if (!subscriptionId) return;
    const targetRef = db.collection(targetCollection).doc(uid);
    const targetSnapshot = await targetRef.get();
    if (!targetSnapshot.exists) return;
    const target = targetSnapshot.data();
    if (providerSubscriptionId(target) !== subscriptionId || providerTerminal(target)) {
      return;
    }
    await targetRef.set({
      providerStatus: String(source.providerStatus || "canceled"),
      blocksNewCheckout: false,
      cancelAtPeriodEnd: false,
      terminalStateMirroredFrom: sourceCollection,
      terminalStateMirroredAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  async function onDispatchProviderUpdated(event) {
    const after = event.data && event.data.after && event.data.after.data();
    if (!providerTerminal(after)) return;
    await mirrorTerminalState({
      uid: event.params.uid,
      sourceCollection: "dispatch_subscription_provider_state",
      targetCollection: "vip_subscription_provider_state",
    });
  }

  async function onVipProviderUpdated(event) {
    const after = event.data && event.data.after && event.data.after.data();
    if (!providerTerminal(after)) return;
    await mirrorTerminalState({
      uid: event.params.uid,
      sourceCollection: "vip_subscription_provider_state",
      targetCollection: "dispatch_subscription_provider_state",
    });
  }

  return {onDispatchProviderUpdated, onVipProviderUpdated};
}

module.exports = {
  TERMINAL_PROVIDER_STATUSES,
  createMembershipProviderStateSync,
  providerSubscriptionId,
  providerTerminal,
};
