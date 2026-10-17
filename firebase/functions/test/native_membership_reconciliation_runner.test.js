"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  NATIVE_RECONCILIATION_CHECKPOINT_COLLECTION,
  NATIVE_RECONCILIATION_CHECKPOINT_DOCUMENT,
  NativeMembershipReconciliationRunError,
  createFirestoreNativeMembershipReconciliationCheckpointStore,
  createNativeMembershipReconciliationRunner,
} = require("../native_membership_reconciliation_runner");

function memoryFirestore(initial = {}) {
  const documents = new Map(Object.entries(initial));
  return {
    documents,
    collection(name) {
      return {
        doc(id) {
          return {key: `${name}/${id}`};
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          const value = documents.get(ref.key);
          return {exists: value != null, data: () => value};
        },
        set(ref, value, options) {
          const previous = options && options.merge ? documents.get(ref.key) || {} : {};
          documents.set(ref.key, {...previous, ...value});
        },
      });
    },
  };
}

const firestoreAdmin = {
  firestore: {
    FieldValue: {serverTimestamp: () => "timestamp"},
  },
};

function checkpointKey() {
  return `${NATIVE_RECONCILIATION_CHECKPOINT_COLLECTION}/` +
    NATIVE_RECONCILIATION_CHECKPOINT_DOCUMENT;
}

test("scheduled reconciliation persists one successful page per invocation", async () => {
  const db = memoryFirestore();
  let lease = 0;
  const checkpointStore =
    createFirestoreNativeMembershipReconciliationCheckpointStore({
      db,
      admin: firestoreAdmin,
      now: () => 1000,
      randomUUID: () => `lease-${++lease}`,
    });
  const cursors = [];
  const results = [
    {checked: 200, updated: 200, failed: 0, pages: 1,
      complete: false, nextCursor: "user-0200"},
    {checked: 200, updated: 200, failed: 0, pages: 1,
      complete: false, nextCursor: "user-0400"},
    {checked: 50, updated: 50, failed: 0, pages: 1,
      complete: true, nextCursor: ""},
  ];
  const run = createNativeMembershipReconciliationRunner({
    reconcileSubscriptions: async ({startAfter, maxPages}) => {
      cursors.push({startAfter, maxPages});
      return results.shift();
    },
    checkpointStore,
    logger: {info() {}, error() {}},
  });
  await run();
  assert.equal(db.documents.get(checkpointKey()).nextCursor, "user-0200");
  await run();
  assert.equal(db.documents.get(checkpointKey()).nextCursor, "user-0400");
  await run();
  assert.equal(db.documents.get(checkpointKey()).nextCursor, "");
  assert.equal(db.documents.get(checkpointKey()).status, "complete");
  assert.deepEqual(cursors, [
    {startAfter: "", maxPages: 1},
    {startAfter: "user-0200", maxPages: 1},
    {startAfter: "user-0400", maxPages: 1},
  ]);
});

test("failed reconciliation preserves its starting cursor and signals failure", async () => {
  const db = memoryFirestore({
    [checkpointKey()]: {status: "pending", nextCursor: "user-0200"},
  });
  const checkpointStore =
    createFirestoreNativeMembershipReconciliationCheckpointStore({
      db,
      admin: firestoreAdmin,
      now: () => 2000,
      randomUUID: () => "lease-failure",
    });
  const logs = [];
  const run = createNativeMembershipReconciliationRunner({
    reconcileSubscriptions: async () => ({
      checked: 200,
      updated: 199,
      failed: 1,
      pages: 1,
      complete: false,
      nextCursor: "user-0400",
    }),
    checkpointStore,
    logger: {info() {}, error: (...values) => logs.push(values)},
  });
  await assert.rejects(
      run(),
      (error) => error instanceof NativeMembershipReconciliationRunError &&
        error.code === "native_reconciliation_partial_failure",
  );
  const checkpoint = db.documents.get(checkpointKey());
  assert.equal(checkpoint.status, "failed");
  assert.equal(checkpoint.nextCursor, "user-0200");
  assert.equal(checkpoint.lastFailureCount, 1);
  assert.equal(logs.length, 1);
  assert.equal(logs[0][1].cursorPreserved, true);
});

test("active reconciliation lease prevents overlapping work", async () => {
  const db = memoryFirestore({
    [checkpointKey()]: {
      status: "processing",
      nextCursor: "user-0200",
      leaseId: "other-run",
      leaseExpiresAtMillis: 9000,
    },
  });
  const checkpointStore =
    createFirestoreNativeMembershipReconciliationCheckpointStore({
      db,
      admin: firestoreAdmin,
      now: () => 2000,
    });
  let called = false;
  const run = createNativeMembershipReconciliationRunner({
    reconcileSubscriptions: async () => {
      called = true;
      return {};
    },
    checkpointStore,
    logger: {info() {}, error() {}},
  });
  assert.deepEqual(await run(), {skipped: true, reason: "in_progress"});
  assert.equal(called, false);
});
