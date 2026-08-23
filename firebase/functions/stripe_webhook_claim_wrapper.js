"use strict";

const {
  stripeWebhookClaimDecision,
} = require("./stripe_webhook_event_claim");
const {
  externalFeeWebhookTransitionDecision,
  feeOnlyWebhookTransition,
  safeAttempt,
} = require("./external_settlement_fee_webhook_policy");

async function claimStripeWebhookEvent({
  db,
  eventRef,
  event,
  Timestamp,
  nowMillis = Date.now(),
}) {
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(eventRef);
    const existing = snapshot.exists ? snapshot.data() : {};
    const decision = stripeWebhookClaimDecision(existing, nowMillis);
    if (decision.action !== "claim") return decision;
    const processingStartedAt = Timestamp.fromMillis(
        decision.processingStartedAtMillis,
    );
    const processingLeaseExpiresAt = Timestamp.fromMillis(
        decision.processingLeaseExpiresAtMillis,
    );
    transaction.set(eventRef, {
      eventId: String(event.id || ""),
      type: String(event.type || ""),
      status: "processing",
      attempts: decision.attempt,
      processingStartedAt,
      processingLeaseExpiresAt,
      updatedAt: processingStartedAt,
    }, {merge: true});
    return decision;
  });
}

function feeEventData(event = {}) {
  const session = event.data && event.data.object || {};
  return {
    transactionId: String(
        session.metadata && session.metadata.pipeBuyerTransactionId || "",
    ).trim(),
    sessionId: String(session.id || "").trim(),
    attempt: safeAttempt(
        session.metadata && session.metadata.checkoutAttempt,
    ),
  };
}

