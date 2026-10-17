"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
  STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
  createStripeAccountsV2WebhookHandler,
  stripeAccountIdFromThinEvent,
  stripeContextFromThinEvent,
  stripeAccountsV2WebhookSecretForMode,
  stripeAccountsV2WebhookSecretNames,
} = require("../stripe_accounts_v2_webhook");
const {createMemoryAdmin} = require("./memory_firestore");

function thinAccountEvent(overrides = {}) {
  return {
    id: "evt_test_accounts_v2_1",
    object: "v2.core.event",
    type:
      "v2.core.account[configuration.recipient].capability_status_updated",
    livemode: false,
    created: "2026-10-17T01:00:00.000Z",
    context: "acct_platform_context",
    related_object: {
      id: "acct_recipient_1",
      type: "v2.core.account",
      url: "/v2/core/accounts/acct_recipient_1",
    },
    ...overrides,
  };
}

function recipientAccount() {
  return {
    id: "acct_recipient_1",
    object: "v2.core.account",
    livemode: false,
    applied_configurations: ["recipient"],
    dashboard: "express",
    defaults: {
      responsibilities: {
        fees_collector: "application",
        losses_collector: "application",
      },
    },
    configuration: {
      recipient: {
        capabilities: {
          stripe_balance: {
            payouts: {status: "active", status_details: []},
            stripe_transfers: {status: "active", status_details: []},
          },
        },
      },
    },
  };
}

function sign(rawBody, secret, timestamp) {
  return crypto.createHmac("sha256", secret)
      .update(`${timestamp}.${rawBody.toString("utf8")}`)
      .digest("hex");
}

async function deliver(handler, event, secret) {
  const rawBody = Buffer.from(JSON.stringify(event));
  const timestamp = Math.floor(Date.now() / 1000);
  const result = {statusCode: null, body: null};
  await handler({
    rawBody,
    get: () => `t=${timestamp},v1=${sign(rawBody, secret, timestamp)}`,
  }, {
    status(code) {
      result.statusCode = code;
      return this;
    },
    send(body) {
      result.body = body;
      return this;
    },
  });
  return result;
}

test("Accounts v2 thin event validates its related account reference", () => {
  assert.equal(
      stripeAccountIdFromThinEvent(thinAccountEvent()),
      "acct_recipient_1",
  );
  assert.equal(
      stripeContextFromThinEvent(thinAccountEvent()),
      "acct_platform_context",
  );
  assert.equal(
      stripeContextFromThinEvent(thinAccountEvent({context: null})),
      null,
  );
  assert.throws(
      () => stripeContextFromThinEvent(thinAccountEvent({context: "bad\nvalue"})),
      /context is invalid/u,
  );
  assert.throws(
      () => stripeAccountIdFromThinEvent(thinAccountEvent({
        related_object: {
          id: "acct_recipient_1",
          type: "v2.core.account",
          url: "/v2/core/accounts/acct_other",
        },
      })),
      /related account is invalid/u,
  );
  assert.equal(
      STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
      "STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION",
  );
  assert.equal(
      STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
      "STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX",
  );
  assert.equal(
      stripeAccountsV2WebhookSecretForMode("production").name,
      STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
  );
  assert.equal(
      stripeAccountsV2WebhookSecretForMode("sandbox").name,
      STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
  );
  assert.deepEqual(stripeAccountsV2WebhookSecretNames, [
    STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_PRODUCTION_NAME,
    STRIPE_ACCOUNTS_V2_WEBHOOK_SECRET_SANDBOX_NAME,
  ]);
});

