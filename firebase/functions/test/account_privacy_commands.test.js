"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  accountDeviceDocumentId,
  createAccountPrivacyCommands,
  deletionRequestCanBeClaimed,
  normalizeExportValue,
  requireAppleDeletionAuthorization,
} = require("../account_privacy_commands");

test("account device document ids do not expose their source values", () => {
  const id = accountDeviceDocumentId(
      "user-123",
      "a1b2c3d4-1111-4222-8333-1234567890ab",
  );
  assert.match(id, /^[a-f0-9]{64}$/);
  assert.equal(id.includes("user-123"), false);
  assert.equal(id.includes("a1b2c3d4"), false);
});

test("account exports normalize timestamps, locations, and nested values", () => {
  const timestamp = { toDate: () => new Date("2026-07-23T01:02:03.000Z") };
  const normalized = normalizeExportValue({
    createdAt: timestamp,
    location: { latitude: 55.17, longitude: -118.79 },
    values: [timestamp, true, 42],
  });
  assert.deepEqual(normalized, {
    createdAt: "2026-07-23T01:02:03.000Z",
    location: { latitude: 55.17, longitude: -118.79 },
    values: ["2026-07-23T01:02:03.000Z", true, 42],
  });
});

test("Apple deletion authorization requires a fresh reauthentication token", () => {
  const authorization = {
    ownerUid: "user-123",
    authorizationId: "12345678-1234-1234-1234-1234567890ab",
    status: "pending_apple_revocation",
    initialAuthTimeSeconds: 100,
    expiresAt: {toMillis: () => 20_000},
  };
  assert.doesNotThrow(() => requireAppleDeletionAuthorization({
    authorization,
    authorizationId: authorization.authorizationId,
    authTimeSeconds: 101,
    nowMillis: 10_000,
    uid: "user-123",
  }));
  assert.throws(
      () => requireAppleDeletionAuthorization({
        authorization,
        authorizationId: authorization.authorizationId,
        authTimeSeconds: 100,
        nowMillis: 10_000,
        uid: "user-123",
      }),
      /Reauthenticate with Apple/,
  );
  assert.throws(
      () => requireAppleDeletionAuthorization({
        authorization,
        authorizationId: authorization.authorizationId,
        authTimeSeconds: 101,
        nowMillis: 20_000,
        uid: "user-123",
      }),
      /expired/,
  );
});

test("deletion claims are due once and processing leases prevent overlap", () => {
  const due = {toMillis: () => 1_000};
  const future = {toMillis: () => 3_000};
  assert.equal(deletionRequestCanBeClaimed({
    status: "scheduled",
    deleteAt: due,
  }, 2_000), true);
  assert.equal(deletionRequestCanBeClaimed({
    status: "scheduled",
    deleteAt: future,
  }, 2_000), false);
  assert.equal(deletionRequestCanBeClaimed({
    status: "processing",
    deleteAt: due,
    processingLeaseExpiresAt: future,
  }, 2_000), false);
  assert.equal(deletionRequestCanBeClaimed({
    status: "processing",
    deleteAt: due,
    processingLeaseExpiresAt: due,
  }, 2_000), true);
  assert.equal(deletionRequestCanBeClaimed({
    status: "cancelled",
    deleteAt: due,
  }, 2_000), false);
});

test("expired Apple deletion authorizations are bounded and removed", async () => {
  const now = {seconds: 1_000};
  const documents = [{ref: {path: "account_deletion_authorizations/user-123"}}];
  const removed = [];
  const db = {
    collection: (name) => {
      assert.equal(name, "account_deletion_authorizations");
      return {
        where: (field, operator, value) => {
          assert.deepEqual([field, operator, value], ["expiresAt", "<=", now]);
          return {
            limit: (limit) => {
              assert.equal(limit, 25);
              return {get: async () => ({docs: documents, size: documents.length})};
            },
          };
        },
      };
    },
    recursiveDelete: async (reference) => removed.push(reference.path),
  };
  const firestore = () => db;
  firestore.FieldValue = {};
  firestore.Timestamp = {now: () => now};
  const commands = createAccountPrivacyCommands({firestore});

  assert.equal(
      await commands.cleanupExpiredAccountDeletionAuthorizations(25),
      1,
  );
  assert.deepEqual(removed, ["account_deletion_authorizations/user-123"]);
});

test("account finalization and the scheduler remove Apple authorizations", () => {
  const commandsSource = fs.readFileSync(
      path.join(__dirname, "..", "account_privacy_commands.js"),
      "utf8",
  );
  assert.match(
      commandsSource,
      /recursiveDelete\(\s*db\.collection\("account_deletion_authorizations"\)\.doc\(uid\)/,
  );
  const indexSource = fs.readFileSync(
      path.join(__dirname, "..", "index.js"),
      "utf8",
  );
  assert.match(
      indexSource,
      /exports\.cleanupExpiredAccountDeletionAuthorizations = onSchedule/,
  );
});
