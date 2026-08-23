"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchBillingPortalAdmin,
  normalizePortalConfig,
} = require("../dispatch_billing_portal_admin");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
} = require("../dispatch_billing_portal_policy");

function administratorRequest(data) {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data,
  };
}

function fakeAdmin(previous = {}) {
  const writes = [];
  const db = {
    collection(name) {
      return {
        doc(id = `auto-${name}`) {
          return {name, id};
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          assert.equal(ref.name, "platform_configuration");
          assert.equal(ref.id, "dispatch_billing_portal");
          return {
            exists: Object.keys(previous).length > 0,
            data: () => previous,
          };
        },
        set(ref, data, options) {
          writes.push({operation: "set", ref, data, options});
        },
        create(ref, data) {
          writes.push({operation: "create", ref, data});
        },
      });
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = {
    serverTimestamp: () => "SERVER_TIMESTAMP",
  };
  return {admin: {firestore}, writes};
}

function providerFeatures() {
  return {
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
  };
}

test("portal readiness normalization preserves current provider verification evidence", () => {
  const features = providerFeatures();
  assert.deepEqual(normalizePortalConfig({
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_1",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: features,
    revision: 4,
  }), {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_1",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: features,
    revision: 4,
  });
});

test("stale provider verification is rendered fail-closed", () => {
  const normalized = normalizePortalConfig({
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_1",
    providerVerificationRevision: "old-policy",
    revision: 4,
  });
  assert.equal(normalized.enabled, false);
  assert.equal(normalized.providerVerified, false);
});

test("manual Billing Portal enablement is rejected without provider verification", async () => {
  const {admin} = fakeAdmin();
  const commands = createDispatchBillingPortalAdmin(admin);
  await assert.rejects(
      commands.setDispatchBillingPortalReadiness(administratorRequest({
        enabled: true,
        confirmProduction: true,
        returnUrl: "https://pipebuyer.com/account",
        stripePortalConfigurationId: "bpc_live_1",
        reason: "Enable reviewed production Dispatch billing portal.",
      })),
      /server-side Stripe provider verification/i,
  );
});

test("emergency disable clears provider verification evidence", async () => {
  const {admin, writes} = fakeAdmin({
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_1",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: providerFeatures(),
    revision: 1,
  });
  const commands = createDispatchBillingPortalAdmin(admin);
  const result = await commands.setDispatchBillingPortalReadiness(
      administratorRequest({
        enabled: false,
        reason: "Emergency disable of Dispatch billing management.",
      }),
  );
  assert.equal(result.enabled, false);
  assert.equal(result.returnUrl, "");
  assert.equal(result.stripePortalConfigurationId, "");
  assert.equal(result.providerVerified, false);
  assert.equal(result.providerVerifiedConfigurationId, "");
  assert.equal(result.providerVerificationRevision, "");
  const configWrite = writes.find(
      (entry) => entry.operation === "set" &&
        entry.ref.name === "platform_configuration",
  );
  assert.equal(configWrite.data.providerVerified, false);
  assert.equal(writes.filter((entry) => entry.operation === "create").length, 1);
});
