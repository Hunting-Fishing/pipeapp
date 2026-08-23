"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  externalFeeReconciliationState,
} = require("../external_settlement_reconciliation_policy");

function fixture() {
  return {
    sale: {
      transactionId: "txn-1",
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
    },
    session: {
      id: "cs_live_1",
      amount_subtotal: 2500,
      amount_total: 2500,
      total_details: {amount_tax: 0},
      payment_intent: "pi_live_1",
      metadata: {
        billingType: "marketplace_fee_only",
        pipeBuyerTransactionId: "txn-1",
      },
    },
    paymentIntent: {
      id: "pi_live_1",
      status: "succeeded",
      latest_charge: "ch_live_1",
    },
    charge: {
      id: "ch_live_1",
      paid: true,
      amount: 2500,
      currency: "cad",
      balance_transaction: "txn_balance_1",
    },
    balanceTransaction: {
      id: "txn_balance_1",
      amount: 2500,
      fee: 103,
      net: 2397,
      currency: "cad",
    },
  };
}

test("exact provider and Firestore values reconcile to zero difference", () => {
  const state = externalFeeReconciliationState(fixture());
  assert.equal(state.balanced, true);
  assert.deepEqual(state.failedChecks, []);
  assert.equal(state.firestoreDifferenceMinor, 0);
  assert.equal(state.providerDifferenceMinor, 0);
  assert.equal(state.providerFeeMinor, 103);
  assert.equal(state.providerNetMinor, 2397);
});

test("unexpected charged amount fails reconciliation", () => {
  const data = fixture();
  data.charge.amount = 2600;
  data.balanceTransaction.amount = 2600;
  data.balanceTransaction.net = 2497;
  const state = externalFeeReconciliationState(data);
  assert.equal(state.balanced, false);
  assert.ok(state.failedChecks.includes("chargeAmountMatches"));
  assert.ok(state.failedChecks.includes("balanceAmountMatches") === false);
});

test("provider fee arithmetic mismatch fails reconciliation", () => {
  const data = fixture();
  data.balanceTransaction.net = 2398;
  const state = externalFeeReconciliationState(data);
  assert.equal(state.balanced, false);
  assert.ok(state.failedChecks.includes("balanceArithmeticMatches"));
  assert.equal(state.providerDifferenceMinor, -1);
});

test("wrong transaction metadata or billing type fails reconciliation", () => {
  const data = fixture();
  data.session.metadata.pipeBuyerTransactionId = "wrong";
  data.session.metadata.billingType = "dispatch_subscription";
  const state = externalFeeReconciliationState(data);
  assert.equal(state.balanced, false);
  assert.ok(state.failedChecks.includes("sessionTransactionMatches"));
  assert.ok(state.failedChecks.includes("sessionBillingTypeMatches"));
});
