"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {
  STRIPE_CONNECT_ACCOUNT_API_FAMILY,
  STRIPE_CONNECT_ACCOUNT_OBJECT,
  STRIPE_CONNECT_ACCOUNTS_API_VERSION,
  providerUsesAccountsV2,
  recipientAccountReadiness,
  recipientPayoutStatus,
  recipientTransferStatus,
  refreshStripeRecipientAccountStatus,
  sellerPayoutReady,
  stripeConnectRequest,
  stripeSellerAccountIdempotencyKey,
  stripeV2RecipientAccountPayload,
} = require("../stripe_marketplace_commands");

test("seller Connect uses the current stable Accounts v2 API version", () => {
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      "2026-08-26.dahlia",
  );
  assert.equal(
      STRIPE_CONNECT_ACCOUNTS_API_VERSION,
      stripeMarketplaceConfig.connectAccountsApiVersion,
  );
  assert.doesNotMatch(STRIPE_CONNECT_ACCOUNTS_API_VERSION, /preview/);
  assert.equal(STRIPE_CONNECT_ACCOUNT_API_FAMILY, "v2");
  assert.equal(STRIPE_CONNECT_ACCOUNT_OBJECT, "v2.core.account");
});

test("Stripe payment and Connect surfaces use one reviewed version", () => {
  assert.equal(stripeMarketplaceConfig.apiVersion, "2026-08-26.dahlia");
  assert.equal(
      stripeMarketplaceConfig.connectAccountsApiVersion,
      stripeMarketplaceConfig.apiVersion,
  );
});

test("Stripe Checkout integration identifiers have stable random-letter suffixes", () => {
  for (const identifier of Object.values(
      stripeMarketplaceConfig.integrationIdentifiers,
  )) {
    assert.match(identifier, /^pipebuyer_[a-z_]+_[a-z]{8}$/u);
  }
  const checkoutSource = fs.readFileSync(
      path.join(__dirname, "..", "stripe_checkout_commands.js"),
      "utf8",
  );
  const externalSource = fs.readFileSync(
      path.join(__dirname, "..", "external_settlement_commands.js"),
      "utf8",
  );
  assert.match(checkoutSource, /integration_identifier/u);
  assert.match(checkoutSource, /payment_method_configuration/u);
  assert.match(checkoutSource, /stripeCheckoutEconomicsDecision/u);
  assert.match(externalSource, /integration_identifier/u);
});

test("seller onboarding creates an Accounts v2 recipient with explicit responsibilities", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "stripe_marketplace_commands.js"),
      "utf8",
  );
  assert.match(source, /path:\s*"\/v2\/core\/accounts"/);
  assert.match(source, /path:\s*"\/v1\/account_links"/);
  assert.doesNotMatch(source, /path:\s*"\/v1\/accounts"/);
  assert.doesNotMatch(source, /type:\s*"express"/);
  assert.doesNotMatch(source, /card_payments/);
  assert.doesNotMatch(source, /merchant_capabilities/);
  const payload = stripeV2RecipientAccountPayload({
    contactEmail: "seller@example.com",
    country: "CA",
    uid: "seller-1",
  });
  assert.equal(payload.dashboard, "express");
  assert.equal(payload.identity.country, "ca");
  assert.equal(
      payload.defaults.responsibilities.fees_collector,
      "application",
  );
  assert.equal(
      payload.defaults.responsibilities.losses_collector,
      "application",
  );
  assert.equal(
      payload.configuration.recipient.capabilities.stripe_balance
          .stripe_transfers.requested,
      true,
  );
  assert.deepEqual(payload.include, [
    "configuration.recipient",
    "defaults",
    "identity",
    "requirements",
  ]);
  assert.match(
      stripeSellerAccountIdempotencyKey("seller-1"),
      /^pipebuyer-recipient-v2-[a-f0-9]{64}$/u,
  );
});

test("Accounts v2 requests use JSON and indexed include query fields", async () => {
  const originalFetch = global.fetch;
  const calls = [];
  global.fetch = async (url, options) => {
    calls.push({url: String(url), options});
    return {
      ok: true,
      async json() {
        return {id: "acct_recipient_1"};
      },
      headers: {get: () => "req_test"},
    };
  };
  try {
    await stripeConnectRequest({
      secretKey: "test-secret",
      path: "/v2/core/accounts",
      fields: {dashboard: "express"},
      idempotencyKey: "recipient-create-1",
    });
    await stripeConnectRequest({
      secretKey: "test-secret",
      path: "/v2/core/accounts/acct_recipient_1",
      method: "GET",
      query: {include: ["configuration.recipient", "defaults"]},
      stripeContext: "acct_platform_context",
    });
  } finally {
    global.fetch = originalFetch;
  }
  assert.equal(calls.length, 2);
  assert.equal(calls[0].options.headers["Content-Type"], "application/json");
  assert.equal(calls[0].options.body, JSON.stringify({dashboard: "express"}));
  assert.equal(
      calls[0].options.headers["Idempotency-Key"],
      "recipient-create-1",
  );
  const getUrl = new URL(calls[1].url);
  assert.equal(
      getUrl.searchParams.get("include[0]"),
      "configuration.recipient",
  );
  assert.equal(getUrl.searchParams.get("include[1]"), "defaults");
  assert.equal(
      calls[1].options.headers["Stripe-Context"],
      "acct_platform_context",
  );
  assert.equal(calls[1].options.body, undefined);
});

