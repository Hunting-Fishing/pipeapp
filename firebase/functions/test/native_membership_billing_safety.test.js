"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyNativeEntitlement,
  appleCurrentEntitlement,
  appleSandboxAllowedForCurrentAccount,
  appleSandboxAllowedForRequest,
  beginNativeMembershipReconciliation,
  claimNativeMembershipPurchaseIntent,
  clearExpiredNativeEntitlement,
  ensureStoreAccountToken,
  nativeBillingReadiness,
  resumableNativeMembershipIntent,
  stripeMembershipBlocksNativePurchase,
} = require("../native_membership_billing");
const {
  accountTokenDocumentId,
} = require("../apple_store_server_notifications");

test("intent recovery is exact, account-bound, and restore-controlled", () => {
  const now = Date.now();
  const token = "a".repeat(43);
  const staleLocalToken = "b".repeat(43);
  const product = {
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
  };
  const active = {
    ownerUid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: product.productId,
    planId: product.planId,
    intentToken: token,
    status: "pending",
    expiresAtMillis: now + 60_000,
  };
  const resumed = resumableNativeMembershipIntent(active, {
    uid: "user-1",
    platform: "ios",
    product,
    nowMillis: now,
  });
  assert.notEqual(resumed.intentToken, staleLocalToken);
  assert.deepEqual(resumed, {
    intentToken: token,
    ownerUid: "user-1",
    platform: "ios",
    productId: product.productId,
    restore: false,
    expiresAtMillis: now + 60_000,
  });
  assert.equal(resumableNativeMembershipIntent(active, {
    uid: "user-2",
    platform: "ios",
    product,
    nowMillis: now,
  }), null);

  const restore = {
    ...active,
    productId: "*",
    planId: "restore",
  };
  assert.equal(resumableNativeMembershipIntent(restore, {
    uid: "user-1",
    platform: "ios",
    product,
    allowRestore: false,
    nowMillis: now,
  }), null);
  assert.equal(resumableNativeMembershipIntent(restore, {
    uid: "user-1",
    platform: "ios",
    product,
    allowRestore: true,
    nowMillis: now,
  }).restore, true);
});

function reference(collection, id) {
  return {collection, id};
}

function fakeAdmin() {
  return {
    firestore: {
      Timestamp: {fromMillis: (value) => ({millis: value})},
      FieldValue: {
        serverTimestamp: () => "server-timestamp",
        delete: () => "delete-field",
      },
    },
  };
}

test("Apple Sandbox fallback requires both readiness and a tester claim", () => {
  const readiness = nativeBillingReadiness({
    enabled: true,
    appleEnabled: true,
    appleSandboxEnabled: true,
  });
  assert.equal(readiness.appleSandboxEnabled, true);
  assert.equal(appleSandboxAllowedForRequest(readiness, {}), false);
  assert.equal(appleSandboxAllowedForRequest(readiness, {
    auth: {token: {appleSandboxTester: false}},
  }), false);
  assert.equal(appleSandboxAllowedForRequest(readiness, {
    auth: {token: {appleSandboxTester: true}},
  }), true);
  assert.equal(appleSandboxAllowedForRequest(
      {...readiness, appleSandboxEnabled: false},
      {auth: {token: {appleSandboxTester: true}}},
  ), false);
});

test("Apple Sandbox fallback rechecks the current Admin Auth claim", async () => {
  const readiness = nativeBillingReadiness({
    enabled: true,
    appleEnabled: true,
    appleSandboxEnabled: true,
  });
  const request = {auth: {token: {appleSandboxTester: true}}};
  const deniedAdmin = {
    auth: () => ({getUser: async () => ({customClaims: {}})}),
  };
  assert.equal(await appleSandboxAllowedForCurrentAccount(
      deniedAdmin,
      readiness,
      request,
      "user-1",
  ), false);
  const allowedAdmin = {
    auth: () => ({
      getUser: async () => ({customClaims: {appleSandboxTester: true}}),
    }),
  };
  assert.equal(await appleSandboxAllowedForCurrentAccount(
      allowedAdmin,
      readiness,
      request,
      "user-1",
  ), true);
});

