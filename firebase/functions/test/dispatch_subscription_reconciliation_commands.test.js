"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionReconciliationCommands,
  invoiceIdFromRequest,
  requiredProviderId,
} = require("../dispatch_subscription_reconciliation_commands");

function administratorRequest(invoiceId = "in_dispatch_1") {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data: {invoiceId},
  };
}

function storedInvoice(overrides = {}) {
  return {
    invoiceId: "in_dispatch_1",
    subscriptionId: "sub_dispatch_1",
    uid: "user-1",
    plan: "monthly",
    currency: "CAD",
    commissionBaseMinor: 2500,
    amountPaidMinor: 2500,
    taxMinor: 0,
    sourceChargeId: "",
    status: "paid",
    ...overrides,
  };
}

function fakeAdmin(stored) {
  const writes = [];
  const db = {
    collection(name) {
      return {
        doc(id = `auto-${name}`) {
          const ref = {name, id};
          if (name === "dispatch_subscription_invoices") {
            ref.get = async () => ({
              exists: true,
              data: () => stored,
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

function providerInvoice({zero = false, wrongBillingType = false} = {}) {
  return {
    id: "in_dispatch_1",
    status: "paid",
    amount_paid: zero ? 0 : 2500,
    total: zero ? 0 : 2500,
    total_excluding_tax: zero ? 0 : 2500,
    currency: "cad",
    parent: {
      subscription_details: {
        subscription: "sub_dispatch_1",
        metadata: {
          billingType: wrongBillingType ? "other" : "dispatch_subscription",
          pipeBuyerUid: "user-1",
          dispatchPlan: "monthly",
        },
      },
    },
  };
}

function providerInvoicePayment(id = "inpay_dispatch_1") {
  return {
    id,
    status: "paid",
    invoice: "in_dispatch_1",
    amount_paid: 2500,
    currency: "cad",
    payment: {
      type: "payment_intent",
      payment_intent: "pi_dispatch_1",
    },
  };
}

function providerFixture({
  zero = false,
  wrongBillingType = false,
  multiplePayments = false,
  listHasMore = false,
} = {}) {
  const calls = [];
  async function stripeRequest({secretKey, path, method}) {
    assert.equal(secretKey, "sk_test_injected");
    assert.equal(method, "GET");
    calls.push(path);
    if (path === "/v1/invoices/in_dispatch_1") {
      return providerInvoice({zero, wrongBillingType});
    }
    if (path === "/v1/invoice_payments?invoice=in_dispatch_1&status=paid&limit=100") {
      return {
        object: "list",
        has_more: listHasMore,
        data: zero ? [] : multiplePayments ? [
          providerInvoicePayment("inpay_dispatch_1"),
          providerInvoicePayment("inpay_dispatch_2"),
        ] : [providerInvoicePayment()],
      };
    }
    if (path === "/v1/payment_intents/pi_dispatch_1") {
      return {
        id: "pi_dispatch_1",
        status: "succeeded",
        amount_received: 2500,
        latest_charge: "ch_dispatch_1",
      };
    }
    if (path === "/v1/charges/ch_dispatch_1") {
      return {
        id: "ch_dispatch_1",
        paid: true,
        amount: 2500,
        currency: "cad",
        balance_transaction: "txn_dispatch_1",
      };
    }
    if (path === "/v1/balance_transactions/txn_dispatch_1") {
      return {
        id: "txn_dispatch_1",
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

test("paid Dispatch invoice re-reads InvoicePayment PaymentIntent Charge and Balance Transaction and records balanced evidence", async () => {
  const {admin, writes} = fakeAdmin(storedInvoice());
  const provider = providerFixture();
  const commands = createDispatchSubscriptionReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  const result = await commands.reconcileDispatchSubscriptionInvoice(
      administratorRequest(),
  );

  assert.equal(result.balanced, true);
  assert.equal(result.status, "balanced");
  assert.equal(result.providerGrossMinor, 2500);
  assert.equal(result.providerFeeMinor, 103);
  assert.equal(result.providerNetMinor, 2397);
  assert.equal(result.stripeInvoicePaymentId, "inpay_dispatch_1");
  assert.equal(result.stripePaymentIntentId, "pi_dispatch_1");
  assert.equal(result.stripeChargeId, "ch_dispatch_1");
  assert.equal(result.stripeBalanceTransactionId, "txn_dispatch_1");
  assert.deepEqual(provider.calls, [
    "/v1/invoices/in_dispatch_1",
    "/v1/invoice_payments?invoice=in_dispatch_1&status=paid&limit=100",
    "/v1/payment_intents/pi_dispatch_1",
    "/v1/charges/ch_dispatch_1",
    "/v1/balance_transactions/txn_dispatch_1",
  ]);
  assert.equal(writes.length, 3);
  const invoiceWrite = writes.find(
      (write) => write.ref.name === "dispatch_subscription_invoices",
  );
  assert.equal(invoiceWrite.data.reconciliationStatus, "balanced");
  assert.equal(invoiceWrite.data.providerFeeMinor, 103);
  assert.equal(invoiceWrite.data.stripeInvoicePaymentId, "inpay_dispatch_1");
  assert.equal(invoiceWrite.data.stripePaymentIntentId, "pi_dispatch_1");
  assert.equal(invoiceWrite.data.sourceChargeId, "ch_dispatch_1");
});

test("provider metadata mismatch is persisted and never reported balanced", async () => {
  const {admin, writes} = fakeAdmin(storedInvoice());
  const provider = providerFixture({wrongBillingType: true});
  const commands = createDispatchSubscriptionReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  const result = await commands.reconcileDispatchSubscriptionInvoice(
      administratorRequest(),
  );
  assert.equal(result.balanced, false);
  assert.equal(result.status, "mismatch");
  assert.ok(result.failedChecks.includes("billingTypeMatches"));
  const invoiceWrite = writes.find(
      (write) => write.ref.name === "dispatch_subscription_invoices",
  );
  assert.equal(invoiceWrite.data.reconciliationStatus, "mismatch");
});

test("zero-dollar promotional invoice proves there are no paid InvoicePayment records", async () => {
  const {admin, writes} = fakeAdmin(storedInvoice({
    commissionBaseMinor: 0,
    amountPaidMinor: 0,
    taxMinor: 0,
    sourceChargeId: null,
  }));
  const provider = providerFixture({zero: true});
  const commands = createDispatchSubscriptionReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  const result = await commands.reconcileDispatchSubscriptionInvoice(
      administratorRequest(),
  );
  assert.equal(result.balanced, true);
  assert.equal(result.zeroAmount, true);
  assert.equal(result.providerGrossMinor, 0);
  assert.equal(result.providerFeeMinor, 0);
  assert.equal(result.stripeInvoicePaymentId, null);
  assert.equal(result.stripePaymentIntentId, null);
  assert.equal(result.stripeChargeId, null);
  assert.deepEqual(provider.calls, [
    "/v1/invoices/in_dispatch_1",
    "/v1/invoice_payments?invoice=in_dispatch_1&status=paid&limit=100",
  ]);
  assert.equal(writes.length, 3);
});

test("multiple paid InvoicePayment records fail closed for manual financial review", async () => {
  const {admin, writes} = fakeAdmin(storedInvoice());
  const provider = providerFixture({multiplePayments: true});
  const commands = createDispatchSubscriptionReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  await assert.rejects(
      commands.reconcileDispatchSubscriptionInvoice(administratorRequest()),
      /multiple paid Stripe InvoicePayment records/i,
  );
  assert.equal(writes.length, 0);
});

test("paginated InvoicePayment history fails closed instead of silently reconciling a partial provider list", async () => {
  const {admin, writes} = fakeAdmin(storedInvoice());
  const provider = providerFixture({listHasMore: true});
  const commands = createDispatchSubscriptionReconciliationCommands(admin, {
    stripeRequest: provider.stripeRequest,
    secretKeyProvider: () => "sk_test_injected",
  });

  await assert.rejects(
      commands.reconcileDispatchSubscriptionInvoice(administratorRequest()),
      /more provider payment records/i,
  );
  assert.equal(writes.length, 0);
});

test("reconciliation refuses unpaid local invoice before calling Stripe", async () => {
  const {admin, writes} = fakeAdmin(storedInvoice({status: "payment_failed"}));
  let providerCalls = 0;
  const commands = createDispatchSubscriptionReconciliationCommands(admin, {
    stripeRequest: async () => {
      providerCalls += 1;
      return {};
    },
    secretKeyProvider: () => "sk_test_injected",
  });
  await assert.rejects(
      commands.reconcileDispatchSubscriptionInvoice(administratorRequest()),
      /must be paid/i,
  );
  assert.equal(providerCalls, 0);
  assert.equal(writes.length, 0);
});

test("reconciliation input and provider IDs fail closed", () => {
  assert.throws(() => invoiceIdFromRequest({data: {invoiceId: "bad/id"}}));
  assert.throws(() => requiredProviderId("bad", "ch_", "missing"));
  assert.equal(requiredProviderId("ch_123", "ch_", "missing"), "ch_123");
});
