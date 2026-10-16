"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");

const MEMBERSHIP_BILLING_INTENT_COLLECTION = "membership_billing_intents";
// Ask to Buy approvals can arrive asynchronously for up to 24 hours. Keep the
// cross-provider reservation beyond that window so a later Apple approval
// cannot race a Stripe checkout that started after a short local timeout.
const NATIVE_PURCHASE_INTENT_TTL_MS = 26 * 60 * 60 * 1000;
const NATIVE_PURCHASE_PENDING_TTL_MS = 26 * 60 * 60 * 1000;
const NATIVE_RESTORE_INTENT_TTL_MS = 10 * 60 * 1000;
const NATIVE_PURCHASE_VERIFY_TTL_MS = 5 * 60 * 1000;
const NATIVE_PURCHASE_COMPLETED_REPLAY_TTL_MS = 7 * 24 * 60 * 60 * 1000;
const STRIPE_CHECKOUT_INTENT_TTL_MS = 24 * 60 * 60 * 1000;
const MAX_BILLING_INTENT_TTL_MS = Math.max(
    NATIVE_PURCHASE_INTENT_TTL_MS,
    STRIPE_CHECKOUT_INTENT_TTL_MS,
);
const BLOCKING_INTENT_STATUSES = new Set(["active", "pending", "verifying"]);

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : 0;
}

function nativeBillingIntentCoordinationEnabled(value) {
  const config = value || {};
  return config.enabled === true &&
    (config.appleEnabled === true || config.googleEnabled === true);
}

function validIntentToken(value) {
  return /^[A-Za-z0-9_-]{43}$/.test(String(value || ""));
}

function billingIntentActive(intent, uid, nowMillis = Date.now()) {
  if (!intent || intent.ownerUid !== uid ||
      !BLOCKING_INTENT_STATUSES.has(String(intent.status || ""))) {
    return false;
  }
  return timestampMillis(intent.expiresAtMillis || intent.expiresAt) > nowMillis;
}

function billingIntentMatches(intent, {
  uid,
  channel,
  platform,
  productId,
  planId,
  intentToken = "",
}, nowMillis = Date.now()) {
  if (!billingIntentActive(intent, uid, nowMillis)) return false;
  if (String(intent.channel || "") !== channel ||
      String(intent.platform || "") !== platform ||
      String(intent.productId || "") !== productId ||
      String(intent.planId || "") !== planId) {
    return false;
  }
  return !intentToken ||
    (validIntentToken(intentToken) && intent.intentToken === intentToken);
}

function billingIntentMatchesForVerification(
    intent,
    expected,
    nowMillis = Date.now(),
) {
  if (billingIntentMatches(intent, expected, nowMillis)) return true;
  if (!intent || intent.ownerUid !== expected.uid ||
      !new Set(["completed", "verifying"]).has(String(intent.status || "")) ||
      timestampMillis(intent.replayUntilMillis || intent.replayUntil) <= nowMillis) {
    return false;
  }
  return String(intent.channel || "") === expected.channel &&
    String(intent.platform || "") === expected.platform &&
    String(intent.productId || "") === expected.productId &&
    String(intent.planId || "") === expected.planId &&
    validIntentToken(expected.intentToken) &&
    intent.intentToken === expected.intentToken;
}

function claimBillingIntentInTransaction({
  transaction,
  intentRef,
  intentSnapshot,
  admin,
  uid,
  channel,
  platform,
  productId,
  planId,
  nowMillis = Date.now(),
  ttlMillis,
  sandboxAllowed = false,
  requireSandboxAllowedAtClaim = false,
}) {
  const existing = intentSnapshot.exists ? intentSnapshot.data() : null;
  if (billingIntentActive(existing, uid, nowMillis)) {
    if (!billingIntentMatches(existing, {
      uid,
      channel,
      platform,
      productId,
      planId,
    }, nowMillis)) {
      throw new HttpsError(
          "failed-precondition",
          "Another membership billing attempt is already in progress.",
      );
    }
    if (!validIntentToken(existing.intentToken)) {
      throw new HttpsError(
          "failed-precondition",
          "The existing membership billing attempt cannot be resumed safely.",
      );
    }
    if (requireSandboxAllowedAtClaim &&
        existing.sandboxAllowedAtClaim !== true) {
      throw new HttpsError(
          "failed-precondition",
          "Start this Apple Sandbox purchase again before continuing.",
      );
    }
    return {
      intentToken: existing.intentToken,
      expiresAtMillis: timestampMillis(
          existing.expiresAtMillis || existing.expiresAt,
      ),
      reused: true,
    };
  }

  const boundedTtl = Number(ttlMillis);
  if (!Number.isSafeInteger(boundedTtl) || boundedTtl < 60 * 1000 ||
      boundedTtl > MAX_BILLING_INTENT_TTL_MS) {
    throw new TypeError("Membership billing intent TTL is invalid.");
  }
  if (requireSandboxAllowedAtClaim &&
      (channel !== "app_store" || sandboxAllowed !== true)) {
    throw new HttpsError(
        "failed-precondition",
        "Apple Sandbox access must be verified before starting this purchase.",
    );
  }
  const intentToken = crypto.randomBytes(32).toString("base64url");
  const expiresAtMillis = nowMillis + boundedTtl;
  transaction.set(intentRef, {
    ownerUid: uid,
    channel,
    platform,
    productId,
    planId,
    intentToken,
    status: "active",
    sandboxAllowedAtClaim: channel === "app_store" && sandboxAllowed === true,
    expiresAtMillis,
    expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMillis),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(intentSnapshot.exists ? {
      replayUntilMillis: admin.firestore.FieldValue.delete(),
      replayUntil: admin.firestore.FieldValue.delete(),
      completedAt: admin.firestore.FieldValue.delete(),
      pendingAt: admin.firestore.FieldValue.delete(),
      verificationStartedAt: admin.firestore.FieldValue.delete(),
      releasedAt: admin.firestore.FieldValue.delete(),
    } : {createdAt: admin.firestore.FieldValue.serverTimestamp()}),
  }, {merge: true});
  return {intentToken, expiresAtMillis, reused: false};
}

