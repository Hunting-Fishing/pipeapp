"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  APPLE_IAP_SECRET_NAMES,
  APPLE_PRODUCTION_NOTIFICATION_GATE_FIELD,
  APPLE_SANDBOX_NOTIFICATION_GATE_FIELD,
  appleNotificationMutationEnabled,
  createAppleProductionServerNotificationComposition,
  createAppleSandboxServerNotificationComposition,
} = require("../apple_native_billing_composition");

function configurationDb(configuration) {
  return {
    collection() {
      return {
        doc() {
          return {
            async get() {
              return {
                exists: configuration != null,
                data: () => configuration || {},
              };
            },
          };
        },
      };
    },
    async runTransaction(callback) {
      return callback({});
    },
  };
}

function fakeAdmin(db) {
  function firestore() {
    return db;
  }
  firestore.FieldValue = {serverTimestamp: () => "timestamp"};
  firestore.Timestamp = {fromMillis: (value) => ({millis: value})};
  return {
    firestore,
    auth: () => ({
      async getUser() {
        return {customClaims: {appleSandboxTester: true}};
      },
    }),
  };
}

test("notification mutation gates are explicit and environment-specific", async () => {
  const base = {enabled: true, appleEnabled: true, appleSandboxEnabled: true};
  assert.equal(await appleNotificationMutationEnabled({
    db: configurationDb({
      ...base,
      [APPLE_PRODUCTION_NOTIFICATION_GATE_FIELD]: true,
    }),
    environment: "Production",
  }), true);
  assert.equal(await appleNotificationMutationEnabled({
    db: configurationDb({
      ...base,
      [APPLE_SANDBOX_NOTIFICATION_GATE_FIELD]: true,
    }),
    environment: "Production",
  }), false);
  assert.equal(await appleNotificationMutationEnabled({
    db: configurationDb({
      ...base,
      [APPLE_SANDBOX_NOTIFICATION_GATE_FIELD]: true,
    }),
    environment: "Sandbox",
  }), true);
  assert.equal(await appleNotificationMutationEnabled({
    db: configurationDb({
      enabled: true,
      appleEnabled: true,
      appleSandboxEnabled: false,
      [APPLE_SANDBOX_NOTIFICATION_GATE_FIELD]: true,
    }),
    environment: "Sandbox",
  }), false);
});

test("Sandbox and Production compositions bind exact environments and IAP secrets", () => {
  const db = configurationDb({});
  const admin = fakeAdmin(db);
  const calls = [];
  const createServerEnvironment = (input) => {
    calls.push(input);
    return {
      apiClient: {getAllSubscriptionStatuses: async () => ({})},
      verifier: {
        verifyAndDecodeNotification: async () => ({}),
        verifyAndDecodeTransaction: async () => ({}),
      },
    };
  };
  const options = {
    admin,
    credentials: {
      privateKey: "private-key",
      keyId: "key-id",
      issuerId: "issuer-id",
    },
    createServerEnvironment,
  };
  const sandbox = createAppleSandboxServerNotificationComposition(options);
  const production = createAppleProductionServerNotificationComposition(options);
  assert.deepEqual(calls.map((call) => call.environment), ["Sandbox", "Production"]);
  assert.equal(sandbox.environment, "Sandbox");
  assert.equal(production.environment, "Production");
  assert.equal(typeof sandbox.processNotification, "function");
  assert.equal(typeof production.httpHandler, "function");
  assert.deepEqual(APPLE_IAP_SECRET_NAMES, [
    "APPLE_IAP_PRIVATE_KEY",
    "APPLE_IAP_KEY_ID",
    "APPLE_IAP_ISSUER_ID",
  ]);
  assert.deepEqual(production.secretNames, APPLE_IAP_SECRET_NAMES);
});

test("production bootstrap does not import or export activation composition", () => {
  const bootstrap = fs.readFileSync(
      path.resolve(__dirname, "..", "production_bootstrap.js"),
      "utf8",
  );
  assert.doesNotMatch(bootstrap, /apple_native_billing_composition/);
  assert.doesNotMatch(bootstrap, /appStoreServerNotifications/);
  assert.doesNotMatch(bootstrap, /backfillNativeMembershipAccountTokensForAdmin/);
});
