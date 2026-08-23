"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionPortalCommands,
} = require("../dispatch_subscription_portal_commands");

function fakeAdmin({config = {}, state = {}} = {}) {
  const db = {
    collection(name) {
      return {
        doc(id) {
          return {
            async get() {
              if (name === "platform_configuration" &&
                  id === "dispatch_billing_portal") {
                return {exists: true, data: () => config};
              }
              if (name === "dispatch_subscriptions") {
                return {exists: true, data: () => state};
              }
              throw new Error(`Unexpected document ${name}/${id}`);
            },
          };
        },
      };
    },
  };
  function firestore() {
    return db;
  }
  return {firestore};
}

const validConfig = Object.freeze({
  enabled: true,
  returnUrl: "https://pipebuyer.com/account",
  stripePortalConfigurationId: "bpc_live_1",
});
const validState = Object.freeze({
  stripeCustomerId: "cus_live_1",
  stripeSubscriptionId: "sub_live_1",
  reviewRequired: false,
});

test("Dispatch portal session explicitly uses the audited Stripe configuration", async () => {
  let requestArgs = null;
  const commands = createDispatchSubscriptionPortalCommands(
      fakeAdmin({config: validConfig, state: validState}),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        secretProvider: () => "sk_test_injected",
        stripeRequest: async (args) => {
          requestArgs = args;
          return {url: "https://billing.stripe.com/p/session/test_1"};
        },
      },
  );

  const result = await commands.createDispatchBillingPortalSession({data: {}});
  assert.equal(result.portalUrl, "https://billing.stripe.com/p/session/test_1");
  assert.equal(requestArgs.path, "/v1/billing_portal/sessions");
  assert.equal(requestArgs.fields.customer, "cus_live_1");
  assert.equal(requestArgs.fields.configuration, "bpc_live_1");
  assert.equal(requestArgs.fields.return_url, "https://pipebuyer.com/account");
});

test("missing reviewed Stripe Portal configuration fails before provider call", async () => {
  let providerCalls = 0;
  const commands = createDispatchSubscriptionPortalCommands(
      fakeAdmin({
        config: {...validConfig, stripePortalConfigurationId: ""},
        state: validState,
      }),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        secretProvider: () => "sk_test_injected",
        stripeRequest: async () => {
          providerCalls += 1;
          return {};
        },
      },
  );

  await assert.rejects(
      commands.createDispatchBillingPortalSession({data: {}}),
      /not available/i,
  );
  assert.equal(providerCalls, 0);
});

test("portal session rejects non-Stripe billing host returned by provider", async () => {
  const commands = createDispatchSubscriptionPortalCommands(
      fakeAdmin({config: validConfig, state: validState}),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        secretProvider: () => "sk_test_injected",
        stripeRequest: async () => ({url: "https://example.com/session"}),
      },
  );

  await assert.rejects(
      commands.createDispatchBillingPortalSession({data: {}}),
      /valid billing management link/i,
  );
});
