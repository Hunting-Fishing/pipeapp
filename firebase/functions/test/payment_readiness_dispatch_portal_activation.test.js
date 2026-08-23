"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createPaymentReadinessAdmin,
} = require("../payment_readiness_admin");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
} = require("../dispatch_billing_portal_policy");

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

function enabledFeatures(overrides = {}) {
  return {
    dispatch: true,
    paidFeatures: true,
    ...overrides,
  };
}

function verifiedPortal(overrides = {}) {
  return {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account/memberships",
    stripePortalConfigurationId: "bpc_dispatchlive",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_dispatchlive",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: {
      paymentMethodUpdate: true,
      customerUpdate: true,
      customerUpdateAllowedUpdates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
      invoiceHistory: true,
      subscriptionCancel: true,
      subscriptionCancelMode: "at_period_end",
      subscriptionCancelProration: "none",
      subscriptionUpdate: true,
      subscriptionUpdateAllowedUpdates: ["price"],
      subscriptionUpdateProration: "none",
      subscriptionUpdateProductId: DISPATCH_PORTAL_PRODUCT_ID,
      subscriptionUpdatePriceIds: [...DISPATCH_PORTAL_PRICE_IDS],
    },
    ...overrides,
  };
}

test("Dispatch activation is blocked without an enabled provider-verified Billing Portal", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/phase1_features": enabledFeatures(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /require an enabled, provider-verified Stripe Billing Portal configuration/i,
  );
});

test("bpc-shaped identity without provider proof cannot authorize Dispatch activation", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": verifiedPortal({
      providerVerified: false,
    }),
    "platform_configuration/phase1_features": enabledFeatures(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /provider-verified Stripe Billing Portal configuration/i,
  );
});

test("provider proof must be bound to the exact current bpc identity", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": verifiedPortal({
      providerVerifiedConfigurationId: "bpc_otherlive",
    }),
    "platform_configuration/phase1_features": enabledFeatures(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /provider-verified Stripe Billing Portal configuration/i,
  );
});

test("missing stored provider features cannot authorize Dispatch activation", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": verifiedPortal({
      providerVerifiedFeatures: {},
    }),
    "platform_configuration/phase1_features": enabledFeatures(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /provider-verified Stripe Billing Portal configuration/i,
  );
});

test("quantity-changing Portal proof cannot authorize Dispatch activation", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": verifiedPortal({
      providerVerifiedFeatures: {
        ...verifiedPortal().providerVerifiedFeatures,
        subscriptionUpdateAllowedUpdates: ["price", "quantity"],
      },
    }),
    "platform_configuration/phase1_features": enabledFeatures(),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /provider-verified Stripe Billing Portal configuration/i,
  );
});

test("Dispatch activation is blocked when paidFeatures or Dispatch is off", async () => {
  const {firestore} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": verifiedPortal(),
    "platform_configuration/phase1_features": enabledFeatures({paidFeatures: false}),
  });
  const commands = createPaymentReadinessAdmin({firestore});
  await assert.rejects(
      () => commands.setPaymentProviderReadiness(request()),
      /Dispatch and paidFeatures feature flags/i,
  );
});

test("Dispatch activation accepts exact Portal proof and enabled feature flags", async () => {
  const {firestore, db} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": currentReadiness(),
    "platform_configuration/dispatch_billing_portal": verifiedPortal(),
    "platform_configuration/phase1_features": enabledFeatures(),
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
