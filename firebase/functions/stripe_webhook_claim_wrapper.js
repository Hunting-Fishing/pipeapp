"use strict";

const {
  stripeWebhookClaimDecision,
} = require("./stripe_webhook_event_claim");

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
  const financialResolution = createMarketplaceFinancialResolution(admin);
  const refundGate = createMarketplaceRefundWebhookGate(
      admin,
      financialResolution,
  );
  return createStripeWebhookHandler(admin, {
    marketplaceFinancialResolution: refundGate,
  });
}

function createClaimedStripeWebhookHandler(admin, options = {}) {
  const db = admin.firestore();
  const Timestamp = admin.firestore.Timestamp;
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
    await innerHandler(request, response);
  };
}

module.exports = {
  claimStripeWebhookEvent,
  createClaimedStripeWebhookHandler,
  productionInnerHandler,
};