function recipientAccount({
  transferStatus = "active",
  payoutStatus = "active",
} = {}) {
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
            payouts: {status: payoutStatus},
            stripe_transfers: {status: transferStatus},
          },
        },
      },
    },
  };
}

test("payout readiness requires the full v2 recipient configuration", () => {
  assert.equal(
      recipientTransferStatus(recipientAccount()),
      "active",
  );
  assert.equal(recipientPayoutStatus(recipientAccount()), "active");
  assert.equal(sellerPayoutReady(recipientAccount()), true);
  assert.equal(sellerPayoutReady(recipientAccount({
    transferStatus: "pending",
  })), false);
  assert.equal(sellerPayoutReady(recipientAccount({
    payoutStatus: "pending",
  })), false);
  assert.equal(sellerPayoutReady(recipientAccount({
    transferStatus: "active",
    payoutStatus: "restricted",
  })), false);
  const missingPayoutCapability = recipientAccount();
  delete missingPayoutCapability.configuration.recipient.capabilities
      .stripe_balance.payouts;
  assert.equal(recipientPayoutStatus(missingPayoutCapability), "pending");
  assert.equal(sellerPayoutReady(missingPayoutCapability), false);
  assert.equal(
      sellerPayoutReady({...recipientAccount(), dashboard: "full"}),
      false,
  );
  assert.equal(
      sellerPayoutReady({
        ...recipientAccount(),
        defaults: {responsibilities: {
          fees_collector: "stripe",
          losses_collector: "stripe",
        }},
      }),
      false,
  );
  assert.equal(recipientAccountReadiness(recipientAccount()).payoutReady, true);
  assert.equal(providerUsesAccountsV2({
    connectAccountApiVersion: "v2",
    connectAccountObject: "v2.core.account",
  }), true);
  assert.equal(providerUsesAccountsV2({}), false);
});

test("runtime recipient refresh uses v2 include fields and persists readiness", async () => {
  const writes = [];
  const providerRef = {
    async set(value, options) {
      writes.push({value, options});
    },
  };
  let request;
  const result = await refreshStripeRecipientAccountStatus({
    providerRef,
    providerData: {
      stripeAccountId: "acct_recipient_1",
      connectAccountApiVersion: "v2",
      connectAccountObject: "v2.core.account",
    },
    FieldValue: {serverTimestamp: () => "server-time"},
    secretKey: "test-secret",
    requestFn: async (value) => {
      request = value;
      return recipientAccount();
    },
  });
  assert.equal(
      request.path,
      "/v2/core/accounts/acct_recipient_1",
  );
  assert.deepEqual(request.query.include, [
    "configuration.recipient",
    "defaults",
    "requirements",
  ]);
  assert.equal(result.payoutReady, true);
  assert.equal(result.accountMode, "sandbox");
  assert.equal(writes.length, 1);
  assert.equal(writes[0].value.transferStatus, "active");
  assert.equal(writes[0].value.payoutStatus, "active");
  assert.equal(writes[0].value.recipientConfigurationReady, true);
  assert.equal(writes[0].value.payoutReady, true);
  assert.equal(writes[0].options.merge, true);
});

test("runtime recipient refresh blocks legacy v1 provider records", async () => {
  let requests = 0;
  await assert.rejects(refreshStripeRecipientAccountStatus({
    providerRef: {set: async () => {}},
    providerData: {stripeAccountId: "acct_legacy_1"},
    FieldValue: {serverTimestamp: () => "server-time"},
    secretKey: "test-secret",
    requestFn: async () => {
      requests += 1;
      return {};
    },
  }), /legacy account model/u);
  assert.equal(requests, 0);
});

test("runtime recipient refresh rejects a Stripe environment mismatch", async () => {
  await assert.rejects(refreshStripeRecipientAccountStatus({
    providerRef: {set: async () => {}},
    providerData: {
      stripeAccountId: "acct_recipient_1",
      connectAccountApiVersion: "v2",
      connectAccountObject: "v2.core.account",
    },
    FieldValue: {serverTimestamp: () => "server-time"},
    secretKey: "test-secret",
    expectedMode: "production",
    requestFn: async () => recipientAccount(),
  }), /different environment/u);
});
