"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchSubscriptionInvoiceReconciliationState,
} = require("../dispatch_subscription_reconciliation_policy");

function stored(overrides = {}) {
  return {
    invoiceId: "in_dispatch_1",
    subscriptionId: "sub_dispatch_1",
    uid: "user-1",
    plan: "monthly",
    currency: "CAD",
    commissionBaseMinor: 2500,
    amountPaidMinor: 2500,
    taxMinor: 0,
    sourceChargeId: "ch_dispatch_1",
    status: "paid",
    ...overrides,
  };
}

function invoice(overrides = {}) {
  return {
    id: "in_dispatch_1",
    status: "paid",
    amount_paid: 2500,
    total: 2500,
    total_excluding_tax: 2500,
    currency: "cad",
    charge: "ch_dispatch_1",
    parent: {
      subscription_details: {
        subscription: "sub_dispatch_1",
        metadata: {
          billingType: "dispatch_subscription",
          pipeBuyerUid: "user-1",
          dispatchPlan: "monthly",
        },
      },
    },
    ...overrides,
  };
}

function charge(overrides = {}) {
  return {
    id: "ch_dispatch_1",
    paid: true,
    amount: 2500,
    currency: "cad",
    balance_transaction: "txn_dispatch_1",
    ...overrides,
  };
}

function balance(overrides = {}) {
  return {
    id: "txn_dispatch_1",
    amount: 2500,
    fee: 103,
    net: 2397,
    currency: "cad",
    ...overrides,
  };
}

test("positive Dispatch invoice balances Invoice Charge and Balance Transaction", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice(),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, true);
  assert.deepEqual(result.failedChecks, []);
  assert.equal(result.providerGrossMinor, 2500);
  assert.equal(result.providerFeeMinor, 103);
  assert.equal(result.providerNetMinor, 2397);
  assert.equal(result.providerDifferenceMinor, 0);
});

test("stored and provider amount mismatch can never report balanced", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice({amount_paid: 2400}),
    charge: charge({amount: 2400}),
    balanceTransaction: balance({amount: 2400, net: 2297}),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("amountPaidMatches"));
  assert.equal(result.invoiceDifferenceMinor, -100);
});

test("wrong Dispatch subscription metadata is quarantined as mismatch", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice({
      parent: {
        subscription_details: {
          subscription: "sub_dispatch_1",
          metadata: {
            billingType: "other",
            pipeBuyerUid: "user-1",
            dispatchPlan: "monthly",
          },
        },
      },
    }),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("billingTypeMatches"));
});

test("100 percent discount invoice reconciles without inventing Charge or provider fee", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored({
      commissionBaseMinor: 0,
      amountPaidMinor: 0,
      taxMinor: 0,
      sourceChargeId: null,
    }),
    invoice: invoice({
      amount_paid: 0,
      total: 0,
      total_excluding_tax: 0,
      charge: null,
    }),
  });
  assert.equal(result.balanced, true);
  assert.equal(result.zeroAmount, true);
  assert.equal(result.providerGrossMinor, 0);
  assert.equal(result.providerFeeMinor, 0);
  assert.equal(result.providerNetMinor, 0);
  assert.equal(result.stripeChargeId, "");
  assert.equal(result.stripeBalanceTransactionId, "");
});

test("zero-dollar Firestore record mismatches if Stripe unexpectedly reports a Charge", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored({
      commissionBaseMinor: 0,
      amountPaidMinor: 0,
      taxMinor: 0,
      sourceChargeId: null,
    }),
    invoice: invoice({
      amount_paid: 0,
      total: 0,
      total_excluding_tax: 0,
      charge: "ch_unexpected",
    }),
    charge: {
      id: "ch_unexpected",
      paid: true,
      amount: 0,
      currency: "cad",
    },
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("providerChargeExpectation"));
  assert.ok(result.failedChecks.includes("sourceChargeMatches"));
});