function markBillingIntentPendingInTransaction({
  transaction,
  intentRef,
  intentSnapshot,
  admin,
  expected,
  requireSandboxAllowedAtClaim = false,
  nowMillis = Date.now(),
}) {
  const intent = intentSnapshot.exists ? intentSnapshot.data() : null;
  requireBillingIntent(intent, expected, nowMillis);
  if (requireSandboxAllowedAtClaim &&
      intent.sandboxAllowedAtClaim !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Start this Apple Sandbox purchase again before continuing.",
    );
  }
  if (String(intent.channel || "") === "stripe") {
    throw new HttpsError(
        "failed-precondition",
        "Only a mobile store purchase can be marked pending.",
    );
  }
  const existingExpiresAtMillis = timestampMillis(
      intent.expiresAtMillis || intent.expiresAt,
  );
  const pendingAlreadyRecorded = String(intent.status || "") === "pending" ||
    timestampMillis(intent.pendingAt) > 0;
  if (pendingAlreadyRecorded) {
    return {...intent, status: "pending", expiresAtMillis: existingExpiresAtMillis};
  }
  const expiresAtMillis = Math.max(
      existingExpiresAtMillis,
      nowMillis + NATIVE_PURCHASE_PENDING_TTL_MS,
  );
  transaction.set(intentRef, {
    status: "pending",
    expiresAtMillis,
    expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMillis),
    pendingAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {...intent, status: "pending", expiresAtMillis};
}

function requireBillingIntent(intent, expected, nowMillis = Date.now()) {
  if (!billingIntentMatches(intent, expected, nowMillis)) {
    throw new HttpsError(
        "failed-precondition",
        "Start this membership purchase again before verifying it.",
    );
  }
  return intent;
}

function requireBillingIntentForVerification(
    intent,
    expected,
    nowMillis = Date.now(),
) {
  if (!billingIntentMatchesForVerification(intent, expected, nowMillis)) {
    throw new HttpsError(
        "failed-precondition",
        "Start this membership purchase again before verifying it.",
    );
  }
  return intent;
}