test("Apple transaction lookup cannot fall back to Sandbox without approval", async () => {
  const environments = [];
  const createServerEnvironment = (environment) => {
    environments.push(environment);
    return {
      environment,
      apiClient: {},
      verifier: {},
    };
  };
  const notFound = Object.assign(new Error("not found"), {apiError: 4040010});
  const fetchCurrentEntitlement = async ({expectedEnvironment}) => {
    if (expectedEnvironment === "Production") throw notFound;
    return {planId: "dispatch_monthly"};
  };
  await assert.rejects(() => appleCurrentEntitlement({
    transactionId: "200000000000001",
    accountToken: "123e4567-e89b-42d3-a456-426614174000",
    allowSandbox: false,
    createServerEnvironment,
    fetchCurrentEntitlement,
    transactionNotFound: (error) => error === notFound,
  }), (error) => error.code === "failed-precondition");
  assert.deepEqual(environments, ["Production"]);

  environments.length = 0;
  const entitlement = await appleCurrentEntitlement({
    transactionId: "200000000000001",
    accountToken: "123e4567-e89b-42d3-a456-426614174000",
    allowSandbox: true,
    createServerEnvironment,
    fetchCurrentEntitlement,
    transactionNotFound: (error) => error === notFound,
  });
  assert.equal(entitlement.planId, "dispatch_monthly");
  assert.deepEqual(environments, ["Production", "Sandbox"]);
});

test("native entitlement transaction rechecks active Stripe ownership", async () => {
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "dispatch_subscription_provider_state") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                subscriptionId: "sub_live_dispatch",
                providerStatus: "active",
              }),
            };
          }
          if (ref.collection === "native_membership_reconciliation_leases") {
            return {exists: true, data: () => ({generation: 1})};
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  await assert.rejects(() => applyNativeEntitlement({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
    accountToken: "123e4567-e89b-42d3-a456-426614174000",
    entitlement: {
      provider: "app_store",
      platform: "ios",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      tier: "dispatch",
      originalTransactionId: "200000000000000",
      transactionId: "200000000000001",
      expiresAtMillis: Date.now() + 3600000,
    },
    reconciliationGeneration: 1,
  }), (error) => error.code === "failed-precondition");
  assert.equal(writes.length, 0);
});

test("native preflight blocks canceled Stripe membership through paid period", async () => {
  const nowMillis = Date.now();
  assert.equal(stripeMembershipBlocksNativePurchase({
    ownerUid: "user-1",
    active: true,
    billingProvider: "stripe",
    currentPeriodEnd: nowMillis + 60_000,
  }, "user-1", nowMillis), true);
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "platform_configuration") {
            return {
              exists: true,
              data: () => ({enabled: true, appleEnabled: true}),
            };
          }
          if (ref.collection === "dispatch_subscription_provider_state") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                subscriptionId: "sub_canceled",
                providerStatus: "canceled",
              }),
            };
          }
          if (ref.collection === "dispatch_memberships") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                active: true,
                billingProvider: "stripe",
                currentPeriodEnd: nowMillis + 60_000,
              }),
            };
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  await assert.rejects(() => claimNativeMembershipPurchaseIntent({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
    platform: "ios",
    product: {
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
    },
    nowMillis,
  }), (error) => error.code === "failed-precondition");
  assert.equal(writes.length, 0);
});

test("native apply blocks canceled Stripe membership through paid period", async () => {
  const nowMillis = Date.now();
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "dispatch_subscription_provider_state") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                subscriptionId: "sub_canceled",
                providerStatus: "canceled",
              }),
            };
          }
          if (ref.collection === "dispatch_memberships") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                active: true,
                billingProvider: "stripe",
                currentPeriodEnd: nowMillis + 60_000,
              }),
            };
          }
          if (ref.collection === "native_membership_reconciliation_leases") {
            return {exists: true, data: () => ({generation: 1})};
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  await assert.rejects(() => applyNativeEntitlement({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
    accountToken: "123e4567-e89b-42d3-a456-426614174000",
    entitlement: {
      provider: "app_store",
      platform: "ios",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      tier: "dispatch",
      originalTransactionId: "200000000000000",
      transactionId: "200000000000001",
      expiresAtMillis: nowMillis + 3_600_000,
    },
    reconciliationGeneration: 1,
  }), (error) => error.code === "failed-precondition");
  assert.equal(writes.length, 0);
});

