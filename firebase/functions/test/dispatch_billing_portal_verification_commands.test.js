"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
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
      customer_update: {
        enabled: true,
        allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
      },
      invoice_history: {enabled: true},
      subscription_cancel: {
        enabled: true,
        mode: "at_period_end",
        proration_behavior: "none",
      },
      subscription_update: {
        enabled: true,
        default_allowed_updates: ["price"],
        proration_behavior: "none",
        trial_update_behavior: "continue_trial",
        schedule_at_period_end: {conditions: []},
        products: [{
          product: DISPATCH_PORTAL_PRODUCT_ID,
          prices: [...DISPATCH_PORTAL_PRICE_IDS],
        }],
      },
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
          return {path: `${name}/${id || `generated-${++generated}`}`};
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
        docs.set(write.ref.path, write.options && write.options.merge ?
          {...current, ...write.value} : write.value);
      }
      return result;
    },
  };
  function firestore() { return db; }
  firestore.FieldValue = FieldValue;
  return {admin: {firestore}, db, writes};
}

test("provider verifier enables only the exact trial-safe live Portal configuration", async () => {
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
  assert.equal(result.enabled, true);
  assert.equal(result.providerVerificationRevision, DISPATCH_BILLING_PORTAL_PROVIDER_REVISION);
  assert.equal(result.providerVerifiedFeatures.subscriptionUpdateProration, "none");
  assert.equal(result.providerVerifiedFeatures.subscriptionUpdateTrialBehavior, "continue_trial");
  assert.deepEqual(result.providerVerifiedFeatures.subscriptionUpdateScheduleAtPeriodEndConditions, []);
  assert.deepEqual(result.providerVerifiedFeatures.subscriptionUpdateAllowedUpdates, ["price"]);
  assert.equal(result.providerVerifiedFeatures.subscriptionUpdateProductId, DISPATCH_PORTAL_PRODUCT_ID);
  assert.deepEqual(result.providerVerifiedFeatures.subscriptionUpdatePriceIds, [...DISPATCH_PORTAL_PRICE_IDS]);
  const stored = db.docs.get("platform_configuration/dispatch_billing_portal");
  assert.equal(stored.enabled, true);
  assert.equal(stored.revision, 3);
  assert.equal(writes.filter((entry) => entry.kind === "create").length, 1);
});

test("provider verifier rejects trial-ending updates or scheduled downgrades", async () => {
  const {admin, db} = fakeAdmin();
  const commands = createDispatchBillingPortalVerificationCommands(admin, {
    secretProvider: () => "sk_live_stub",
    stripeRequest: async () => reviewedProviderConfiguration({
      features: {
        payment_method_update: {enabled: true},
        customer_update: {
          enabled: true,
          allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
        },
        invoice_history: {enabled: true},
        subscription_cancel: {
          enabled: true,
          mode: "at_period_end",
          proration_behavior: "none",
        },
        subscription_update: {
          enabled: true,
          default_allowed_updates: ["price"],
          proration_behavior: "none",
          trial_update_behavior: "end_trial",
          schedule_at_period_end: {
            conditions: [{type: "shortening_interval"}],
          },
          products: [{
            product: DISPATCH_PORTAL_PRODUCT_ID,
            prices: [...DISPATCH_PORTAL_PRICE_IDS],
          }],
        },
      },
    }),
  });
  await assert.rejects(
      () => commands.verifyDispatchBillingPortalConfiguration(request()),
      /subscription_update_trial_behavior.*subscription_update_schedule/u,
  );
  assert.equal(db.docs.has("platform_configuration/dispatch_billing_portal"), false);
});

test("provider verifier rejects quantity switching or an unreviewed product", async () => {
  const {admin, db} = fakeAdmin();
  const commands = createDispatchBillingPortalVerificationCommands(admin, {
    secretProvider: () => "sk_live_stub",
    stripeRequest: async () => reviewedProviderConfiguration({
      features: {
        payment_method_update: {enabled: true},
        customer_update: {enabled: true, allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES]},
        invoice_history: {enabled: true},
        subscription_cancel: {enabled: true, mode: "at_period_end", proration_behavior: "none"},
        subscription_update: {
          enabled: true,
          default_allowed_updates: ["price", "quantity"],
          proration_behavior: "none",
          trial_update_behavior: "continue_trial",
          schedule_at_period_end: {conditions: []},
          products: [{product: "prod_unreviewed", prices: ["price_unreviewed"]}],
        },
      },
    }),
  });
  await assert.rejects(
      () => commands.verifyDispatchBillingPortalConfiguration(request()),
      /subscription_update_fields.*subscription_update_products/u,
  );
  assert.equal(db.docs.has("platform_configuration/dispatch_billing_portal"), false);
});
