"use strict";

const crypto = require("node:crypto");

const NATIVE_RECONCILIATION_CHECKPOINT_COLLECTION =
  "native_membership_reconciliation_checkpoints";
const NATIVE_RECONCILIATION_CHECKPOINT_DOCUMENT = "scheduled";
const DEFAULT_RECONCILIATION_LEASE_MILLIS = 15 * 60 * 1000;

class NativeMembershipReconciliationRunError extends Error {
  constructor(code, message, result = null) {
    super(message);
    this.name = "NativeMembershipReconciliationRunError";
    this.code = code;
    this.result = result;
  }
}

function safeErrorCode(error) {
  return String(error && error.code || "native_reconciliation_failed")
      .replace(/[^a-zA-Z0-9_.:-]/g, "_")
      .slice(0, 80);
}

function validReconciliationResult(result) {
  if (!result || typeof result !== "object" ||
      !Number.isInteger(result.checked) || result.checked < 0 ||
      !Number.isInteger(result.updated) || result.updated < 0 ||
      !Number.isInteger(result.failed) || result.failed < 0 ||
      !Number.isInteger(result.pages) || result.pages < 0 ||
      typeof result.complete !== "boolean") {
    return false;
  }
  return result.complete || String(result.nextCursor || "").trim().length > 0;
}

function createFirestoreNativeMembershipReconciliationCheckpointStore({
  db,
  admin,
  now = () => Date.now(),
  randomUUID = () => crypto.randomUUID(),
  leaseMillis = DEFAULT_RECONCILIATION_LEASE_MILLIS,
}) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function" ||
      !admin || !admin.firestore || !admin.firestore.FieldValue) {
    throw new TypeError("Native membership reconciliation checkpoint is not configured.");
  }
  const FieldValue = admin.firestore.FieldValue;
  const ref = db.collection(NATIVE_RECONCILIATION_CHECKPOINT_COLLECTION)
      .doc(NATIVE_RECONCILIATION_CHECKPOINT_DOCUMENT);

  return {
    async begin() {
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (existing.status === "processing" &&
            Number(existing.leaseExpiresAtMillis || 0) > now()) {
          return {state: "in_progress"};
        }
        const leaseId = randomUUID();
        const startCursor = String(existing.nextCursor || "");
        transaction.set(ref, {
          status: "processing",
          leaseId,
          leaseExpiresAtMillis: now() + leaseMillis,
          attemptCount: Number(existing.attemptCount || 0) + 1,
          lastStartedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          ...(snapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
        }, {merge: true});
        return {state: "acquired", leaseId, startCursor};
      });
    },

    async complete(claim, result) {
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (!claim || existing.status !== "processing" ||
            existing.leaseId !== claim.leaseId) {
          throw new NativeMembershipReconciliationRunError(
              "native_reconciliation_lease_lost",
              "The native membership reconciliation lease was lost.",
          );
        }
        const nextCursor = result.complete ? "" : String(result.nextCursor || "");
        transaction.set(ref, {
          status: result.complete ? "complete" : "pending",
          nextCursor,
          leaseId: "",
          leaseExpiresAtMillis: 0,
          lastChecked: result.checked,
          lastUpdated: result.updated,
          lastFailed: result.failed,
          lastPages: result.pages,
          lastSucceededAt: FieldValue.serverTimestamp(),
          ...(result.complete ? {lastCompletedAt: FieldValue.serverTimestamp()} : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {nextCursor, complete: result.complete};
      });
    },

    async fail(claim, error) {
      return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        const existing = snapshot.exists ? snapshot.data() : {};
        if (!claim || existing.status !== "processing" ||
            existing.leaseId !== claim.leaseId) {
          return false;
        }
        transaction.set(ref, {
          status: "failed",
          nextCursor: String(claim.startCursor || ""),
          leaseId: "",
          leaseExpiresAtMillis: 0,
          lastErrorCode: safeErrorCode(error),
          lastFailureCount: Number(error && error.result && error.result.failed || 0),
          lastFailedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return true;
      });
    },
  };
}

function createNativeMembershipReconciliationRunner({
  reconcileSubscriptions,
  checkpointStore,
  logger = console,
}) {
  if (typeof reconcileSubscriptions !== "function" ||
      !checkpointStore || typeof checkpointStore.begin !== "function" ||
      typeof checkpointStore.complete !== "function" ||
      typeof checkpointStore.fail !== "function") {
    throw new TypeError("Native membership reconciliation runner is not configured.");
  }

  return async function runNativeMembershipReconciliation() {
    const claim = await checkpointStore.begin();
    if (!claim || claim.state !== "acquired") {
      logger.info("Native membership reconciliation already in progress", {
        status: "in_progress",
      });
      return {skipped: true, reason: "in_progress"};
    }
    try {
      const result = await reconcileSubscriptions({
        startAfter: claim.startCursor,
        maxPages: 1,
      });
      if (!validReconciliationResult(result)) {
        throw new NativeMembershipReconciliationRunError(
            "native_reconciliation_result_invalid",
            "Native membership reconciliation returned an invalid checkpoint.",
        );
      }
      if (result.failed > 0) {
        throw new NativeMembershipReconciliationRunError(
            "native_reconciliation_partial_failure",
            "Native membership reconciliation left failed records for retry.",
            result,
        );
      }
      const checkpoint = await checkpointStore.complete(claim, result);
      logger.info("Native membership reconciliation checkpoint completed", {
        checked: result.checked,
        updated: result.updated,
        pages: result.pages,
        complete: result.complete,
        continuationPending: checkpoint.nextCursor.length > 0,
      });
      return {...result, skipped: false};
    } catch (error) {
      await checkpointStore.fail(claim, error);
      logger.error("Native membership reconciliation checkpoint failed", {
        code: safeErrorCode(error),
        failed: Number(error && error.result && error.result.failed || 0),
        cursorPreserved: true,
      });
      throw error;
    }
  };
}

function createNativeMembershipReconciliationComposition({
  admin,
  reconcileSubscriptions,
  logger = console,
  now,
  randomUUID,
}) {
  const db = admin.firestore();
  const checkpointStore =
    createFirestoreNativeMembershipReconciliationCheckpointStore({
      db,
      admin,
      ...(now ? {now} : {}),
      ...(randomUUID ? {randomUUID} : {}),
    });
  const run = createNativeMembershipReconciliationRunner({
    reconcileSubscriptions,
    checkpointStore,
    logger,
  });
  return Object.freeze({checkpointStore, run});
}

module.exports = {
  DEFAULT_RECONCILIATION_LEASE_MILLIS,
  NATIVE_RECONCILIATION_CHECKPOINT_COLLECTION,
  NATIVE_RECONCILIATION_CHECKPOINT_DOCUMENT,
  NativeMembershipReconciliationRunError,
  createFirestoreNativeMembershipReconciliationCheckpointStore,
  createNativeMembershipReconciliationComposition,
  createNativeMembershipReconciliationRunner,
  safeErrorCode,
  validReconciliationResult,
};
