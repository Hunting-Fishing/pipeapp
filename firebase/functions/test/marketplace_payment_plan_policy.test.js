"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  paymentHasStarted,
  splitPaymentAmounts,
  validateDepositApproval,
  validateDepositProposal,
} = require("../marketplace_payment_plan_policy");

function sale(overrides = {}) {
  return {
    buyerUid: "buyer",
    sellerUid: "seller",
    status: "pending_completion",
    paymentProviderStatus: "pending_payment",
    marketplaceFeeSnapshot: {agreedTotalMinor: 1000000},
    ...overrides,
  };
}

test("deposit plan derives exact immutable deposit and balance amounts", () => {
  assert.deepEqual(splitPaymentAmounts(1000000, 100000), {
    paymentRequiredMinor: 1000000,
    depositAmountMinor: 100000,
    balanceAmountMinor: 900000,
  });
  assert.throws(
      () => splitPaymentAmounts(1000000, 999950),
      (error) => error.code === "invalid-argument",
  );
});

test("only transaction participants can propose a deposit before payment starts", () => {
  const proposal = validateDepositProposal({
    sale: sale(),
    actorUid: "buyer",
    depositAmountMinor: 250000,
  });
  assert.equal(proposal.paymentPlan, "deposit_balance");
  assert.equal(proposal.buyerApproved, true);
  assert.equal(proposal.sellerApproved, false);
  assert.equal(proposal.proposalRevision, 1);
  assert.throws(
      () => validateDepositProposal({
        sale: sale(),
        actorUid: "stranger",
        depositAmountMinor: 250000,
      }),
      (error) => error.code === "permission-denied",
  );
});

test("deposit terms lock as soon as any Stripe payment starts", () => {
  for (const started of [
    sale({paymentProviderStatus: "checkout_created"}),
    sale({paymentProviderStatus: "partially_paid"}),
    sale({amountPaidMinor: 10000}),
    sale({stripeCheckoutSessionId: "cs_live_123"}),
  ]) {
    assert.equal(paymentHasStarted(started), true);
    assert.throws(
        () => validateDepositProposal({
          sale: started,
          actorUid: "buyer",
          depositAmountMinor: 250000,
        }),
        (error) => error.code === "failed-precondition",
    );
  }
});

test("Timed Buying cannot add a deposit requirement after the winner is selected", () => {
  assert.throws(
      () => validateDepositProposal({
        sale: sale({paymentOrigin: "timed_buying"}),
        actorUid: "seller",
        depositAmountMinor: 250000,
      }),
      (error) =>
        error.code === "failed-precondition" &&
        error.message.includes("before bidding starts"),
  );
});

test("counterparty approval activates only the exact proposal revision", () => {
  const pendingSale = sale({
    paymentPlanProposalRevision: 3,
    paymentPlanProposal: {
      status: "pending_counterparty",
      paymentPlan: "deposit_balance",
      paymentRequiredMinor: 1000000,
      depositAmountMinor: 250000,
      balanceAmountMinor: 750000,
      buyerApproved: true,
      sellerApproved: false,
    },
  });
  const approval = validateDepositApproval({
    sale: pendingSale,
    actorUid: "seller",
    expectedRevision: 3,
  });
  assert.equal(approval.activate, true);
  assert.equal(approval.depositAmountMinor, 250000);
  assert.throws(
      () => validateDepositApproval({
        sale: pendingSale,
        actorUid: "seller",
        expectedRevision: 2,
      }),
      (error) => error.code === "aborted",
  );
});
