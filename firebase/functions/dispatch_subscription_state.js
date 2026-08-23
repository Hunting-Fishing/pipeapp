"use strict";

const {
  retrieveStripeSubscription,
  subscriptionIdentityFromInvoice,
} = require("./subscription_monetization");
const {
  isDispatchRetiredSubscriptionId,
} = require("./dispatch_subscription_checkout_policy");
const {
  dispatchCheckoutWebhookDecision,
  dispatchSubscriptionLifecycleDecision,
  dispatchSubscriptionReplacementAllowed,
} = require("./dispatch_subscription_lifecycle_policy");
const {
  dispatchSubscriptionCatalogAssessment,
} = require("./dispatch_subscription_catalog_policy");

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
    // Metadata records the Checkout-time selection for audit only. Current
    // lifecycle state derives Monthly/Yearly from the live Stripe Price.
    checkoutPlan: String(metadata.dispatchPlan || "").trim(),
    plan: String(metadata.dispatchPlan || "").trim(),
    taxCollectionStatus: String(
        metadata.taxCollectionStatus || "registered",
    ).trim(),
  };
}

function catalogReviewPatch(assessment, FieldValue, extra = {}) {
  return {
    entitlementActive: false,
    paymentIssue: true,
    reviewRequired: true,
    reviewReason: "dispatch_subscription_catalog_review",
    providerCatalogRevision: assessment.revision,
    providerCatalogFailedChecks: assessment.failedChecks,
    stripePriceId: assessment.priceId || null,
    stripeProductId: assessment.productId || null,
    stripeSubscriptionQuantity: assessment.quantity,
    ...extra,
    updatedAt: FieldValue.serverTimestamp(),
  };
}