async function applyExternalFeeNonSuccessEvent({
  db,
  event,
  FieldValue,
}) {
  const nextStatus = feeOnlyWebhookTransition(event);
  if (!nextStatus) return {handled: false};
  const eventData = feeEventData(event);
  if (!eventData.transactionId) {
    return {handled: true, action: "ignore", reason: "missing_transaction_id"};
  }
  const transactionRef = db.collection("marketplace_transactions")
      .doc(eventData.transactionId);
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(transactionRef);
    if (!snapshot.exists) {
      throw new Error("Pipe Buyer transaction for fee webhook was not found.");
    }
    const sale = snapshot.data() || {};
    const decision = externalFeeWebhookTransitionDecision({
      currentStatus: sale.marketplaceFeeStatus,
      currentSessionId: sale.stripeMarketplaceFeeSessionId,
      currentAttempt: sale.marketplaceFeeCheckoutAttempt,
      eventSessionId: eventData.sessionId,
      eventAttempt: eventData.attempt,
      nextStatus,
    });
    if (decision.action === "apply") {
      transaction.set(transactionRef, {
        marketplaceFeeStatus: nextStatus,
        stripeMarketplaceFeeSessionId: eventData.sessionId,
        ...(eventData.attempt > 0 ? {
          marketplaceFeeCheckoutAttempt: eventData.attempt,
        } : {}),
        ...(nextStatus === "payment_failed" ? {
          marketplaceFeePaymentFailedAt: FieldValue.serverTimestamp(),
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } else if (decision.action === "review") {
      transaction.set(transactionRef, {
        marketplaceFeeOperationalReviewRequired: true,
        marketplaceFeeOperationalReviewReason: decision.reason,
        marketplaceFeeOperationalReviewEventSessionId: eventData.sessionId,
        marketplaceFeeOperationalReviewEventAttempt: eventData.attempt || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return {
      handled: true,
      action: decision.action,
      reason: decision.reason || "",
      nextStatus: decision.nextStatus || nextStatus,
      transactionId: eventData.transactionId,
    };
  });
  return result;
}

function productionInnerHandler(admin) {
  const {
    createMarketplaceFinancialResolution,
  } = require("./marketplace_financial_resolution");
  const {
    createMarketplaceRefundWebhookGate,
  } = require("./marketplace_refund_webhook_gate");
  const {
    createStripeWebhookHandler,
  } = require("./stripe_webhook");
  const {
    createDispatchSubscriptionState,
  } = require("./dispatch_subscription_state");
  const {
    createDispatchSubscriptionWebhookWrapper,
  } = require("./dispatch_subscription_webhook_wrapper");
  const {
    stripeMarketplaceConfig,
  } = require("./stripe_marketplace_config");
  const financialResolution = createMarketplaceFinancialResolution(admin);
  const refundGate = createMarketplaceRefundWebhookGate(
      admin,
      financialResolution,
  );
  const coreWebhookHandler = createStripeWebhookHandler(admin, {
    marketplaceFinancialResolution: refundGate,
  });
  const dispatchSubscriptionState = createDispatchSubscriptionState(
      admin,
      stripeMarketplaceConfig,
  );
  return createDispatchSubscriptionWebhookWrapper(admin, {
    innerHandler: coreWebhookHandler,
    dispatchState: dispatchSubscriptionState,
  });
}

function createClaimedStripeWebhookHandler(admin, options = {}) {
  const db = admin.firestore();
  const Timestamp = admin.firestore.Timestamp;
  const FieldValue = admin.firestore.FieldValue;
  const innerHandler = options.innerHandler || productionInnerHandler(admin);
  const verifySignature = options.verifySignature ||
    require("./stripe_webhook").verifyStripeSignature;
  const secretProvider = options.secretProvider ||
    (() => require("./stripe_webhook").stripeWebhookSecret.value());
  const nowProvider = options.nowProvider || (() => Date.now());

  return async (request, response) => {
    const rawBody = request.rawBody;
    const signature = request.get("stripe-signature");
    if (!verifySignature(
        rawBody,
        signature,
        secretProvider(),
    )) {
      response.status(400).send("Invalid Stripe signature");
      return;
    }
    let event;
    try {
      event = JSON.parse(rawBody.toString("utf8"));
    } catch (_) {
      response.status(400).send("Invalid JSON");
      return;
    }
    const eventId = String(event.id || "");
    if (!eventId.startsWith("evt_")) {
      response.status(400).send("Invalid Stripe event");
      return;
    }
    const eventRef = db.collection("stripe_webhook_events").doc(eventId);
    let claim;
    try {
      claim = await claimStripeWebhookEvent({
        db,
        eventRef,
        event,
        Timestamp,
        nowMillis: nowProvider(),
      });
    } catch (error) {
      console.error("Stripe webhook event claim failed", {eventId, error});
      response.status(500).send("Webhook claim failed");
      return;
    }
    if (claim.action === "already_processed") {
      response.status(200).send("Already processed");
      return;
    }
    if (claim.action === "already_processing") {
      response.status(200).send("Already processing");
      return;
    }

    if (feeOnlyWebhookTransition(event)) {
      try {
        const transition = await applyExternalFeeNonSuccessEvent({
          db,
          event,
          FieldValue,
        });
        await eventRef.set({
          eventId,
          type: String(event.type || ""),
          status: "processed",
          guardedFeeTransitionAction: transition.action || "",
          guardedFeeTransitionReason: transition.reason || "",
          processingLeaseExpiresAt: null,
          processedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        response.status(200).send("OK");
      } catch (error) {
        console.error("Guarded external fee webhook transition failed", {
          eventId,
          type: event.type,
          error,
        });
        await eventRef.set({
          eventId,
          type: String(event.type || ""),
          status: "failed",
          processingLeaseExpiresAt: null,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        response.status(500).send("Webhook processing failed");
      }
      return;
    }

    await innerHandler(request, response);
  };
}

module.exports = {
  applyExternalFeeNonSuccessEvent,
  claimStripeWebhookEvent,
  createClaimedStripeWebhookHandler,
  feeEventData,
  productionInnerHandler,
};
