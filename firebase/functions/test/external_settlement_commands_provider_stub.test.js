"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {createExternalSettlementCommands} = require("../external_settlement_commands");

const FieldValue = {serverTimestamp: () => "server-time"};

function fakeAdmin(initial = {}) {
  const docs = new Map(Object.entries(initial));
  function ref(path) {
    return {
      path,
      async get() {
        const value = docs.get(path);
        return {exists: value != null, data: () => value};
      },
      collection(name) {
        return {doc: (id) => ref(`${path}/${name}/${id}`)};
      },
    };
  }
  const db = {
    docs,
    collection(name) {
      return {doc: (id) => ref(`${name}/${id}`)};
    },
    async runTransaction(callback) {
      const writes = [];
      const tx = {
        async get(documentRef) {
          const value = docs.get(documentRef.path);
          return {exists: value != null, data: () => value};
        },
        set(documentRef, value, options) {
          writes.push({documentRef, value, options});
        },
      };
      const result = await callback(tx);
      for (const write of writes) {
        const current = docs.get(write.documentRef.path) || {};
        docs.set(
            write.documentRef.path,
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

function baseSale(overrides = {}) {
  return {
    buyerUid: "buyer-1",
    sellerUid: "seller-1",
    status: "pending_completion",
    paymentMethod: "external_settlement",
    paymentProvider: "external",
    paymentProviderStatus: "external_agreed",
    externalSettlementBuyerConfirmed: true,
    externalSettlementSellerConfirmed: true,
    marketplaceFeeStatus: "pending_collection",
    marketplaceFeeCheckoutAttempt: 0,
    marketplaceFeeSnapshot: {
      marketplaceFeeMinor: 2500,
      currency: "CAD",
      scheduleRevision: "provider-stub-v1",
      feeClass: "equipment",
    },
    ...overrides,
  };
}

function fixture(transactionId, sale, stripeRequest) {
  const {admin, db} = fakeAdmin({
    "platform_configuration/payment_provider_readiness": {
      stripeFeeBillingEnabled: true,
      checkoutSuccessUrl: "https://pipebuyer.com/payments/success",
      checkoutCancelUrl: "https://pipebuyer.com/payments/cancel",
    },
    [`marketplace_transactions/${transactionId}`]: sale,
  });
  const commands = createExternalSettlementCommands(admin, {
    authUid: () => "seller-1",
    rateLimit: async () => {},
    loadFeatureFlags: async () => ({marketplace: true, offers: true, paidFeatures: true}),
    requireFeature: () => {},
    loadProviderReadiness: async () => ({
      stripeMode: "production",
      stripeWebhookVerified: true,
      stripeTaxReady: true,
      stripeReconciliationReady: true,
    }),
    stripeRequest,
    secretProvider: () => "sk_test_stub",
  });
  return {commands, db};
}

const request = (transactionId) => ({data: {transactionId}});

test("actual fee callable reuses an open Stripe Session", async () => {
  const id = "txn-open";
  let calls = 0;
  const {commands, db} = fixture(id, baseSale({
    marketplaceFeeStatus: "checkout_created",
    marketplaceFeeCheckoutAttempt: 1,
    stripeMarketplaceFeeSessionId: "cs_existing_open",
  }), async (call) => {
    calls += 1;
    assert.equal(call.method, "GET");
    return {
      status: "open",
      payment_status: "unpaid",
      url: "https://checkout.stripe.com/c/pay/open",
    };
  });
  const result = await commands.createExternalSettlementFeeCheckout(request(id));
  assert.equal(result.alreadyCreated, true);
  assert.equal(result.processing, false);
  assert.equal(result.checkoutSessionId, "cs_existing_open");
  assert.equal(calls, 1);
  assert.equal(db.docs.get(`marketplace_transactions/${id}`).marketplaceFeeCheckoutAttempt, 1);
});

test("actual fee callable retries an expired Session with attempt-scoped idempotency", async () => {
  const id = "txn-expired";
  let calls = 0;
  const {commands, db} = fixture(id, baseSale({
    marketplaceFeeStatus: "checkout_created",
    marketplaceFeeCheckoutAttempt: 1,
    stripeMarketplaceFeeSessionId: "cs_old",
  }), async (call) => {
    calls += 1;
    if (call.method === "GET") return {status: "expired", payment_status: "unpaid"};
    assert.equal(call.idempotencyKey, "pipebuyer-external-fee-txn-expired-attempt-2");
    assert.equal(call.fields["line_items[0][price_data][unit_amount]"], 2500);
    assert.equal(call.fields["metadata[checkoutAttempt]"], 2);
    return {id: "cs_new", url: "https://checkout.stripe.com/c/pay/new"};
  });
  const result = await commands.createExternalSettlementFeeCheckout(request(id));
  assert.equal(result.checkoutAttempt, 2);
  assert.equal(result.checkoutSessionId, "cs_new");
  assert.equal(calls, 2);
  const stored = db.docs.get(`marketplace_transactions/${id}`);
  assert.equal(stored.marketplaceFeeCheckoutAttempt, 2);
  assert.equal(stored.marketplaceFeeStatus, "checkout_created");
  const audit = db.docs.get(`marketplace_transactions/${id}/marketplace_fee_checkout_attempts/0002`);
  assert.equal(audit.stripeCheckoutSessionId, "cs_new");
  assert.equal(audit.feeMinor, 2500);
});

test("actual fee callable preserves webhook processing state after provider response", async () => {
  const id = "txn-processing-race";
  let db;
  const built = fixture(id, baseSale({
    marketplaceFeeStatus: "payment_failed",
    marketplaceFeeCheckoutAttempt: 1,
    stripeMarketplaceFeeSessionId: "cs_failed",
  }), async () => {
    db.docs.set(`marketplace_transactions/${id}`, {
      ...db.docs.get(`marketplace_transactions/${id}`),
      marketplaceFeeStatus: "processing",
      marketplaceFeeCheckoutAttempt: 2,
      stripeMarketplaceFeeSessionId: "cs_race",
    });
    return {id: "cs_race", url: "https://checkout.stripe.com/c/pay/race"};
  });
  db = built.db;
  const result = await built.commands.createExternalSettlementFeeCheckout(request(id));
  assert.equal(result.processing, true);
  assert.equal(result.alreadyCreated, true);
  assert.equal(db.docs.get(`marketplace_transactions/${id}`).marketplaceFeeStatus, "processing");
});

test("actual fee callable cannot downgrade a webhook-collected fee", async () => {
  const id = "txn-paid-race";
  let db;
  const built = fixture(id, baseSale({
    marketplaceFeeStatus: "payment_failed",
    marketplaceFeeCheckoutAttempt: 1,
    stripeMarketplaceFeeSessionId: "cs_failed",
  }), async () => {
    db.docs.set(`marketplace_transactions/${id}`, {
      ...db.docs.get(`marketplace_transactions/${id}`),
      marketplaceFeeStatus: "collected",
      marketplaceFeeCheckoutAttempt: 2,
      stripeMarketplaceFeeSessionId: "cs_paid",
      stripeMarketplaceFeePaymentIntentId: "pi_paid",
      stripeMarketplaceFeeChargeId: "ch_paid",
    });
    return {id: "cs_paid", url: "https://checkout.stripe.com/c/pay/paid"};
  });
  db = built.db;
  const result = await built.commands.createExternalSettlementFeeCheckout(request(id));
  assert.equal(result.alreadyPaid, true);
  assert.equal(result.checkoutSessionId, "cs_paid");
  const stored = db.docs.get(`marketplace_transactions/${id}`);
  assert.equal(stored.marketplaceFeeStatus, "collected");
  assert.equal(stored.stripeMarketplaceFeeChargeId, "ch_paid");
});
