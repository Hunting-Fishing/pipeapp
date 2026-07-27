"use strict";

const crypto = require("node:crypto");
const {AccountSecurityError} = require("./account_security");

const RATE_LIMITS = Object.freeze({
  account: 20,
  administration: 120,
  marketplace: 240,
  offers: 80,
  auctions: 180,
  dispatch: 180,
  messaging: 120,
  reporting: 20,
  media: 60,
  privacy: 10,
  support: 10,
});
const WINDOW_SECONDS = 60 * 60;

function hash(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function rateLimitSpec(scope) {
  const limit = RATE_LIMITS[scope];
  if (!Number.isInteger(limit) || limit <= 0) {
    throw new AccountSecurityError(
        "internal",
        "This protected action has no approved abuse-control policy.",
    );
  }
  return {scope, limit, windowSeconds: WINDOW_SECONDS};
}

function requestFingerprint(request, scope) {
  const route = String(
      request && request.rawRequest &&
      (request.rawRequest.path || request.rawRequest.url) || "callable",
  );
  const data = JSON.stringify(request && request.data || {});
  return hash(`${scope}|${route}|${data}`);
}

function rateLimitDocumentId(uid, scope, windowStartSeconds) {
  return hash(`${uid}|${scope}|${windowStartSeconds}`);
}

async function enforceUserRateLimit({
  db,
  admin,
  request,
  scope,
  limitOverride,
  nowMillis,
}) {
  const uid = request && request.auth && request.auth.uid;
  if (!uid) {
    throw new AccountSecurityError("unauthenticated", "Sign in to continue.");
  }
  const spec = rateLimitSpec(scope);
  const limit = limitOverride == null ? spec.limit : Number(limitOverride);
  if (!Number.isInteger(limit) || limit < 1 || limit > 1000) {
    throw new AccountSecurityError("internal", "Invalid abuse-control limit.");
  }
  const currentMillis = Number.isFinite(nowMillis) ?
    Number(nowMillis) : admin.firestore.Timestamp.now().toMillis();
  const currentSeconds = Math.floor(currentMillis / 1000);
  const windowStartSeconds = currentSeconds -
    currentSeconds % spec.windowSeconds;
  const fingerprint = requestFingerprint(request, scope);
  const reference = db.collection("security_rate_limits").doc(
      rateLimitDocumentId(uid, scope, windowStartSeconds),
  );

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const data = snapshot.exists ? snapshot.data() : {};
    const fingerprints = Array.isArray(data.requestFingerprints) ?
      data.requestFingerprints : [];
    if (fingerprints.includes(fingerprint)) {
      return {allowed: true, duplicate: true, remaining: limit - data.count};
    }
    const count = Number(data.count || 0);
    if (count >= limit) {
      throw new AccountSecurityError(
          "resource-exhausted",
          "Too many requests were made in a short period. Wait and try again.",
      );
    }
    const nextCount = count + 1;
    transaction.set(reference, {
      actorUid: uid,
      scope,
      count: nextCount,
      limit,
      windowStart: admin.firestore.Timestamp.fromMillis(
          windowStartSeconds * 1000,
      ),
      expiresAt: admin.firestore.Timestamp.fromMillis(
          (windowStartSeconds + spec.windowSeconds * 2) * 1000,
      ),
      requestFingerprints: [...fingerprints, fingerprint],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(!snapshot.exists ?
        {createdAt: admin.firestore.FieldValue.serverTimestamp()} : {}),
    }, {merge: true});
    return {allowed: true, duplicate: false, remaining: limit - nextCount};
  });
}

async function cleanupExpiredRateLimits(admin, batchLimit = 500) {
  const db = admin.firestore();
  const expired = await db.collection("security_rate_limits")
      .where("expiresAt", "<=", admin.firestore.Timestamp.now())
      .limit(batchLimit)
      .get();
  if (expired.empty) return 0;
  const batch = db.batch();
  for (const document of expired.docs) batch.delete(document.ref);
  await batch.commit();
  return expired.size;
}

module.exports = {
  RATE_LIMITS,
  cleanupExpiredRateLimits,
  enforceUserRateLimit,
  rateLimitDocumentId,
  rateLimitSpec,
  requestFingerprint,
};