function markBillingIntentVerifyingInTransaction({
  transaction,
  intentRef,
  intentSnapshot,
  admin,
  expected,
  allowCompletedReplay = false,
  nowMillis = Date.now(),
}) {
  const intent = intentSnapshot.exists ? intentSnapshot.data() : null;
  if (allowCompletedReplay) {
    requireBillingIntentForVerification(intent, expected, nowMillis);
  } else {
    requireBillingIntent(intent, expected, nowMillis);
  }
  const expiresAtMillis = Math.max(
      timestampMillis(intent.expiresAtMillis || intent.expiresAt),
      nowMillis + NATIVE_PURCHASE_VERIFY_TTL_MS,
  );
  transaction.set(intentRef, {
    status: "verifying",
    expiresAtMillis,
    expiresAt: admin.firestore.Timestamp.fromMillis(expiresAtMillis),
    verificationStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return intent;
}

async function finishBillingIntent({
  db,
  admin,
  uid,
  intentToken,
  status,
}) {
  if (!validIntentToken(intentToken) ||
      !new Set(["completed", "released"]).has(status)) {
    return false;
  }
  const intentRef = db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION).doc(uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(intentRef);
    if (!snapshot.exists) return false;
    const intent = snapshot.data();
    if (intent.ownerUid !== uid || intent.intentToken !== intentToken ||
        !BLOCKING_INTENT_STATUSES.has(String(intent.status || ""))) {
      return false;
    }
    transaction.set(intentRef, {
      status,
      expiresAtMillis: Date.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now()),
      ...(status === "completed" ? {
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        replayUntilMillis: Date.now() + NATIVE_PURCHASE_COMPLETED_REPLAY_TTL_MS,
        replayUntil: admin.firestore.Timestamp.fromMillis(
            Date.now() + NATIVE_PURCHASE_COMPLETED_REPLAY_TTL_MS,
        ),
      } : {
        releasedAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

async function failStripeCheckoutReservation({
  db,
  admin,
  uid,
  stateRef,
  attemptNumber,
  intentToken = "",
  failureCode = "stripe_checkout_failed",
}) {
  const expectedAttempt = Number(attemptNumber);
  if (!Number.isSafeInteger(expectedAttempt) || expectedAttempt < 1) {
    return false;
  }
  const expectedIntentToken = String(intentToken || "");
  if (expectedIntentToken && !validIntentToken(expectedIntentToken)) {
    return false;
  }
  const intentRef = db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION).doc(uid);
  return db.runTransaction(async (transaction) => {
    const [stateSnapshot, intentSnapshot] = await Promise.all([
      transaction.get(stateRef),
      transaction.get(intentRef),
    ]);
    if (!stateSnapshot.exists) return false;
    const state = stateSnapshot.data();
    if (state.ownerUid !== uid || state.status !== "creating" ||
        Number(state.attemptNumber || 0) !== expectedAttempt) {
      return false;
    }
    let releaseIntent = false;
    if (expectedIntentToken) {
      if (!intentSnapshot.exists) return false;
      const intent = intentSnapshot.data();
      if (intent.ownerUid !== uid || intent.channel !== "stripe" ||
          intent.intentToken !== expectedIntentToken ||
          !BLOCKING_INTENT_STATUSES.has(String(intent.status || ""))) {
        return false;
      }
      releaseIntent = true;
    }
    const nowMillis = Date.now();
    transaction.set(stateRef, {
      status: "failed",
      failureCode: String(failureCode || "stripe_checkout_failed").slice(0, 80),
      leaseExpiresAt: admin.firestore.FieldValue.delete(),
      expiresAt: admin.firestore.Timestamp.fromMillis(nowMillis),
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    if (releaseIntent) {
      transaction.set(intentRef, {
        status: "released",
        expiresAtMillis: nowMillis,
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMillis),
        releasedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  });
}

async function makeStripeCheckoutReservationRetryable({
  db,
  admin,
  uid,
  stateRef,
  attemptNumber,
  intentToken = "",
  failureCode = "stripe_checkout_ambiguous",
}) {
  const expectedAttempt = Number(attemptNumber);
  if (!Number.isSafeInteger(expectedAttempt) || expectedAttempt < 1) {
    return false;
  }
  const expectedIntentToken = String(intentToken || "");
  if (expectedIntentToken && !validIntentToken(expectedIntentToken)) {
    return false;
  }
  const intentRef = db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION).doc(uid);
  return db.runTransaction(async (transaction) => {
    const [stateSnapshot, intentSnapshot] = await Promise.all([
      transaction.get(stateRef),
      transaction.get(intentRef),
    ]);
    if (!stateSnapshot.exists) return false;
    const state = stateSnapshot.data();
    if (state.ownerUid !== uid || state.status !== "creating" ||
        Number(state.attemptNumber || 0) !== expectedAttempt) {
      return false;
    }
    if (expectedIntentToken) {
      if (!intentSnapshot.exists) return false;
      const intent = intentSnapshot.data();
      if (intent.ownerUid !== uid || intent.channel !== "stripe" ||
          intent.intentToken !== expectedIntentToken ||
          !BLOCKING_INTENT_STATUSES.has(String(intent.status || ""))) {
        return false;
      }
    }
    transaction.set(stateRef, {
      failureCode: String(failureCode || "stripe_checkout_ambiguous").slice(0, 80),
      // The next caller reuses the same attempt number and Stripe idempotency
      // key. Do not release the cross-channel intent for an indeterminate POST.
      leaseExpiresAt: admin.firestore.Timestamp.fromMillis(Date.now()),
      retryableAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

function stripeCheckoutStateOpen(state, uid, nowMillis = Date.now()) {
  if (!state || state.ownerUid !== uid ||
      !new Set(["creating", "created"]).has(String(state.status || ""))) {
    return false;
  }
  return timestampMillis(state.expiresAt) > nowMillis;
}

module.exports = {
  BLOCKING_INTENT_STATUSES,
  MEMBERSHIP_BILLING_INTENT_COLLECTION,
  NATIVE_PURCHASE_INTENT_TTL_MS,
  NATIVE_PURCHASE_COMPLETED_REPLAY_TTL_MS,
  NATIVE_PURCHASE_PENDING_TTL_MS,
  NATIVE_RESTORE_INTENT_TTL_MS,
  NATIVE_PURCHASE_VERIFY_TTL_MS,
  STRIPE_CHECKOUT_INTENT_TTL_MS,
  billingIntentActive,
  billingIntentMatches,
  billingIntentMatchesForVerification,
  claimBillingIntentInTransaction,
  failStripeCheckoutReservation,
  finishBillingIntent,
  markBillingIntentPendingInTransaction,
  markBillingIntentVerifyingInTransaction,
  makeStripeCheckoutReservationRetryable,
  nativeBillingIntentCoordinationEnabled,
  requireBillingIntent,
  requireBillingIntentForVerification,
  stripeCheckoutStateOpen,
  timestampMillis,
  validIntentToken,
};
