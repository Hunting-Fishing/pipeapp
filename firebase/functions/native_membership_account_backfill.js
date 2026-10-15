"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  accountTokenDocumentId,
} = require("./apple_store_server_notifications");
const {
  normalizeAccountToken,
} = require("./apple_store_server_client");

const NATIVE_MEMBERSHIP_ACCOUNT_COLLECTION = "native_membership_accounts";
const NATIVE_MEMBERSHIP_ACCOUNT_TOKEN_COLLECTION =
  "native_membership_account_tokens";
const DEFAULT_ACCOUNT_BACKFILL_PAGE_SIZE = 200;
const DEFAULT_ACCOUNT_BACKFILL_MAX_DOCUMENTS = 50000;
const ACCOUNT_BACKFILL_WRITE_BATCH_SIZE = 200;

class NativeMembershipAccountBackfillError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "NativeMembershipAccountBackfillError";
    this.code = code;
  }
}

function normalizedPositiveInteger(value, fallback, maximum) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1) return fallback;
  return Math.min(parsed, maximum);
}

function buildNativeMembershipAccountTokenBackfillPlan(documents) {
  if (!Array.isArray(documents)) {
    throw new TypeError("Native membership account documents are invalid.");
  }
  const planByTokenHash = new Map();
  for (const document of documents) {
    const ownerUid = String(document && document.id || "").trim();
    const data = document && typeof document.data === "function" ?
      document.data() : null;
    const storeAccountToken = normalizeAccountToken(
        data && data.storeAccountToken,
    );
    if (!ownerUid || !storeAccountToken) {
      throw new NativeMembershipAccountBackfillError(
          "native_account_token_source_invalid",
          "A native membership account has no valid owner and account token.",
      );
    }
    const tokenHash = accountTokenDocumentId(storeAccountToken);
    const previous = planByTokenHash.get(tokenHash);
    if (previous && previous.ownerUid !== ownerUid) {
      throw new NativeMembershipAccountBackfillError(
          "native_account_token_collision",
          "A native membership account token maps to more than one user.",
      );
    }
    planByTokenHash.set(tokenHash, {
      tokenHash,
      ownerUid,
      storeAccountToken,
    });
  }
  return [...planByTokenHash.values()];
}

async function loadNativeMembershipAccountDocuments({
  db,
  admin,
  pageSize = DEFAULT_ACCOUNT_BACKFILL_PAGE_SIZE,
  maxDocuments = DEFAULT_ACCOUNT_BACKFILL_MAX_DOCUMENTS,
}) {
  const limit = normalizedPositiveInteger(pageSize, 200, 500);
  const maximum = normalizedPositiveInteger(maxDocuments, 50000, 100000);
  const documents = [];
  let cursor = "";
  while (true) {
    let query = db.collection(NATIVE_MEMBERSHIP_ACCOUNT_COLLECTION)
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(limit);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (documents.length + snapshot.docs.length > maximum) {
      throw new NativeMembershipAccountBackfillError(
          "native_account_backfill_limit_exceeded",
          "The native membership account backfill exceeded its reviewed limit.",
      );
    }
    documents.push(...snapshot.docs);
    if (snapshot.docs.length < limit) break;
    cursor = String(snapshot.docs.at(-1).id || "");
    if (!cursor || documents.length >= maximum) {
      throw new NativeMembershipAccountBackfillError(
          "native_account_backfill_limit_exceeded",
          "The native membership account backfill exceeded its reviewed limit.",
      );
    }
  }
  return documents;
}

function validateIndexSnapshot(snapshot, item) {
  if (!snapshot.exists) return true;
  const existing = snapshot.data() || {};
  if (String(existing.ownerUid || "") !== item.ownerUid ||
      normalizeAccountToken(existing.storeAccountToken) !== item.storeAccountToken) {
    throw new NativeMembershipAccountBackfillError(
        "native_account_token_collision",
        "A native membership account token is already assigned to another user.",
    );
  }
  return false;
}

async function preflightNativeMembershipAccountTokenIndexes({db, plan}) {
  const pending = [];
  for (let offset = 0; offset < plan.length; offset += 400) {
    const chunk = plan.slice(offset, offset + 400).map((item) => ({
      ...item,
      ref: db.collection(NATIVE_MEMBERSHIP_ACCOUNT_TOKEN_COLLECTION)
          .doc(item.tokenHash),
    }));
    const snapshots = typeof db.getAll === "function" ?
      await db.getAll(...chunk.map((item) => item.ref)) :
      await Promise.all(chunk.map((item) => item.ref.get()));
    snapshots.forEach((snapshot, index) => {
      if (validateIndexSnapshot(snapshot, chunk[index])) {
        pending.push(chunk[index]);
      }
    });
  }
  return pending;
}

