"use strict";

const {FieldPath} = require("firebase-admin/firestore");
const {
  YellowPagesError,
  jsonSafe,
} = require("./yellow_pages_commands");
const {text} = require("./yellow_pages_policy");

const PUBLIC_ENTRIES = "yellow_pages_public_entries";
const MAX_SCAN_BATCHES = 4;
const SCAN_BATCH_SIZE = 100;

function pageSize(value, fallback = 40) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(1, Math.min(80, Math.trunc(number)));
}

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function isPublicEntryCurrent(entry, nowMillis = Date.now()) {
  if (!entry || typeof entry !== "object") return false;
  if (entry.verified !== true) return false;
  if (entry.nonExpiringPaid === true) return true;
  const paidThrough = timestampMillis(entry.paidThrough);
  return paidThrough != null && paidThrough > nowMillis;
}

async function listCurrentPublicEntries(db, data) {
  const limit = pageSize(data && data.pageSize, 40);
  let cursor = text(data && data.cursor, 200);
  const entries = [];
  let hasMore = true;
  let lastScannedId = cursor || null;

  for (let batchIndex = 0;
    batchIndex < MAX_SCAN_BATCHES && entries.length < limit && hasMore;
    batchIndex += 1) {
    let query = db.collection(PUBLIC_ENTRIES)
        .orderBy(FieldPath.documentId())
        .limit(SCAN_BATCH_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    hasMore = snapshot.docs.length === SCAN_BATCH_SIZE;
    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    for (const doc of snapshot.docs) {
      lastScannedId = doc.id;
      cursor = doc.id;
      const entry = doc.data() || {};
      if (!isPublicEntryCurrent(entry)) continue;
      entries.push({id: doc.id, ...jsonSafe(entry)});
      if (entries.length >= limit) break;
    }
  }

  return {
    entries,
    nextCursor: hasMore && lastScannedId ? lastScannedId : null,
  };
}

async function getCurrentPublicEntry(db, data) {
  const companyId = text(data && data.companyId, 200);
  if (!companyId) {
    throw new YellowPagesError("invalid-argument", "A company ID is required.");
  }
  const snapshot = await db.collection(PUBLIC_ENTRIES).doc(companyId).get();
  if (!snapshot.exists || !isPublicEntryCurrent(snapshot.data() || {})) {
    throw new YellowPagesError("not-found", "Yellow Pages listing not found.");
  }
  return {id: snapshot.id, ...jsonSafe(snapshot.data())};
}

module.exports = {
  getCurrentPublicEntry,
  isPublicEntryCurrent,
  listCurrentPublicEntries,
};