test("thin event without data.object fetches authoritative v2 payout state", async () => {
  const memory = createMemoryAdmin({
    "payment_provider_accounts/seller-1": {
      stripeAccountId: "acct_recipient_1",
      connectAccountApiVersion: "v2",
      connectAccountObject: "v2.core.account",
      mode: "sandbox",
      transferStatus: "pending",
      payoutStatus: "pending",
      payoutReady: false,
    },
  });
  const secret = "whsec_accounts_v2_sandbox";
  let request = null;
  const handler = createStripeAccountsV2WebhookHandler(memory.admin, {
    webhookSecretForMode: (mode) => {
      assert.equal(mode, "sandbox");
      return secret;
    },
    stripeMode: async () => "sandbox",
    stripeSecretForMode: (mode) => {
      assert.equal(mode, "sandbox");
      return "sk_test_accounts_v2";
    },
    stripeConnectRequest: async (value) => {
      request = value;
      return recipientAccount();
    },
  });
  const event = thinAccountEvent();
  assert.equal(Object.hasOwn(event, "data"), false);
  const result = await deliver(handler, event, secret);
  assert.equal(result.statusCode, 200);
  assert.equal(request.path, "/v2/core/accounts/acct_recipient_1");
  assert.deepEqual(request.query.include, [
    "configuration.recipient",
    "defaults",
    "requirements",
  ]);
  assert.equal(request.stripeContext, "acct_platform_context");
  const provider = memory.read("payment_provider_accounts/seller-1");
  assert.equal(provider.transferStatus, "active");
  assert.equal(provider.payoutStatus, "active");
  assert.equal(provider.payoutReady, true);
  assert.equal(
      memory.read("stripe_webhook_events/evt_test_accounts_v2_1").status,
      "processed",
  );
});

test("thin webhook verifies only the configured environment signing secret", async () => {
  const sandboxSecret = "whsec_accounts_v2_sandbox_only";
  const productionSecret = "whsec_accounts_v2_production_other";
  let selectedMode = null;
  const handler = createStripeAccountsV2WebhookHandler(
      createMemoryAdmin().admin,
      {
        stripeMode: async () => "sandbox",
        webhookSecretForMode: (mode) => {
          selectedMode = mode;
          return sandboxSecret;
        },
        stripeSecretForMode: () => "sk_test_not_used",
      },
  );
  const result = await deliver(handler, thinAccountEvent({
    id: "evt_test_accounts_v2_wrong_secret",
  }), productionSecret);
  assert.equal(selectedMode, "sandbox");
  assert.equal(result.statusCode, 400);
  assert.equal(result.body, "Invalid Stripe signature");
});

test("thin webhook rejects readiness and provider environment drift", async () => {
  const secret = "whsec_accounts_v2_mode";
  const productionReadiness = createMemoryAdmin({
    "payment_provider_accounts/seller-1": {
      stripeAccountId: "acct_recipient_1",
      connectAccountApiVersion: "v2",
      connectAccountObject: "v2.core.account",
      mode: "sandbox",
    },
  });
  let requests = 0;
  const readinessMismatch = createStripeAccountsV2WebhookHandler(
      productionReadiness.admin,
      {
        webhookSecretForMode: (mode) => {
          assert.equal(mode, "production");
          return secret;
        },
        stripeMode: async () => "production",
        stripeSecretForMode: () => "sk_live_not_used",
        stripeConnectRequest: async () => {
          requests += 1;
          return recipientAccount();
        },
      },
  );
  assert.equal(
      (await deliver(readinessMismatch, thinAccountEvent(), secret)).statusCode,
      409,
  );
  assert.equal(requests, 0);

  const providerMismatch = createStripeAccountsV2WebhookHandler(
      createMemoryAdmin({
        "payment_provider_accounts/seller-1": {
          stripeAccountId: "acct_recipient_1",
          connectAccountApiVersion: "v2",
          connectAccountObject: "v2.core.account",
          mode: "production",
        },
      }).admin,
      {
        webhookSecretForMode: (mode) => {
          assert.equal(mode, "sandbox");
          return secret;
        },
        stripeMode: async () => "sandbox",
        stripeSecretForMode: () => "sk_test_not_used",
        stripeConnectRequest: async () => {
          requests += 1;
          return recipientAccount();
        },
      },
  );
  assert.equal(
      (await deliver(providerMismatch, thinAccountEvent({
        id: "evt_test_accounts_v2_provider_mode",
      }), secret)).statusCode,
      500,
  );
  assert.equal(requests, 0);
});