test("restore verification cannot apply across an open Stripe checkout", async () => {
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "dispatch_subscription_checkout_state") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                status: "created",
                expiresAt: Date.now() + 3600000,
              }),
            };
          }
          if (ref.collection === "native_membership_reconciliation_leases") {
            return {exists: true, data: () => ({generation: 1})};
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  await assert.rejects(() => applyNativeEntitlement({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
    accountToken: "123e4567-e89b-42d3-a456-426614174000",
    entitlement: {
      provider: "app_store",
      platform: "ios",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      tier: "dispatch",
      originalTransactionId: "200000000000000",
      transactionId: "200000000000001",
      expiresAtMillis: Date.now() + 3600000,
    },
    reconciliationGeneration: 1,
  }), (error) => error.code === "failed-precondition");
  assert.equal(writes.length, 0);
});

test("older reconciliation generation cannot overwrite a newer result", async () => {
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "native_membership_reconciliation_leases") {
            return {exists: true, data: () => ({generation: 2})};
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  await assert.rejects(() => applyNativeEntitlement({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
    accountToken: "123e4567-e89b-42d3-a456-426614174000",
    entitlement: {
      provider: "app_store",
      platform: "ios",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      tier: "dispatch",
      originalTransactionId: "200000000000000",
      transactionId: "200000000000001",
      expiresAtMillis: Date.now() + 3600000,
    },
    reconciliationGeneration: 1,
  }), (error) => error.code === "aborted");
  assert.equal(writes.length, 0);
});

test("same-original stale reconciliation cannot clear a newer renewal", async () => {
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "native_membership_provider_state") {
            return {
              exists: true,
              data: () => ({
                ownerUid: "user-1",
                active: true,
                provider: "app_store",
                providerSubscriptionKey: "app_store:200000000000000",
                originalTransactionId: "200000000000000",
                latestTransactionId: "200000000000002",
                productId: "pipebuyer_dispatch_monthly",
                planId: "dispatch_monthly",
                expiresAtMillis: 2000,
              }),
            };
          }
          if (ref.collection === "native_membership_reconciliation_leases") {
            return {exists: true, data: () => ({generation: 1})};
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  const cleared = await clearExpiredNativeEntitlement({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
    providerState: {
      ownerUid: "user-1",
      active: true,
      provider: "app_store",
      providerSubscriptionKey: "app_store:200000000000000",
      originalTransactionId: "200000000000000",
      latestTransactionId: "200000000000001",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      expiresAtMillis: 1000,
    },
    reconciliationGeneration: 1,
  });
  assert.equal(cleared, false);
  assert.equal(writes.length, 0);
});

test("reconciliation generations increase atomically per user", async () => {
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get() {
          return {exists: true, data: () => ({generation: 7})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  const generation = await beginNativeMembershipReconciliation({
    db,
    admin: fakeAdmin(),
    uid: "user-1",
  });
  assert.equal(generation, 8);
  assert.equal(writes[0][1].generation, 8);
});

test("existing account tokens get a collision-checked reverse index", async () => {
  const token = "123e4567-e89b-42d3-a456-426614174000";
  const writes = [];
  const db = {
    collection(name) {
      return {doc: (id) => reference(name, id)};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "native_membership_accounts") {
            return {
              exists: true,
              data: () => ({ownerUid: "user-1", storeAccountToken: token}),
            };
          }
          return {exists: false, data: () => ({})};
        },
        set(...args) {
          writes.push(args);
        },
      });
    },
  };
  const result = await ensureStoreAccountToken(db, fakeAdmin(), "user-1");
  assert.equal(result, token);
  assert.equal(writes.length, 1);
  assert.deepEqual(writes[0][0], reference(
      "native_membership_account_tokens",
      accountTokenDocumentId(token),
  ));
  assert.equal(writes[0][1].ownerUid, "user-1");
});
