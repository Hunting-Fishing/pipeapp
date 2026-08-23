"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchBillingPortalAdmin,
  normalizePortalConfig,
} = require("../dispatch_billing_portal_admin");

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

test("portal readiness normalization preserves exact Stripe configuration identity", () => {
  assert.deepEqual(normalizePortalConfig({
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    revision: 4,
  }), {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    revision: 4,
  });
});

test("enabling Dispatch portal requires reviewed Stripe configuration identity", async () => {
  const {admin} = fakeAdmin();
  const commands = createDispatchBillingPortalAdmin(admin);
  await assert.rejects(
      commands.setDispatchBillingPortalReadiness(administratorRequest({
        enabled: true,
        confirmProduction: true,
        returnUrl: "https://pipebuyer.com/account",
        stripePortalConfigurationId: "",
        reason: "Enable reviewed production Dispatch billing portal.",
      })),
      /configuration ID is required/i,
  );
});

test("audited enable persists exact Stripe configuration and return URL", async () => {
  const {admin, writes} = fakeAdmin({revision: 2});
  const commands = createDispatchBillingPortalAdmin(admin);
  const result = await commands.setDispatchBillingPortalReadiness(
      administratorRequest({
        enabled: true,
        confirmProduction: true,
        returnUrl: "https://pipebuyer.com/account",
        stripePortalConfigurationId: "bpc_live_1",
        reason: "Enable reviewed production Dispatch billing portal.",
      }),
  );
  assert.equal(result.enabled, true);
  assert.equal(result.stripePortalConfigurationId, "bpc_live_1");
  assert.equal(result.revision, 3);
  const configWrite = writes.find(
      (entry) => entry.operation === "set" &&
        entry.ref.name === "platform_configuration",
  );
  assert.equal(configWrite.data.stripePortalConfigurationId, "bpc_live_1");
  assert.equal(configWrite.data.returnUrl, "https://pipebuyer.com/account");
  assert.equal(writes.filter((entry) => entry.operation === "create").length, 1);
});

test("emergency disable remains possible without portal configuration or return URL", async () => {
  const {admin} = fakeAdmin({
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_1",
    revision: 1,
  });
  const commands = createDispatchBillingPortalAdmin(admin);
  const result = await commands.setDispatchBillingPortalReadiness(
      administratorRequest({
        enabled: false,
        returnUrl: "",
        stripePortalConfigurationId: "",
        reason: "Emergency disable of Dispatch billing management.",
      }),
  );
  assert.equal(result.enabled, false);
  assert.equal(result.returnUrl, "");
  assert.equal(result.stripePortalConfigurationId, "");
});
