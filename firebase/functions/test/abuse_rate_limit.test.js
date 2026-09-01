"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  RATE_LIMITS,
  enforceUserRateLimit,
  rateLimitDocumentId,
  rateLimitSpec,
  requestFingerprint,
} = require("../abuse_rate_limit");

function fakeAdmin() {
  class Timestamp {
    constructor(milliseconds) {
      this.milliseconds = milliseconds;
    }

    toMillis() {
      return this.milliseconds;
    }

    static fromMillis(milliseconds) {
      return new Timestamp(milliseconds);
    }

    static now() {
      return new Timestamp(Date.now());
    }
  }
  return {
    firestore: {
      Timestamp,
      FieldValue: {serverTimestamp: () => ({serverTimestamp: true})},
    },
  };
}

class SerializedTransactionDb {
  constructor() {
    this.value = null;
    this.queue = Promise.resolve();
  }

  collection(name) {
    return {doc: (id) => ({name, id})};
  }

  runTransaction(callback) {
    const operation = this.queue.then(async () => {
      const snapshotValue = this.value == null ? null : structuredClone(
          this.value,
      );
      const transaction = {
        get: async () => ({
          exists: snapshotValue != null,
          data: () => snapshotValue,
        }),
        set: (_reference, value) => {
          this.value = {...(this.value || {}), ...value};
        },
      };
      return callback(transaction);
    });
    this.queue = operation.catch(() => undefined);
    return operation;
  }
}

test("every protected command group has a bounded hourly policy", () => {
  assert.deepEqual(Object.keys(RATE_LIMITS).sort(), [
    "account", "administration", "auctions", "directory", "dispatch",
    "marketplace", "media",
    "messaging", "offers", "privacy", "reporting", "support",
  ]);
  for (const scope of Object.keys(RATE_LIMITS)) {
    const policy = rateLimitSpec(scope);
    assert.equal(policy.windowSeconds, 3600);
    assert.ok(policy.limit > 0 && policy.limit <= 1000);
  }
});

test("rate documents and request fingerprints are private deterministic hashes", () => {
  const documentId = rateLimitDocumentId("user-123", "offers", 123456);
  assert.equal(documentId.length, 64);
  assert.equal(documentId.includes("user-123"), false);
  const request = {
    data: {requestId: "retry-1", listingId: "listing-1"},
    rawRequest: {path: "/createMarketplaceOffer"},
  };
  assert.equal(
      requestFingerprint(request, "offers"),
      requestFingerprint(request, "offers"),
  );
  assert.notEqual(
      requestFingerprint(request, "offers"),
      requestFingerprint({...request, data: {...request.data, requestId: "2"}},
          "offers"),
  );
});

test("concurrent unique requests cannot oversubscribe a quota", async () => {
  const db = new SerializedTransactionDb();
  const admin = fakeAdmin();
  const attempts = Array.from({length: 64}, (_, index) =>
    enforceUserRateLimit({
      db,
      admin,
      request: {
        auth: {uid: "load-test-user"},
        data: {requestId: `request-${index}`},
        rawRequest: {path: "/load-test"},
      },
      scope: "offers",
      limitOverride: 20,
      nowMillis: 1_800_000,
    }));

  const results = await Promise.allSettled(attempts);
  assert.equal(results.filter((result) => result.status === "fulfilled").length,
      20);
  assert.equal(results.filter((result) =>
    result.status === "rejected" &&
      result.reason.code === "resource-exhausted").length, 44);
  assert.equal(db.value.count, 20);
  assert.equal(db.value.requestFingerprints.length, 20);
});

test("concurrent retries consume one quota unit", async () => {
  const db = new SerializedTransactionDb();
  const admin = fakeAdmin();
  const request = {
    auth: {uid: "retry-test-user"},
    data: {requestId: "same-request"},
    rawRequest: {path: "/retry-test"},
  };
  const results = await Promise.all(Array.from({length: 50}, () =>
    enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "support",
      limitOverride: 3,
      nowMillis: 1_800_000,
    })));

  assert.equal(results.filter((result) => result.duplicate === false).length, 1);
  assert.equal(results.filter((result) => result.duplicate === true).length, 49);
  assert.equal(db.value.count, 1);
  assert.equal(db.value.requestFingerprints.length, 1);
});
