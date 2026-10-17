"use strict";

const crypto = require("node:crypto");

const DEFAULT_STRIPE_WEBHOOK_LEASE_MILLIS = 5 * 60 * 1000;

class StripeWebhookEventLeaseError extends Error {
  constructor(message) {
    super(message);
    this.name = "StripeWebhookEventLeaseError";
    this.code = "stripe_webhook_lease_lost";
  }
}

function safeEventText(value, maximumLength = 160) {
  return String(value || "")
      .replace(/[^a-zA-Z0-9_.:-]/g, "_")
      .slice(0, maximumLength);
}

function createStripeWebhookEventStore({
  db,
  admin,
  now = () => Date.now(),
  leaseMillis = DEFAULT_STRIPE_WEBHOOK_LEASE_MILLIS,
} = {}) {
  if (!db || typeof db.runTransaction !== "function" ||
      !admin || !admin.firestore || !admin.firestore.FieldValue) {
    throw new TypeError("Stripe webhook event storage is not configured.");
  }
  if (!Number.isFinite(leaseMillis) || leaseMillis < 1000) {
    throw new RangeError("Stripe webhook processing lease is too short.");
  }
  const FieldValue = admin.firestore.FieldValue;

  function reference(eventId) {
    return db.collection("stripe_webhook_events").doc(eventId);
  }

  return {
    async begin({eventId, type}) {
      const ref = reference(eventId);
      const leaseId = crypto.randomUUID();
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        const status = String(existing.status || "");
        if (status === "processed") return {state: "duplicate"};
        if (status === "processing" &&
            Number(existing.leaseExpiresAtMillis || 0) > now()) {
          return {state: "in_progress"};
        }
        transaction.set(ref, {
          eventId,
          type: safeEventText(type),
          status: "processing",
          leaseId,
          leaseExpiresAtMillis: now() + leaseMillis,
          attemptCount: Math.max(0, Number(existing.attemptCount || 0)) + 1,
          updatedAt: FieldValue.serverTimestamp(),
          ...(snapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        }, {merge: true});
        return {state: "acquired", leaseId};
      });
    },

    async complete(eventId, claim) {
      const ref = reference(eventId);
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (existing.status !== "processing" || !claim ||
            existing.leaseId !== claim.leaseId) {
          throw new StripeWebhookEventLeaseError(
              "The Stripe webhook processing lease was lost.",
          );
        }
        transaction.set(ref, {
          status: "processed",
          leaseId: "",
          leaseExpiresAtMillis: 0,
          processedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
    },

    async fail(eventId, error, claim) {
      const ref = reference(eventId);
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (existing.status !== "processing" || !claim ||
            existing.leaseId !== claim.leaseId) return;
        transaction.set(ref, {
          status: "failed",
          leaseId: "",
          leaseExpiresAtMillis: 0,
          lastErrorCode: safeEventText(
              error && error.code || error && error.name || "processing_failed",
          ),
          lastFailedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
    },
  };
}

module.exports = {
  DEFAULT_STRIPE_WEBHOOK_LEASE_MILLIS,
  StripeWebhookEventLeaseError,
  createStripeWebhookEventStore,
  safeEventText,
};
