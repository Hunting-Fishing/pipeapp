"use strict";

const {
  retrieveStripeSubscription,
  subscriptionIdentityFromInvoice,
} = require("./subscription_monetization");
const {
  dispatchCheckoutWebhookDecision,
  dispatchSubscriptionLifecycleDecision,
} = require("./dispatch_subscription_lifecycle_policy");

const DISPATCH_SUBSCRIPTIONS_COLLECTION = "dispatch_subscriptions";
const SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION =
  "subscription_checkout_sessions";
const ENTITLEMENT_ACTIVATION_STATUSES = Object.freeze(new Set([
  "active",
  "trialing",
]));

function objectId(value) {
  if (typeof value === "string") return value;
  return String(value && value.id || "");
}

function dispatchMetadata(value) {
  const metadata = value && value.metadata || {};
  if (String(metadata.billingType || "") !== "dispatch_subscription") {
    return null;
  }
  const uid = String(metadata.pipeBuyerUid || "").trim();
  if (!uid) return null;
  return {
    uid,
    plan: String(metadata.dispatchPlan || "").trim(),
    taxCollectionStatus: String(
        metadata.taxCollectionStatus || "registered",
    ).trim(),
  };
}

function createDispatchSubscriptionState(admin, stripeConfig, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const retrieveSubscription = options.retrieveSubscription ||
    retrieveStripeSubscription;

  async function subscriptionFromInvoice(invoice, secretKey, {always = false} = {}) {
    const identity = subscriptionIdentityFromInvoice(invoice);
    const subscriptionId = String(identity.subscriptionId || "");
    if (!subscriptionId.startsWith("sub_")) return null;
    if (!always && identity.metadata) {
      return {
        id: subscriptionId,
        metadata: identity.metadata,
        status: "",
        customer: invoice.customer,
      };
    }
    return retrieveSubscription({
      secretKey,
      apiVersion: stripeConfig.apiVersion,
      subscriptionId,
    });
  }

  async function handleCheckoutSession(session) {
    const metadata = dispatchMetadata(session);
    if (!metadata) return {handled: false};
    const sessionId = String(session.id || "");
    if (!sessionId.startsWith("cs_")) return {handled: false};
    const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
        .doc(metadata.uid);
    const sessionRef = db.collection(SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION)
        .doc(sessionId);
    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(stateRef);
      const current = currentSnapshot.exists ? currentSnapshot.data() : {};
      const decision = dispatchCheckoutWebhookDecision(current, session);
      transaction.set(sessionRef, {
        uid: metadata.uid,
        plan: metadata.plan,
        status: "completed",
        stripeSubscriptionId: objectId(session.subscription) || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (decision.action === "preserve_active") {
        return {handled: true, action: "preserve_active"};
      }
      if (decision.action === "review") {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: decision.reason,
          conflictingStripeSubscriptionId: objectId(session.subscription) || null,
          lastCheckoutSessionId: sessionId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }
      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: metadata.plan || String(current.plan || ""),
        status: "processing",
        billingStatus: "checkout_complete",
        stripeCheckoutSessionId: sessionId,
        stripeSubscriptionId: decision.stripeSubscriptionId || null,
        stripeCustomerId: objectId(session.customer) || null,
        taxCollectionStatus: metadata.taxCollectionStatus,
        entitlementActive: current.entitlementActive === true,
        paymentIssue: false,
        reviewRequired: false,
        checkoutCompletedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {handled: true, action: "processing"};
    });
  }

  async function handleInvoicePaid(invoice, secretKey) {
    // Invoice payment is necessary evidence, but it is not sufficient to grant
    // access. Always retrieve the current Stripe Subscription so entitlement is
    // based on the provider lifecycle state rather than invoice metadata alone.
    const subscription = await subscriptionFromInvoice(
        invoice,
        secretKey,
        {always: true},
    );
    const metadata = dispatchMetadata(subscription);
    if (!metadata) return {handled: false};
    const invoiceId = String(invoice.id || "");
    const subscriptionId = String(subscription.id || "");
    if (!invoiceId.startsWith("in_") || !subscriptionId.startsWith("sub_")) {
      return {handled: false};
    }
    const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
        .doc(metadata.uid);
    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(stateRef);
      const current = currentSnapshot.exists ? currentSnapshot.data() : {};
      const currentSubscriptionId = String(current.stripeSubscriptionId || "");
      if (currentSubscriptionId.startsWith("sub_") &&
          currentSubscriptionId !== subscriptionId &&
          current.entitlementActive === true) {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: "paid_invoice_subscription_conflict",
          conflictingStripeSubscriptionId: subscriptionId,
          conflictingInvoiceId: invoiceId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }

      const lifecycle = dispatchSubscriptionLifecycleDecision(
          subscription.status,
          current.entitlementActive === true,
      );
      const activatesEntitlement =
        ENTITLEMENT_ACTIVATION_STATUSES.has(lifecycle.status) &&
        lifecycle.entitlementActive === true &&
        lifecycle.reviewRequired !== true;
      const billingStatus = activatesEntitlement ?
        "paid" : `paid_provider_${lifecycle.status}`.slice(0, 80);
      const reviewReason = lifecycle.reviewRequired ?
        "paid_invoice_subscription_status_review" : null;

      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: metadata.plan || String(current.plan || ""),
        status: lifecycle.status,
        billingStatus,
        stripeSubscriptionId: subscriptionId,
        stripeCustomerId: objectId(subscription.customer || invoice.customer) || null,
        taxCollectionStatus: metadata.taxCollectionStatus,
        entitlementActive: lifecycle.entitlementActive,
        paymentIssue: lifecycle.paymentIssue,
        reviewRequired: lifecycle.reviewRequired,
        ...(reviewReason ? {reviewReason} : {}),
        lastPaidInvoiceId: invoiceId,
        lastInvoiceAmountPaidMinor: Number(invoice.amount_paid || 0),
        lastInvoiceCurrency: String(invoice.currency || "cad").toUpperCase(),
        lastInvoicePaidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        handled: true,
        action: activatesEntitlement ?
          "activated" : lifecycle.reviewRequired ? "review" : "paid_state_updated",
      };
    });
  }

  async function handleInvoicePaymentFailed(invoice, secretKey) {
    const subscription = await subscriptionFromInvoice(
        invoice,
        secretKey,
        {always: true},
    );
    const metadata = dispatchMetadata(subscription);
    if (!metadata) return {handled: false};
    const invoiceId = String(invoice.id || "");
    const subscriptionId = String(subscription.id || "");
    if (!invoiceId.startsWith("in_") || !subscriptionId.startsWith("sub_")) {
      return {handled: false};
    }
    const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
        .doc(metadata.uid);
    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(stateRef);
      const current = currentSnapshot.exists ? currentSnapshot.data() : {};
      const currentSubscriptionId = String(current.stripeSubscriptionId || "");
      if (currentSubscriptionId.startsWith("sub_") &&
          currentSubscriptionId !== subscriptionId) {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: "failed_invoice_subscription_conflict",
          conflictingStripeSubscriptionId: subscriptionId,
          conflictingInvoiceId: invoiceId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }
      const lifecycle = dispatchSubscriptionLifecycleDecision(
          subscription.status,
          current.entitlementActive === true,
      );
      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: metadata.plan || String(current.plan || ""),
        status: lifecycle.status,
        billingStatus: "payment_failed",
        stripeSubscriptionId: subscriptionId,
        stripeCustomerId: objectId(subscription.customer || invoice.customer) || null,
        entitlementActive: lifecycle.entitlementActive,
        paymentIssue: true,
        reviewRequired: lifecycle.reviewRequired,
        lastFailedInvoiceId: invoiceId,
        lastInvoicePaymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {handled: true, action: "payment_failed"};
    });
  }

  async function handleSubscriptionEvent(subscription, eventType) {
    const metadata = dispatchMetadata(subscription);
    if (!metadata) return {handled: false};
    const subscriptionId = String(subscription.id || "");
    if (!subscriptionId.startsWith("sub_")) return {handled: false};
    const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
        .doc(metadata.uid);
    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(stateRef);
      const current = currentSnapshot.exists ? currentSnapshot.data() : {};
      const currentSubscriptionId = String(current.stripeSubscriptionId || "");
      if (currentSubscriptionId.startsWith("sub_") &&
          currentSubscriptionId !== subscriptionId) {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: "subscription_event_conflict",
          conflictingStripeSubscriptionId: subscriptionId,
          conflictingSubscriptionEventType: eventType,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }
      const providerStatus = eventType === "customer.subscription.deleted" ?
        "canceled" : String(subscription.status || "");
      const lifecycle = dispatchSubscriptionLifecycleDecision(
          providerStatus,
          current.entitlementActive === true,
      );
      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: metadata.plan || String(current.plan || ""),
        status: lifecycle.status,
        stripeSubscriptionId: subscriptionId,
        stripeCustomerId: objectId(subscription.customer) || null,
        entitlementActive: lifecycle.entitlementActive,
        paymentIssue: lifecycle.paymentIssue,
        reviewRequired: lifecycle.reviewRequired,
        lastSubscriptionEventType: eventType,
        subscriptionStateUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {handled: true, action: "updated"};
    });
  }

  return {
    handleCheckoutSession,
    handleInvoicePaid,
    handleInvoicePaymentFailed,
    handleSubscriptionEvent,
  };
}

module.exports = {
  DISPATCH_SUBSCRIPTIONS_COLLECTION,
  ENTITLEMENT_ACTIVATION_STATUSES,
  SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION,
  createDispatchSubscriptionState,
  dispatchMetadata,
  objectId,
};
