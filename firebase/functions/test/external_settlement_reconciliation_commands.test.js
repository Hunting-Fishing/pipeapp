"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createExternalSettlementReconciliationCommands,
  requiredProviderId,
  transactionIdFromRequest,
} = require("../external_settlement_reconciliation_commands");

function administratorRequest(transactionId = "txn-1") {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data: {transactionId},
  };
}

function saleFixture(overrides = {}) {
  return {
    marketplaceFeeStatus: "collected",
    currency: "CAD",
    marketplaceFeeSnapshot: {
      marketplaceFeeMinor: 2500,
      currency: "CAD",
    },
    marketplaceFeeTaxCollectedMinor: 0,
    marketplaceFeeBuyerChargedMinor: 2500,
    stripeMarketplaceFeeSessionId: "cs_live_1",
    stripeMarketplaceFeePaymentIntentId: "pi_live_1",
    stripeMarketplaceFeeChargeId: "ch_live_1",
    ...overrides,
  };
}

function fakeAdmin(sale) {
  const writes = [];
  const db = {
    collection(name) {
      return {
        doc(id = `auto-${name}`) {
          const ref = {name, id};
          if (name === "marketplace_transactions") {
            ref.get = async () => ({
              exists: true,
              data: () => sale,
            });
          }
          return ref;
        },
      };
    },
    async runTransaction(callback) {
      return callback({
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

function providerFixture({wrongTransaction = false} = {}) {
  const calls = [];
  async function stripeRequest({secretKey, path, method}) {
    assert.equal(secretKey, "sk_test_injected");
    assert.equal(method, "GET");
    calls.push(path);
    if (path === "/v1/checkout/sessions/cs_live_1") {
      return {
        id: "cs_live_1",
        amount_subtotal: 2500,
        amount_total: 2500,
        total_details: {amount_tax: 0},
        payment_intent: "pi_live_1",
        metadata: {
          billingType: "marketplace_fee_only",
          pipeBuyerTransactionId: wrongTransaction ? "wrong" : "txn-1",
        },
      };
    }
    if (path === "/v1/payment_intents/pi_live_1") {
      return {
        id: "pi_live_1",
        status: "succeeded",
        latest_charge: "ch_live_1",
      };
    }
    if (path === "/v1/charges/ch_live_1") {
      return {
        id: "ch_live_1",
        paid: true,
        amount: 2500,
        currency: "cad",
        balance_transaction: "txn_balance_1",
      };
    }
    if (path === "/v1/balance_transactions/txn_balance_1") {
      return {
        id: "txn_balance_1",
        amount: 2500,
        fee: 103,
        net: 2397,
        currency: "cad",
      };
    }
    throw new Error(`Unexpected provider path ${path}`);
  }
  return {calls, stripeRequest};
}

test("reconciliation command re-reads full Stripe chain and records balanced evidence", async () => {
  const {admin, writes} = fakeAdmin(saleFixture());
  const provider = providerFixture();
  const commands = createExternalSettlementReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  const result = await commands.reconcileExternalSettlementFee(
      administratorRequest(),
  );

  assert.equal(result.balanced, true);
  assert.equal(result.status, "balanced");
  assert.equal(result.providerGrossMinor, 2500);
  assert.equal(result.providerFeeMinor, 103);
  assert.equal(result.providerNetMinor, 2397);
  assert.equal(result.stripeBalanceTransactionId, "txn_balance_1");
  assert.deepEqual(provider.calls, [
    "/v1/checkout/sessions/cs_live_1",
    "/v1/payment_intents/pi_live_1",
    "/v1/charges/ch_live_1",
    "/v1/balance_transactions/txn_balance_1",
  ]);
  assert.equal(writes.length, 3);
  const transactionWrite = writes.find(
      (write) => write.ref.name === "marketplace_transactions",
  );
  assert.equal(
      transactionWrite.data.marketplaceFeeReconciliationStatus,
      "balanced",
  );
  assert.equal(
      transactionWrite.data.stripeMarketplaceFeeBalanceTransactionId,
      "txn_balance_1",
  );
});

test("provider mismatch is persisted as mismatch and never reported balanced", async () => {
  const {admin, writes} = fakeAdmin(saleFixture());
  const provider = providerFixture({wrongTransaction: true});
  const commands = createExternalSettlementReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  const result = await commands.reconcileExternalSettlementFee(
      administratorRequest(),
  );
  assert.equal(result.balanced, false);
  assert.equal(result.status, "mismatch");
  assert.ok(result.failedChecks.includes("sessionTransactionMatches"));
  const transactionWrite = writes.find(
      (write) => write.ref.name === "marketplace_transactions",
  );
  assert.equal(
      transactionWrite.data.marketplaceFeeReconciliationStatus,
      "mismatch",
  );
});

test("reconciliation refuses unpaid fee state before calling Stripe", async () => {
  const {admin, writes} = fakeAdmin(saleFixture({
    marketplaceFeeStatus: "payment_failed",
  }));
  let providerCalls = 0;
  const commands = createExternalSettlementReconciliationCommands(admin, {
    stripeRequest: async () => {
      providerCalls += 1;
      return {};
    },
    secretKeyProvider: () => "sk_test_injected",
  });

  await assert.rejects(
      commands.reconcileExternalSettlementFee(administratorRequest()),
      /must be collected/i,
  );
  assert.equal(providerCalls, 0);
  assert.equal(writes.length, 0);
});

test("reconciliation input and provider IDs fail closed", () => {
  assert.throws(() => transactionIdFromRequest({data: {transactionId: "bad/id"}}));
  assert.throws(() => requiredProviderId("not-a-charge", "ch_", "missing"));
  assert.equal(requiredProviderId("ch_123", "ch_", "missing"), "ch_123");
});