async function writeNativeMembershipAccountTokenIndexes({db, admin, pending}) {
  let written = 0;
  for (let offset = 0; offset < pending.length;
    offset += ACCOUNT_BACKFILL_WRITE_BATCH_SIZE) {
    const chunk = pending.slice(offset, offset + ACCOUNT_BACKFILL_WRITE_BATCH_SIZE);
    const count = await db.runTransaction(async (transaction) => {
      const snapshots = await Promise.all(
          chunk.map((item) => transaction.get(item.ref)),
      );
      let changed = 0;
      snapshots.forEach((snapshot, index) => {
        const item = chunk[index];
        const needsWrite = validateIndexSnapshot(snapshot, item);
        if (!needsWrite) return;
        transaction.set(item.ref, {
          ownerUid: item.ownerUid,
          storeAccountToken: item.storeAccountToken,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: false});
        changed += 1;
      });
      return changed;
    });
    written += count;
  }
  return written;
}

async function backfillNativeMembershipAccountTokens({
  db,
  admin,
  dryRun = true,
  pageSize = DEFAULT_ACCOUNT_BACKFILL_PAGE_SIZE,
  maxDocuments = DEFAULT_ACCOUNT_BACKFILL_MAX_DOCUMENTS,
}) {
  if (!db || typeof db.collection !== "function" ||
      typeof db.runTransaction !== "function" ||
      !admin || !admin.firestore || !admin.firestore.FieldValue ||
      !admin.firestore.FieldPath) {
    throw new TypeError("Native membership account backfill is not configured.");
  }
  const documents = await loadNativeMembershipAccountDocuments({
    db,
    admin,
    pageSize,
    maxDocuments,
  });
  const plan = buildNativeMembershipAccountTokenBackfillPlan(documents);
  const pending = await preflightNativeMembershipAccountTokenIndexes({db, plan});
  const written = dryRun ? 0 : await writeNativeMembershipAccountTokenIndexes({
    db,
    admin,
    pending,
  });
  return {
    dryRun,
    scanned: documents.length,
    indexed: plan.length,
    pending: pending.length,
    written,
    collisionFree: true,
  };
}

function createNativeMembershipAccountBackfill(admin, {
  runBackfill = backfillNativeMembershipAccountTokens,
  logger = console,
} = {}) {
  const db = admin.firestore();
  const backfillNativeMembershipAccountTokensForAdmin = async (request) => {
    try {
      const administratorUid = requireAdministrator(request);
      const dryRun = request.data && request.data.confirmWrite === true ? false : true;
      const result = await runBackfill({db, admin, dryRun});
      logger.info("Native membership account-token backfill completed", {
        administratorUid,
        dryRun,
        scanned: result.scanned,
        pending: result.pending,
        written: result.written,
      });
      return result;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      if (error instanceof NativeMembershipAccountBackfillError) {
        throw new HttpsError("failed-precondition", error.message);
      }
      logger.error("Native membership account-token backfill failed", {
        code: String(error && error.code || "unknown").slice(0, 80),
      });
      throw new HttpsError(
          "internal",
          "The native membership account-token backfill could not finish safely.",
      );
    }
  };
  return {backfillNativeMembershipAccountTokensForAdmin};
}

module.exports = {
  ACCOUNT_BACKFILL_WRITE_BATCH_SIZE,
  DEFAULT_ACCOUNT_BACKFILL_MAX_DOCUMENTS,
  DEFAULT_ACCOUNT_BACKFILL_PAGE_SIZE,
  NATIVE_MEMBERSHIP_ACCOUNT_COLLECTION,
  NATIVE_MEMBERSHIP_ACCOUNT_TOKEN_COLLECTION,
  NativeMembershipAccountBackfillError,
  backfillNativeMembershipAccountTokens,
  buildNativeMembershipAccountTokenBackfillPlan,
  createNativeMembershipAccountBackfill,
  loadNativeMembershipAccountDocuments,
  preflightNativeMembershipAccountTokenIndexes,
  validateIndexSnapshot,
  writeNativeMembershipAccountTokenIndexes,
};