function createDispatchSubscriptionState(admin, stripeConfig, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const retrieveSubscription = options.retrieveSubscription ||
    retrieveStripeSubscription;

  async function retrieveCurrentSubscription(subscriptionId, secretKey) {
    const current = await retrieveSubscription({
      secretKey,
      apiVersion: stripeConfig.apiVersion,
      subscriptionId,
    });
    if (String(current && current.id || "") !== subscriptionId) {
      throw new Error("Stripe returned an unexpected Dispatch subscription.");
    }
    return current;
  }

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
    return retrieveCurrentSubscription(subscriptionId, secretKey);
  }

  async function handleCheckoutSession(session) {
    const metadata = dispatchMetadata(session);
    if (!metadata) return {handled: false};
    const sessionId = String(session.id || "");
    if (!sessionId.startsWith("cs_")) return {handled: false};
    const eventSubscriptionId = objectId(session.subscription);
    const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
        .doc(metadata.uid);
    const sessionRef = db.collection(SUBSCRIPTION_CHECKOUT_SESSIONS_COLLECTION)
        .doc(sessionId);
    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(stateRef);
      const current = currentSnapshot.exists ? currentSnapshot.data() : {};
      if (eventSubscriptionId.startsWith("sub_") &&
          isDispatchRetiredSubscriptionId(current, eventSubscriptionId)) {
        transaction.set(sessionRef, {
          uid: metadata.uid,
          plan: metadata.checkoutPlan,
          status: "retired_ignored",
          stripeSubscriptionId: eventSubscriptionId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "ignored_retired"};
      }
      const decision = dispatchCheckoutWebhookDecision(current, session);
      transaction.set(sessionRef, {
        uid: metadata.uid,
        plan: metadata.checkoutPlan,
        status: "completed",
        stripeSubscriptionId: eventSubscriptionId || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (decision.action === "preserve_active") {
        return {handled: true, action: "preserve_active"};
      }
      if (decision.action === "review") {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: decision.reason,
          conflictingStripeSubscriptionId: eventSubscriptionId || null,
          lastCheckoutSessionId: sessionId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }
      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: metadata.checkoutPlan || String(current.plan || ""),
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
    // access. Always retrieve the current Stripe Subscription so entitlement and
    // plan are based on provider lifecycle + current Price, not stale metadata.
    const subscription = await subscriptionFromInvoice(
        invoice,
        secretKey,
        {always: true},
    );
    const metadata = dispatchMetadata(subscription);
    if (!metadata) return {handled: false};
    const catalog = dispatchSubscriptionCatalogAssessment(subscription);
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
      if (isDispatchRetiredSubscriptionId(current, subscriptionId)) {
        return {handled: true, action: "ignored_retired"};
      }
      const currentSubscriptionId = String(current.stripeSubscriptionId || "");
      if (currentSubscriptionId.startsWith("sub_") &&
          currentSubscriptionId !== subscriptionId &&
          !dispatchSubscriptionReplacementAllowed(current)) {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: "paid_invoice_subscription_conflict",
          conflictingStripeSubscriptionId: subscriptionId,
          conflictingInvoiceId: invoiceId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }
      if (!catalog.ready) {
        transaction.set(stateRef, catalogReviewPatch(catalog, FieldValue, {
          uid: metadata.uid,
          status: "review_required",
          billingStatus: "provider_catalog_review",
          stripeSubscriptionId: subscriptionId,
          stripeCustomerId: objectId(subscription.customer || invoice.customer) || null,
          lastPaidInvoiceId: invoiceId,
          lastInvoiceAmountPaidMinor: Number(invoice.amount_paid || 0),
          lastInvoiceCurrency: String(invoice.currency || "cad").toUpperCase(),
          lastInvoicePaidAt: FieldValue.serverTimestamp(),
        }), {merge: true});
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
        plan: catalog.plan,
        status: lifecycle.status,
        billingStatus,
        stripeSubscriptionId: subscriptionId,
        stripeCustomerId: objectId(subscription.customer || invoice.customer) || null,
        stripePriceId: catalog.priceId,
        stripeProductId: catalog.productId ||
          stripeConfig.products.dispatchMonthlyCad.productId,
        stripeSubscriptionQuantity: catalog.quantity,
        providerCatalogRevision: catalog.revision,
        providerCatalogFailedChecks: [],
        taxCollectionStatus: metadata.taxCollectionStatus,
        entitlementActive: lifecycle.entitlementActive,
        paymentIssue: lifecycle.paymentIssue,
        reviewRequired: lifecycle.reviewRequired,
        ...(reviewReason ? {reviewReason} : {reviewReason: null}),
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
    const catalog = dispatchSubscriptionCatalogAssessment(subscription);
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
      if (isDispatchRetiredSubscriptionId(current, subscriptionId)) {
        return {handled: true, action: "ignored_retired"};
      }
      const currentSubscriptionId = String(current.stripeSubscriptionId || "");
      if (currentSubscriptionId.startsWith("sub_") &&
          currentSubscriptionId !== subscriptionId &&
          !dispatchSubscriptionReplacementAllowed(current)) {
        transaction.set(stateRef, {
          reviewRequired: true,
          reviewReason: "failed_invoice_subscription_conflict",
          conflictingStripeSubscriptionId: subscriptionId,
          conflictingInvoiceId: invoiceId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {handled: true, action: "review"};
      }
      if (!catalog.ready) {
        transaction.set(stateRef, catalogReviewPatch(catalog, FieldValue, {
          uid: metadata.uid,
          status: "review_required",
          billingStatus: "provider_catalog_review",
          stripeSubscriptionId: subscriptionId,
          stripeCustomerId: objectId(subscription.customer || invoice.customer) || null,
          lastFailedInvoiceId: invoiceId,
          lastInvoicePaymentFailedAt: FieldValue.serverTimestamp(),
        }), {merge: true});
        return {handled: true, action: "review"};
      }
      const lifecycle = dispatchSubscriptionLifecycleDecision(
          subscription.status,
          current.entitlementActive === true,
      );
      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: catalog.plan,
        status: lifecycle.status,
        billingStatus: "payment_failed",
        stripeSubscriptionId: subscriptionId,
        stripeCustomerId: objectId(subscription.customer || invoice.customer) || null,
        stripePriceId: catalog.priceId,
        stripeProductId: catalog.productId ||
          stripeConfig.products.dispatchMonthlyCad.productId,
        stripeSubscriptionQuantity: catalog.quantity,
        providerCatalogRevision: catalog.revision,
        providerCatalogFailedChecks: [],
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

  async function handleSubscriptionEvent(subscription, eventType, secretKey) {
    const eventSubscriptionId = String(subscription && subscription.id || "");
    if (!eventSubscriptionId.startsWith("sub_")) return {handled: false};

    // Stripe does not guarantee webhook delivery order. For update events,
    // ignore the potentially stale event snapshot and re-read the current
    // Subscription before changing entitlement or plan. A deleted event is
    // itself the authoritative terminal cancellation signal for that ID.
    const providerSubscription = eventType === "customer.subscription.updated" ?
      await retrieveCurrentSubscription(eventSubscriptionId, secretKey) : subscription;
    const metadata = dispatchMetadata(providerSubscription);
    if (!metadata) return {handled: false};
    const catalog = dispatchSubscriptionCatalogAssessment(providerSubscription);
    const subscriptionId = String(providerSubscription.id || "");
    const stateRef = db.collection(DISPATCH_SUBSCRIPTIONS_COLLECTION)
        .doc(metadata.uid);
    return db.runTransaction(async (transaction) => {
      const currentSnapshot = await transaction.get(stateRef);
      const current = currentSnapshot.exists ? currentSnapshot.data() : {};
      if (isDispatchRetiredSubscriptionId(current, subscriptionId)) {
        return {handled: true, action: "ignored_retired"};
      }
      const currentSubscriptionId = String(current.stripeSubscriptionId || "");
      if (currentSubscriptionId.startsWith("sub_") &&
          currentSubscriptionId !== subscriptionId &&
          !dispatchSubscriptionReplacementAllowed(current)) {
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
        "canceled" : String(providerSubscription.status || "");
      if (!catalog.ready) {
        transaction.set(stateRef, catalogReviewPatch(catalog, FieldValue, {
          uid: metadata.uid,
          status: eventType === "customer.subscription.deleted" ?
            "canceled" : String(current.status || "review_required"),
          billingStatus: "provider_catalog_review",
          stripeSubscriptionId: subscriptionId,
          stripeCustomerId: objectId(providerSubscription.customer) || null,
          paymentIssue: eventType !== "customer.subscription.deleted",
          lastSubscriptionEventType: eventType,
          subscriptionStateUpdatedAt: FieldValue.serverTimestamp(),
        }), {merge: true});
        return {handled: true, action: "review"};
      }
      const lifecycle = dispatchSubscriptionLifecycleDecision(
          providerStatus,
          current.entitlementActive === true,
      );
      transaction.set(stateRef, {
        uid: metadata.uid,
        plan: catalog.plan,
        status: lifecycle.status,
        stripeSubscriptionId: subscriptionId,
        stripeCustomerId: objectId(providerSubscription.customer) || null,
        stripePriceId: catalog.priceId,
        stripeProductId: catalog.productId ||
          stripeConfig.products.dispatchMonthlyCad.productId,
        stripeSubscriptionQuantity: catalog.quantity,
        providerCatalogRevision: catalog.revision,
        providerCatalogFailedChecks: [],
        entitlementActive: lifecycle.entitlementActive,
        paymentIssue: lifecycle.paymentIssue,
        reviewRequired: lifecycle.reviewRequired,
        ...(lifecycle.reviewRequired ? {} : {reviewReason: null}),
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
  catalogReviewPatch,
  createDispatchSubscriptionState,
  dispatchMetadata,
  objectId,
};
