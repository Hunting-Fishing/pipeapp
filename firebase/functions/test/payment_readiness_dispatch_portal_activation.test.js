"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createPaymentReadinessAdmin,
} = require("../payment_readiness_admin");

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
  return {firestore, db};
}

function request() {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data: {
      confirmProduction: true,
      reason: "Enable controlled Dispatch billing only after all launch controls passed.",
      patch: {
        stripeMode: "production",
        stripeSubscriptionsEnabled: true,
        stripeSubscriptionRecoveryVerified: true,
        stripeWebhookVerified: true,
        stripeTaxReady: true,
        stripeReconciliationReady: true,
      },
    },
  };
}

function currentReadiness() {
  return {
    stripeMode: "disabled",
    stripeSubscriptionLifecycleWebhookVerified: true,
  };
}

test("Dispatch activation is blocked without an enabled reviewed Billing Portal", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /require an enabled, reviewed Stripe Billing Portal configuration/i,
  );
});

test("Dispatch activation accepts a reviewed Billing Portal prerequisite", async () => {
  const {firestore, db} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": {
      enabled: true,
      returnUrl: "https://pipebuyer.com/account/memberships",
      stripePortalConfigurationId: "bpc_dispatchlive",
    },
  });
  const commands = createPaymentReadinessAdmin({firestore});
  const result = await commands.setPaymentProviderReadiness(request());
  assert.equal(result.readiness.stripeSubscriptionsEnabled, true);
  const stored = db.docs.get(
      "platform_configuration/payment_provider_readiness",
  );
  assert.equal(stored.stripeSubscriptionsEnabled, true);
  assert.equal(stored.stripeSubscriptionLifecycleWebhookVerified, true);
  assert.equal(stored.stripeSubscriptionRecoveryVerified, true);
});
