"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
} = require("../dispatch_billing_portal_policy");
const {
  createDispatchBillingPortalVerificationCommands,
} = require("../dispatch_billing_portal_verification_commands");

const FieldValue = {serverTimestamp: () => "SERVER_TIMESTAMP"};

function request(overrides = {}) {
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
      stripePortalConfigurationId: "bpc_live_dispatch",
      returnUrl: "https://pipebuyer.com/account",
      confirmProduction: true,
      reason: "Verify the reviewed live Dispatch Billing Portal configuration.",
      ...overrides,
    },
  };
}

function reviewedProviderConfiguration(overrides = {}) {
  return {
    id: "bpc_live_dispatch",
    livemode: true,
    active: true,
    features: {
      payment_method_update: {enabled: true},
      invoice_history: {enabled: true},
      subscription_cancel: {
        enabled: true,
        mode: "at_period_end",
        proration_behavior: "none",
      },
      subscription_update: {enabled: false},
    },
    ...overrides,
  };
}

function fakeAdmin(previous = {}) {
  const docs = new Map(Object.entries(previous));
  const writes = [];
  let generated = 0;
  const db = {
    docs,
    collection(name) {
      return {
        doc(id) {
          return {
            path: `${name}/${id || `generated-${++generated}`}`,
          };
        },
      };
    },
    async runTransaction(callback) {
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
        if (write.kind !== "set") continue;
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
  return {admin: {firestore}, db, writes};
}

test("provider verifier enables only the exact launch-safe live Portal configuration", async () => {
  const providerCalls = [];
  const {admin, db, writes} = fakeAdmin({
    "platform_configuration/dispatch_billing_portal": {revision: 2},
  });
  const commands = createDispatchBillingPortalVerificationCommands(admin, {
    secretProvider: () => "sk_live_stub",
    stripeRequest: async (call) => {
      providerCalls.push(call);
      return reviewedProviderConfiguration();
    },
  });

  const result = await commands.verifyDispatchBillingPortalConfiguration(request());
  assert.equal(providerCalls.length, 1);
  assert.equal(providerCalls[0].method, "GET");
  assert.match(providerCalls[0].path, /bpc_live_dispatch$/u);
  assert.equal(result.enabled, true);
  assert.equal(result.providerVerified, true);
  assert.equal(
      result.providerVerificationRevision,
      DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  );
  assert.equal(result.providerVerifiedConfigurationId, "bpc_live_dispatch");
  assert.equal(result.providerVerifiedFeatures.paymentMethodUpdate, true);
  assert.equal(result.providerVerifiedFeatures.invoiceHistory, true);
  assert.equal(result.providerVerifiedFeatures.subscriptionCancelMode, "at_period_end");
  assert.equal(result.providerVerifiedFeatures.subscriptionUpdate, false);

  const stored = db.docs.get("platform_configuration/dispatch_billing_portal");
  assert.equal(stored.enabled, true);
  assert.equal(stored.stripePortalConfigurationId, "bpc_live_dispatch");
  assert.equal(stored.providerVerified, true);
  assert.equal(stored.revision, 3);
  assert.equal(writes.filter((entry) => entry.kind === "create").length, 1);
});

test("provider verifier rejects Portal price switching and does not enable readiness", async () => {
  const {admin, db} = fakeAdmin();
  const commands = createDispatchBillingPortalVerificationCommands(admin, {
    secretProvider: () => "sk_live_stub",
    stripeRequest: async () => reviewedProviderConfiguration({
      features: {
        payment_method_update: {enabled: true},
        invoice_history: {enabled: true},
        subscription_cancel: {
          enabled: true,
          mode: "at_period_end",
          proration_behavior: "none",
        },
        subscription_update: {enabled: true},
      },
    }),
  });

  await assert.rejects(
      () => commands.verifyDispatchBillingPortalConfiguration(request()),
      /subscription_update_disabled/u,
  );
  assert.equal(
      db.docs.has("platform_configuration/dispatch_billing_portal"),
      false,
  );
});

test("provider verifier rejects immediate cancellation or non-live configuration", async () => {
  const {admin} = fakeAdmin();
  const commands = createDispatchBillingPortalVerificationCommands(admin, {
    secretProvider: () => "sk_live_stub",
    stripeRequest: async () => reviewedProviderConfiguration({
      livemode: false,
      features: {
        payment_method_update: {enabled: true},
        invoice_history: {enabled: true},
        subscription_cancel: {
          enabled: true,
          mode: "immediately",
          proration_behavior: "create_prorations",
        },
        subscription_update: {enabled: false},
      },
    }),
  });

  await assert.rejects(
      () => commands.verifyDispatchBillingPortalConfiguration(request()),
      /livemode.*subscription_cancel_mode.*subscription_cancel_proration/u,
  );
});
