"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  PRODUCTION_WEBHOOK_URL,
  REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS,
  createDispatchSubscriptionLaunchReadinessCommands,
  dispatchSubscriptionLifecycleWebhookAssessment,
} = require("../dispatch_subscription_launch_readiness_commands");

const FieldValue = {serverTimestamp: () => "server-time"};

function fakeAdmin(initial = {}) {
  const docs = new Map(Object.entries(initial));
  let generated = 0;
  const db = {
    docs,
    collection(name) {
      return {
        doc(id) {
          return {path: `${name}/${id || `generated-${++generated}`}`};
        },
      };
    },
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        async get(ref) {
          const value = docs.get(ref.path);
          return {exists: value != null, data: () => value};
        },
        set(ref, value, options) {
          writes.push({kind: "set", ref, value, options});
        },
        create(ref, value) {
          writes.push({kind: "create", ref, value});
        },
      };
      const result = await callback(transaction);
      for (const write of writes) {
        const current = docs.get(write.ref.path) || {};
        docs.set(
            write.ref.path,
            write.options && write.options.merge ?
              {...current, ...write.value} : write.value,
        );
      }
      return result;
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = FieldValue;
  return {admin: {firestore}, db};
}

function endpoint(overrides = {}) {
  return {
    id: "we_pipebuyer_live",
    url: PRODUCTION_WEBHOOK_URL,
    status: "enabled",
    livemode: true,
    enabled_events: [...REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS],
    ...overrides,
  };
}

test("lifecycle assessment requires the exact live endpoint and all events", () => {
  const ready = dispatchSubscriptionLifecycleWebhookAssessment({
    data: [endpoint()],
  });
  assert.equal(ready.verified, true);
  assert.deepEqual(ready.missingEvents, []);

  const missing = dispatchSubscriptionLifecycleWebhookAssessment({
    data: [endpoint({enabled_events: ["invoice.paid"]})],
  });
  assert.equal(missing.verified, false);
  assert.deepEqual(missing.missingEvents, [
    "invoice.payment_failed",
    "customer.subscription.updated",
    "customer.subscription.deleted",
  ]);

  const wrongMode = dispatchSubscriptionLifecycleWebhookAssessment({
    data: [endpoint({livemode: false})],
  });
  assert.equal(wrongMode.verified, false);
});

test("provider verification records verified lifecycle readiness and audit", async () => {
  const {admin, db} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": {
      revision: 4,
      stripeMode: "production",
      stripeSubscriptionLifecycleWebhookVerified: false,
    },
  });
  const commands = createDispatchSubscriptionLaunchReadinessCommands(admin, {
    requireAdministrator: () => "admin-1",
    secretProvider: () => "sk_live_stub",
    stripeRequest: async (call) => {
      assert.equal(call.path, "/v1/webhook_endpoints?limit=100");
      assert.equal(call.method, "GET");
      return {data: [endpoint()]};
    },
  });

  const result = await commands.verifyDispatchSubscriptionLifecycleWebhook({});
  assert.equal(result.verified, true);
  assert.equal(result.revision, 5);
  assert.equal(result.stripeWebhookEndpointId, "we_pipebuyer_live");
  const readiness = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(readiness.stripeSubscriptionLifecycleWebhookVerified, true);
  assert.equal(readiness.revision, 5);
  const audit = [...db.docs.entries()].find(([key]) =>
    key.startsWith("payment_readiness_audit/"),
  );
  assert.ok(audit);
  assert.deepEqual(audit[1].missingSubscriptionLifecycleEvents, []);
});

test("provider verification records false when a required event is missing", async () => {
  const {admin, db} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": {
      revision: 8,
      stripeSubscriptionLifecycleWebhookVerified: true,
    },
  });
  const commands = createDispatchSubscriptionLaunchReadinessCommands(admin, {
    requireAdministrator: () => "admin-1",
    secretProvider: () => "sk_live_stub",
    stripeRequest: async () => ({
      data: [endpoint({
        enabled_events: REQUIRED_DISPATCH_SUBSCRIPTION_EVENTS.filter(
            (event) => event !== "invoice.payment_failed",
        ),
      })],
    }),
  });

  const result = await commands.verifyDispatchSubscriptionLifecycleWebhook({});
  assert.equal(result.verified, false);
  assert.deepEqual(result.missingEvents, ["invoice.payment_failed"]);
  const readiness = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(readiness.stripeSubscriptionLifecycleWebhookVerified, false);
});
