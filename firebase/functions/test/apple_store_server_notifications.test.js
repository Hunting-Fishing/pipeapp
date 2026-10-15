"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  AppStoreNotificationError,
  createAppStoreServerNotificationHttpHandler,
  createAppStoreServerNotificationProcessor,
  createFirestoreNotificationEventStore,
  notificationDocumentId,
} = require("../apple_store_server_notifications");
const {APPLE_BUNDLE_ID} = require("../native_membership_policy");

const accountToken = "123e4567-e89b-42d3-a456-426614174000";
const originalTransactionId = "200000000000000";
const notificationUUID = "b0cc3a12-3af3-47b8-8f21-65d058759c8e";

function createMemoryEventStore() {
  const events = new Map();
  return {
    events,
    beginCount: 0,
    async begin(event) {
      this.beginCount += 1;
      const existing = events.get(event.notificationUUID);
      if (existing && new Set(["processed", "ignored"]).has(existing.status)) {
        return {state: "duplicate"};
      }
      events.set(event.notificationUUID, {status: "processing"});
      return {state: "acquired"};
    },
    async complete(uuid, outcome) {
      events.set(uuid, outcome);
    },
    async fail(uuid, error) {
      events.set(uuid, {status: "failed", code: error.code});
    },
  };
}

function notification(overrides = {}) {
  return {
    notificationType: "DID_RENEW",
    notificationUUID,
    data: {
      environment: "Sandbox",
      bundleId: APPLE_BUNDLE_ID,
      signedTransactionInfo: "signed-transaction",
    },
    ...overrides,
  };
}

function transaction(overrides = {}) {
  return {
    environment: "Sandbox",
    bundleId: APPLE_BUNDLE_ID,
    appAccountToken: accountToken,
    productId: "pipebuyer_dispatch_monthly",
    originalTransactionId,
    transactionId: "200000000000001",
    ...overrides,
  };
}

function processorFixture(overrides = {}) {
  const eventStore = overrides.eventStore || createMemoryEventStore();
  const applied = [];
  const cleared = [];
  const verifier = overrides.verifier || {
    async verifyAndDecodeNotification() {
      return notification();
    },
    async verifyAndDecodeTransaction() {
      return transaction();
    },
  };
  const processNotification = createAppStoreServerNotificationProcessor({
    expectedEnvironment: "Sandbox",
    verifier,
    eventStore,
    resolveOwnerByAccountToken: overrides.resolveOwnerByAccountToken ||
      (async () => "user-1"),
    authorizeOwnerForEnvironment: overrides.authorizeOwnerForEnvironment ||
      (async () => true),
    beginReconciliation: overrides.beginReconciliation || (async () => 1),
    loadProviderState: overrides.loadProviderState || (async () => ({
      ownerUid: "user-1",
      provider: "app_store",
      originalTransactionId,
      latestTransactionId: "200000000000001",
      planId: "dispatch_monthly",
    })),
    reconcileSubscription: overrides.reconcileSubscription || (async () => ({
      provider: "app_store",
      originalTransactionId,
      planId: "dispatch_monthly",
      tier: "dispatch",
      productId: "pipebuyer_dispatch_monthly",
      expiresAtMillis: Date.now() + 3600000,
    })),
    applyNativeEntitlement: overrides.applyNativeEntitlement ||
      (async (value) => applied.push(value)),
    clearExpiredNativeEntitlement: overrides.clearExpiredNativeEntitlement ||
      (async (value) => cleared.push(value)),
  });
  return {applied, cleared, eventStore, processNotification};
}

test("notification document IDs are deterministic and do not expose UUIDs", () => {
  const id = notificationDocumentId(notificationUUID);
  assert.match(id, /^[0-9a-f]{64}$/);
  assert.equal(id, notificationDocumentId(notificationUUID.toUpperCase()));
  assert.equal(id.includes(notificationUUID.slice(0, 8)), false);
});

test("Firestore idempotency completion requires the acquired lease", async () => {
  const documents = new Map();
  const db = {
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
          return {exists: Boolean(value), data: () => value};
        },
        set(ref, value) {
          documents.set(ref.key, {...documents.get(ref.key), ...value});
        },
      });
    },
  };
  const store = createFirestoreNotificationEventStore({
    db,
    admin: {firestore: {FieldValue: {serverTimestamp: () => "timestamp"}}},
    now: () => 1000,
  });
  const claim = await store.begin({
    notificationUUID,
    notificationType: "TEST",
    environment: "Sandbox",
  });
  assert.equal(claim.state, "acquired");
  await assert.rejects(
      store.complete(notificationUUID, {status: "processed"}, {leaseId: "wrong"}),
      (error) => error.code === "notification_lease_lost",
  );
  await store.complete(notificationUUID, {status: "processed"}, claim);
  assert.equal((await store.begin({notificationUUID})).state, "duplicate");
});

test("verified lifecycle notification reconciles before applying entitlement", async () => {
  const calls = [];
  const fixture = processorFixture({
    reconcileSubscription: async (value) => {
      calls.push(value);
      return {
        provider: "app_store",
        originalTransactionId,
        planId: "dispatch_monthly",
        tier: "dispatch",
        productId: "pipebuyer_dispatch_monthly",
        expiresAtMillis: Date.now() + 3600000,
      };
    },
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "entitlement_applied");
  assert.equal(calls[0].originalTransactionId, originalTransactionId);
  assert.equal(fixture.applied[0].uid, "user-1");
  assert.equal(fixture.applied[0].accountToken, accountToken);
  assert.equal(fixture.applied[0].reconciliationGeneration, 1);
  assert.equal(fixture.cleared.length, 0);
});

test("notification idempotency prevents a duplicate entitlement mutation", async () => {
  const fixture = processorFixture();
  await fixture.processNotification("signed-notification");
  const duplicate = await fixture.processNotification("signed-notification");
  assert.equal(duplicate.status, "duplicate");
  assert.equal(fixture.applied.length, 1);
});

test("current inactive subscription clears only matching App Store state", async () => {
  const fixture = processorFixture({
    reconcileSubscription: async () => null,
    verifier: {
      async verifyAndDecodeNotification() {
        return notification({notificationType: "REFUND"});
      },
      async verifyAndDecodeTransaction() {
        return transaction();
      },
    },
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "entitlement_cleared");
  assert.equal(fixture.cleared[0].terminalStatus, "refunded");
  assert.equal(fixture.applied.length, 0);
});

test("authoritative inactive status clears a missed newer local renewal safely", async () => {
  const fixture = processorFixture({
    reconcileSubscription: async () => null,
    loadProviderState: async () => ({
      ownerUid: "user-1",
      provider: "app_store",
      originalTransactionId,
      latestTransactionId: "200000000000099",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      expiresAtMillis: Date.now() - 1,
    }),
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "entitlement_cleared");
  assert.equal(fixture.cleared.length, 1);
  assert.equal(
      fixture.cleared[0].providerState.latestTransactionId,
      "200000000000099",
  );
});

test("inactive event cannot clear a different provider or original transaction", async () => {
  const fixture = processorFixture({
    reconcileSubscription: async () => null,
    loadProviderState: async () => ({
      ownerUid: "user-1",
      provider: "google_play",
      originalTransactionId,
    }),
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "no_matching_entitlement");
  assert.equal(fixture.cleared.length, 0);
});

test("lost provider compare-and-set preserves a newer entitlement", async () => {
  const fixture = processorFixture({
    reconcileSubscription: async () => null,
    clearExpiredNativeEntitlement: async () => false,
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "stale_entitlement_preserved");
  assert.equal(result.status, "ignored");
});

test("unconfigured Apple VIP product is verified then ignored", async () => {
  const fixture = processorFixture({
    verifier: {
      async verifyAndDecodeNotification() {
        return notification();
      },
      async verifyAndDecodeTransaction() {
        return transaction({productId: "pipebuyer_vip_monthly"});
      },
    },
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "product_not_configured");
  assert.equal(fixture.applied.length, 0);
  assert.equal(fixture.cleared.length, 0);
});

test("test notifications verify without mutating membership", async () => {
  const fixture = processorFixture({
    verifier: {
      async verifyAndDecodeNotification() {
        return notification({notificationType: "TEST", data: {}});
      },
      async verifyAndDecodeTransaction() {
        throw new Error("transaction verifier should not be called");
      },
    },
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "test_verified");
  assert.equal(fixture.applied.length, 0);
  assert.equal(fixture.cleared.length, 0);
});

test("unverified outer payload cannot reserve an idempotency record", async () => {
  const eventStore = createMemoryEventStore();
  const fixture = processorFixture({
    eventStore,
    verifier: {
      async verifyAndDecodeNotification() {
        throw new Error("bad signature");
      },
      async verifyAndDecodeTransaction() {
        throw new Error("not reached");
      },
    },
  });
  await assert.rejects(
      fixture.processNotification("forged-notification"),
      /bad signature/,
  );
  assert.equal(eventStore.beginCount, 0);
  assert.equal(eventStore.events.size, 0);
});

test("missing account mapping fails retryably after recording failure", async () => {
  const fixture = processorFixture({
    resolveOwnerByAccountToken: async () => "",
  });
  await assert.rejects(
      fixture.processNotification("signed-notification"),
      (error) => error instanceof AppStoreNotificationError &&
        error.code === "notification_account_not_found" && error.retryable,
  );
  assert.equal(fixture.eventStore.events.get(notificationUUID).status, "failed");
});

test("Sandbox notification cannot mutate an unauthorized account", async () => {
  const fixture = processorFixture({
    authorizeOwnerForEnvironment: async () => false,
  });
  const result = await fixture.processNotification("signed-notification");
  assert.equal(result.outcome, "environment_owner_not_authorized");
  assert.equal(fixture.applied.length, 0);
  assert.equal(fixture.cleared.length, 0);
});

function fakeHttpResponse() {
  return {
    statusCode: 0,
    headers: {},
    body: null,
    set(name, value) {
      this.headers[name] = value;
    },
    status(value) {
      this.statusCode = value;
      return this;
    },
    send(value) {
      this.body = value;
      return this;
    },
  };
}

test("notification HTTP handler rejects invalid input and retries unknown failures", async () => {
  const invalidHandler = createAppStoreServerNotificationHttpHandler({
    processNotification: async () => ({status: "processed"}),
  });
  const invalidResponse = fakeHttpResponse();
  await invalidHandler({method: "GET", body: {}}, invalidResponse);
  assert.equal(invalidResponse.statusCode, 405);

  const failureHandler = createAppStoreServerNotificationHttpHandler({
    processNotification: async () => {
      throw new Error("database unavailable");
    },
    verificationError: () => false,
  });
  const failureResponse = fakeHttpResponse();
  await failureHandler({
    method: "POST",
    body: {signedPayload: "x".repeat(64)},
  }, failureResponse);
  assert.equal(failureResponse.statusCode, 500);
  assert.equal(failureResponse.body.code, "notification_processing_failed");
});
