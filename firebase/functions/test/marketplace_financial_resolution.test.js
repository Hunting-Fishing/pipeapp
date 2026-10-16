"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  adjustedAffiliateCommission,
  createMarketplaceFinancialResolution,
  financialChargeAmount,
  proportionalRecoveryTarget,
  refundStatusShouldApply,
  refundReasonCode,
  resolvedDisputeOutcome,
} = require("../marketplace_financial_resolution");
const {createAffiliatePayouts} = require("../affiliate_payouts");
const {
  createMarketplaceRefundWebhookGate,
} = require("../marketplace_refund_webhook_gate");
const {
  createMarketplaceSellerFunds,
} = require("../marketplace_seller_funds");
const {financialMutationValues} = require("../marketplace_financial_epoch");
const {createMemoryAdmin} = require("./memory_firestore");

test("seller recovery scales proportionally and reaches the full transfer", () => {
  assert.equal(proportionalRecoveryTarget({
    transferAmountMinor: 97000,
    originalChargeAmountMinor: 105000,
    customerExposureMinor: 52500,
  }), 48500);
  assert.equal(proportionalRecoveryTarget({
    transferAmountMinor: 97000,
    originalChargeAmountMinor: 105000,
    customerExposureMinor: 105000,
  }), 97000);
});

test("cumulative partial exposure never over-recovers seller proceeds", () => {
  const first = proportionalRecoveryTarget({
    transferAmountMinor: 90000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 25000,
  });
  const second = proportionalRecoveryTarget({
    transferAmountMinor: 90000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 60000,
  });
  assert.equal(first, 22500);
  assert.equal(second, 54000);
  assert.equal(second - first, 31500);
});

test("affiliate commission is reduced by financial exposure", () => {
  assert.equal(adjustedAffiliateCommission({
    commissionMinor: 2000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 25000,
  }), 1500);
  assert.equal(adjustedAffiliateCommission({
    commissionMinor: 2000,
    originalChargeAmountMinor: 100000,
    customerExposureMinor: 100000,
  }), 0);
});

test("refund reason codes are restricted to Stripe-supported values", () => {
  assert.equal(refundReasonCode("fraudulent"), "fraudulent");
  assert.equal(refundReasonCode("duplicate"), "duplicate");
  assert.equal(refundReasonCode("seller_requested"), "requested_by_customer");
});

function feeOnlyFixture(ledgerStatus = "pending_refund_window") {
  return createMemoryAdmin({
    "marketplace_transactions/external-1": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      paymentMethod: "external_settlement",
      marketplaceFeeStatus: "collected",
      stripeMarketplaceFeeChargeId: "ch_Fee1",
      marketplaceFeeBuyerChargedMinor: 1000,
      platformMarketplaceFeeMinor: 1000,
      marketplaceFeeSnapshot: {marketplaceFeeMinor: 1000},
      financialEpoch: 4,
      financialHold: false,
    },
    "affiliate_commission_ledger/marketplace_external-1": {
      transactionId: "external-1",
      referrerUid: "affiliate-1",
      currency: "USD",
      commissionMinor: 200,
      status: ledgerStatus,
    },
    "payment_provider_accounts/affiliate-1": {
      affiliatePayoutHold: false,
    },
  });
}

function feeDispute(status, id = "du_Fee1") {
  return {
    id,
    charge: "ch_Fee1",
    amount: 1000,
    currency: "usd",
    reason: "fraudulent",
    status,
    evidence_details: {submission_count: 0},
  };
}

test("fee-only dispute freezes then restores unpaid affiliate exposure on win", async () => {
  const memory = feeOnlyFixture();
  const financial = createMarketplaceFinancialResolution(memory.admin);
  await financial.handleDisputeEvent(
      feeDispute("under_review"),
      "charge.dispute.created",
  );
  let sale = memory.read("marketplace_transactions/external-1");
  let ledger = memory.read(
      "affiliate_commission_ledger/marketplace_external-1",
  );
  assert.equal(sale.marketplaceFeeStatus, "disputed");
  assert.equal(sale.financialHold, true);
  assert.equal(sale.financialEpoch, 5);
  assert.equal(ledger.status, "void_financial_event");
  assert.equal(ledger.adjustedCommissionMinor, 0);

  await financial.handleDisputeEvent(
      feeDispute("won"),
      "charge.dispute.closed",
  );
  sale = memory.read("marketplace_transactions/external-1");
  ledger = memory.read("affiliate_commission_ledger/marketplace_external-1");
  assert.equal(sale.marketplaceFeeStatus, "collected");
  assert.equal(sale.marketplaceFeeDisputeStatus, "won");
  assert.equal(sale.financialHold, false);
  assert.equal(ledger.status, "pending_refund_window");
  assert.equal(ledger.adjustedCommissionMinor, 200);

  await financial.handleDisputeEvent(
      feeDispute("under_review"),
      "charge.dispute.updated",
  );
  assert.equal(
      memory.read("marketplace_transactions/external-1")
          .marketplaceFeeStatus,
      "collected",
  );
});

test("lost fee-only dispute creates recovery for a paid affiliate", async () => {
  const memory = feeOnlyFixture("paid");
  const financial = createMarketplaceFinancialResolution(memory.admin);
  await financial.handleDisputeEvent(
      feeDispute("lost", "du_FeeLost1"),
      "charge.dispute.closed",
  );
  const sale = memory.read("marketplace_transactions/external-1");
  const obligation = memory.read(
      "affiliate_recovery_obligations/marketplace_external-1_affiliate-1",
  );
  const provider = memory.read("payment_provider_accounts/affiliate-1");
  assert.equal(sale.marketplaceFeeStatus, "charged_back");
  assert.equal(sale.marketplaceFeeDisputeStatus, "lost");
  assert.equal(sale.financialHold, true);
  assert.equal(obligation.targetRecoveryMinor, 200);
  assert.equal(obligation.amountDueMinor, 200);
  assert.equal(obligation.status, "open");
  assert.equal(provider.affiliatePayoutHold, true);
});

test("concurrent stale fee dispute work cannot regress a terminal win", async () => {
  const memory = feeOnlyFixture();
  let openReachedFinalization;
  const reachedFinalization = new Promise((resolve) => {
    openReachedFinalization = resolve;
  });
  let resumeOpen;
  const openMayFinish = new Promise((resolve) => {
    resumeOpen = resolve;
  });
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    beforeFeeDisputeFinalization: async ({outcome}) => {
      if (outcome !== "open") return;
      openReachedFinalization();
      await openMayFinish;
    },
  });
  const opening = financial.handleDisputeEvent(
      feeDispute("under_review"),
      "charge.dispute.created",
  );
  await reachedFinalization;
  await financial.handleDisputeEvent(
      feeDispute("won"),
      "charge.dispute.closed",
  );
  resumeOpen();
  await opening;

  const sale = memory.read("marketplace_transactions/external-1");
  const ledger = memory.read(
      "affiliate_commission_ledger/marketplace_external-1",
  );
  assert.equal(sale.marketplaceFeeStatus, "collected");
  assert.equal(sale.marketplaceFeeDisputeStatus, "won");
  assert.equal(sale.financialHold, false);
  assert.equal(ledger.status, "pending_refund_window");
  assert.equal(ledger.adjustedCommissionMinor, 200);
  assert.equal(ledger.financialExposureEpoch, sale.financialEpoch);
});

test("fee dispute closure preserves a fully refunded fee", async () => {
  const memory = feeOnlyFixture();
  await memory.db.collection("marketplace_transactions").doc("external-1").set({
    marketplaceFeeStatus: "refunded",
    marketplaceFeeRefundedMinor: 1000,
    financialHold: true,
  }, {merge: true});
  const financial = createMarketplaceFinancialResolution(memory.admin);
  await financial.handleDisputeEvent(
      feeDispute("won", "du_FeeRefunded1"),
      "charge.dispute.closed",
  );
  const sale = memory.read("marketplace_transactions/external-1");
  assert.equal(sale.marketplaceFeeStatus, "refunded");
  assert.equal(sale.marketplaceFeeFinancialStatus, "refunded");
  assert.equal(sale.financialHold, true);
});

test("first-observed fee dispute win does not create a stranded hold", async () => {
  const memory = feeOnlyFixture();
  const financial = createMarketplaceFinancialResolution(memory.admin);
  await financial.handleDisputeEvent(
      feeDispute("won", "du_FeeWonFirst1"),
      "charge.dispute.closed",
  );
  const sale = memory.read("marketplace_transactions/external-1");
  assert.equal(sale.marketplaceFeeStatus, "collected");
  assert.equal(sale.marketplaceFeeDisputeStatus, "won");
  assert.equal(sale.financialHold, false);
});

test("fee dispute voids a claimed affiliate payout before dispatch", async () => {
  const memory = feeOnlyFixture();
  await memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1").set({
        eligibleAfter: {toMillis: () => 0},
      }, {merge: true});
  const financial = createMarketplaceFinancialResolution(memory.admin);
  let stripeCalls = 0;
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      stripeCalls += 1;
      return {id: "tr_affiliate_1"};
    },
    beforePayoutAuthorization: async () => {
      await financial.handleDisputeEvent(
          feeDispute("under_review", "du_FeePayoutRace1"),
          "charge.dispute.created",
      );
    },
  });
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  const result = await payouts.processLedger(await ledgerRef.get());
  assert.equal(result, "financial_hold");
  assert.equal(stripeCalls, 0);
  assert.equal(memory.read(ledgerRef.path).status, "void_financial_event");
});

test("fee refund after payout reservation aborts without recovery debt", async () => {
  const memory = feeOnlyFixture();
  await memory.db.collection("payment_provider_accounts")
      .doc("affiliate-1").set({
        transferStatus: "active",
        stripeAccountId: "acct_affiliate_1",
      }, {merge: true});
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  await ledgerRef.set({eligibleAfter: {toMillis: () => 0}}, {merge: true});
  const financial = createMarketplaceFinancialResolution(memory.admin);
  const gate = createMarketplaceRefundWebhookGate(memory.admin, financial);
  let stripeCalls = 0;
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      stripeCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
    afterPayoutAuthorization: async () => {
      assert.equal(memory.read(ledgerRef.path).status, "payout_reserved");
      await gate.recordRefundForManualRecovery({
        id: "ch_Fee1",
        amount: 1000,
        amount_refunded: 1000,
        refunded: true,
        currency: "usd",
      });
    },
  });
  assert.equal(await payouts.processLedger(await ledgerRef.get()),
      "financial_hold");
  assert.equal(stripeCalls, 0);
  assert.equal(memory.read(ledgerRef.path).status, "void_refunded");
  assert.equal(
      memory.read(
          "affiliate_recovery_obligations/marketplace_external-1_affiliate-1",
      ),
      undefined,
  );
  assert.equal(
      memory.read("payment_provider_accounts/affiliate-1")
          .affiliatePayoutHold,
      false,
  );
});

test("fee dispute during affiliate dispatch records paid recovery exposure", async () => {
  const memory = feeOnlyFixture();
  await memory.db.collection("payment_provider_accounts")
      .doc("affiliate-1").set({
        transferStatus: "active",
        stripeAccountId: "acct_affiliate_1",
      }, {merge: true});
  await memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1").set({
        eligibleAfter: {toMillis: () => 0},
      }, {merge: true});
  const financial = createMarketplaceFinancialResolution(memory.admin);
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => ({id: "tr_affiliate_race_1"}),
    afterPayoutDispatchCheck: async () => {
      await financial.handleDisputeEvent(
          feeDispute("under_review", "du_FeePayoutDispatch1"),
          "charge.dispute.created",
      );
    },
  });
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  const result = await payouts.processLedger(await ledgerRef.get());
  const ledger = memory.read(ledgerRef.path);
  const obligation = memory.read(
      "affiliate_recovery_obligations/marketplace_external-1_affiliate-1",
  );
  assert.equal(result, "paid");
  assert.equal(ledger.status, "paid");
  assert.equal(ledger.contingentDisputeHold, true);
  assert.equal(obligation.amountDueMinor, 200);
  assert.equal(obligation.status, "open");
});

test("fee refund finalizes atomically when affiliate payout has passed dispatch CAS", async () => {
  const memory = feeOnlyFixture();
  await memory.db.collection("payment_provider_accounts")
      .doc("affiliate-1").set({
        transferStatus: "active",
        stripeAccountId: "acct_affiliate_1",
      }, {merge: true});
  await memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1").set({
        eligibleAfter: {toMillis: () => 0},
      }, {merge: true});
  const financial = createMarketplaceFinancialResolution(memory.admin);
  const gate = createMarketplaceRefundWebhookGate(memory.admin, financial);
  let refundApplied = false;
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => ({id: "tr_affiliate_refund_race_1"}),
    afterPayoutDispatchCheck: async () => {
      await gate.recordRefundForManualRecovery({
        id: "ch_Fee1",
        amount: 1000,
        amount_refunded: 1000,
        refunded: true,
        currency: "usd",
      });
      refundApplied = true;
    },
  });
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  const result = await payouts.processLedger(await ledgerRef.get());
  const ledger = memory.read(ledgerRef.path);
  const obligation = memory.read(
      "affiliate_recovery_obligations/marketplace_external-1_affiliate-1",
  );
  assert.equal(refundApplied, true);
  assert.equal(result, "paid");
  assert.equal(ledger.status, "paid");
  assert.equal(ledger.contingentDisputeHold, true);
  assert.equal(obligation.amountDueMinor, 200);
  assert.equal(obligation.status, "open");
  assert.equal(
      memory.read("payment_provider_accounts/affiliate-1")
          .affiliatePayoutHold,
      true,
  );
});

test("ambiguous affiliate transfer retries the immutable request after exposure changes", async () => {
  const memory = feeOnlyFixture();
  await memory.db.collection("payment_provider_accounts")
      .doc("affiliate-1").set({
        transferStatus: "active",
        stripeAccountId: "acct_affiliate_1",
      }, {merge: true});
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  await ledgerRef.set({eligibleAfter: {toMillis: () => 0}}, {merge: true});
  const requests = [];
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      requests.push(request);
      if (requests.length === 1) {
        const error = new Error("connection reset after transfer acceptance");
        error.code = "ECONNRESET";
        throw error;
      }
      return {id: "tr_affiliate_ambiguous_1"};
    },
  });
  assert.equal(await payouts.processLedger(await ledgerRef.get()), "retry");
  const firstAttemptId = memory.read(ledgerRef.path).payoutAttemptId;
  assert.equal(memory.read(ledgerRef.path).status, "payout_outcome_unknown");

  const financial = createMarketplaceFinancialResolution(memory.admin);
  await financial.handleDisputeEvent(
      feeDispute("under_review", "du_FeeAmbiguous1"),
      "charge.dispute.created",
  );
  await ledgerRef.set({nextRetryAt: {toMillis: () => 0}}, {merge: true});
  assert.equal(await payouts.processLedger(await ledgerRef.get()), "paid");

  const ledger = memory.read(ledgerRef.path);
  const obligation = memory.read(
      "affiliate_recovery_obligations/marketplace_external-1_affiliate-1",
  );
  assert.equal(requests.length, 2);
  assert.equal(requests[0].idempotencyKey, requests[1].idempotencyKey);
  assert.deepEqual(requests[0].fields, requests[1].fields);
  assert.equal(ledger.payoutAttemptId, firstAttemptId);
  assert.equal(ledger.status, "paid");
  assert.equal(ledger.paidCommissionMinor, 200);
  assert.equal(obligation.amountDueMinor, 200);
  assert.equal(obligation.status, "open");
});

test("affiliate payout rejects missing currency before Stripe dispatch", async () => {
  const memory = feeOnlyFixture();
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  await ledgerRef.set({
    currency: "",
    eligibleAfter: {toMillis: () => 0},
  }, {merge: true});
  let stripeCalls = 0;
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      stripeCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
  });
  assert.equal(await payouts.processLedger(await ledgerRef.get()), "invalid");
  assert.equal(stripeCalls, 0);
  assert.equal(memory.read(ledgerRef.path).status, "invalid");
});

test("ambiguous payout without immutable request stays blocked across runs", async () => {
  const memory = feeOnlyFixture("payout_outcome_unknown");
  const ledgerRef = memory.db.collection("affiliate_commission_ledger")
      .doc("marketplace_external-1");
  await ledgerRef.set({
    payoutAttemptId: "legacy-attempt-without-snapshot",
    nextRetryAt: {toMillis: () => 0},
  }, {merge: true});
  let stripeCalls = 0;
  const payouts = createAffiliatePayouts(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      stripeCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
  });
  assert.equal(await payouts.processLedger(await ledgerRef.get()), "skipped");
  assert.equal(
      memory.read(ledgerRef.path).status,
      "eligible_financial_review_required",
  );
  const firstAttemptId = memory.read(ledgerRef.path).payoutAttemptId;
  assert.equal(await payouts.processLedger(await ledgerRef.get()), "skipped");
  assert.equal(memory.read(ledgerRef.path).payoutAttemptId, firstAttemptId);
  assert.equal(stripeCalls, 0);
});

test("full-sale refund exposure cannot regress from full to stale partial", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-refund-monotonic": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_RefundMonotonic1",
      buyerChargedMinor: 1000,
      sellerProceedsMinor: 900,
      originalSellerProceedsMinor: 900,
      sellerPayoutTransferIds: [],
      paymentProviderStatus: "paid",
      marketplaceFeeStatus: "collected",
      financialEpoch: 1,
      financialHold: false,
    },
    "affiliate_commission_ledger/marketplace_sale-refund-monotonic": {
      transactionId: "sale-refund-monotonic",
      referrerUid: "affiliate-1",
      currency: "USD",
      commissionMinor: 100,
      status: "pending_refund_window",
    },
  });
  const financial = createMarketplaceFinancialResolution(memory.admin);
  await financial.reconcileChargeRefund({
    id: "ch_RefundMonotonic1",
    amount: 1000,
    amount_refunded: 1000,
    refunded: true,
  });
  await financial.reconcileChargeRefund({
    id: "ch_RefundMonotonic1",
    amount: 1000,
    amount_refunded: 400,
    refunded: false,
  });
  const sale = memory.read(
      "marketplace_transactions/sale-refund-monotonic",
  );
  const ledger = memory.read(
      "affiliate_commission_ledger/marketplace_sale-refund-monotonic",
  );
  assert.equal(sale.refundedMinor, 1000);
  assert.equal(sale.paymentProviderStatus, "refunded");
  assert.equal(sale.financialStatus, "refunded");
  assert.equal(ledger.adjustedCommissionMinor, 0);
  assert.equal(ledger.status, "void_financial_event");
});

test("manual fee refund exposure cannot regress from full to stale partial", async () => {
  const memory = feeOnlyFixture();
  const financial = createMarketplaceFinancialResolution(memory.admin);
  const gate = createMarketplaceRefundWebhookGate(memory.admin, financial);
  await gate.recordRefundForManualRecovery({
    id: "ch_Fee1",
    amount: 1000,
    amount_refunded: 1000,
    refunded: true,
    currency: "usd",
  });
  await gate.recordRefundForManualRecovery({
    id: "ch_Fee1",
    amount: 1000,
    amount_refunded: 300,
    refunded: false,
    currency: "usd",
  });
  const sale = memory.read("marketplace_transactions/external-1");
  const ledger = memory.read(
      "affiliate_commission_ledger/marketplace_external-1",
  );
  assert.equal(sale.marketplaceFeeRefundedMinor, 1000);
  assert.equal(sale.marketplaceFeeStatus, "refunded");
  assert.equal(ledger.adjustedCommissionMinor, 0);
  assert.equal(ledger.status, "void_refunded");
});

test("fee dispute amount and terminal outcome helpers are monotonic", () => {
  assert.equal(financialChargeAmount({
    marketplaceFeeBuyerChargedMinor: 1250,
    buyerChargedMinor: 500000,
  }, "marketplace_fee_only"), 1250);
  assert.equal(resolvedDisputeOutcome("won", "open"), "won");
  assert.equal(resolvedDisputeOutcome("lost", "won"), "lost");
  assert.equal(resolvedDisputeOutcome("open", "won"), "won");
});

test("older refund failures cannot regress a succeeded refund", () => {
  assert.equal(refundStatusShouldApply({
    currentStatus: "succeeded",
    currentEventCreated: 200,
    incomingStatus: "failed",
    incomingEventCreated: 100,
  }), false);
  assert.equal(refundStatusShouldApply({
    currentStatus: "pending",
    currentEventCreated: 100,
    incomingStatus: "succeeded",
    incomingEventCreated: 200,
  }), true);
  assert.equal(refundStatusShouldApply({
    currentStatus: "succeeded",
    incomingStatus: "failed",
  }), false);
  assert.equal(refundStatusShouldApply({
    currentStatus: "pending",
    currentEventCreated: 300,
    currentEventId: "evt_pending_success",
    incomingStatus: "succeeded",
    incomingEventCreated: 300,
    incomingEventId: "evt_terminal_success",
  }), true);
  assert.equal(refundStatusShouldApply({
    currentStatus: "pending",
    currentEventCreated: 400,
    currentEventId: "evt_pending_failure",
    incomingStatus: "failed",
    incomingEventCreated: 400,
    incomingEventId: "evt_terminal_failure",
  }), true);
  assert.equal(refundStatusShouldApply({
    currentStatus: "failed",
    currentEventCreated: 450,
    currentEventId: "evt_failed",
    incomingStatus: "succeeded",
    incomingEventCreated: 450,
    incomingEventId: "evt_succeeded",
  }), true);
  assert.equal(refundStatusShouldApply({
    currentStatus: "succeeded",
    currentEventCreated: 450,
    currentEventId: "evt_succeeded",
    incomingStatus: "failed",
    incomingEventCreated: 450,
    incomingEventId: "evt_failed",
  }), false);
  assert.equal(refundStatusShouldApply({
    currentStatus: "pending",
    currentEventCreated: 500,
    currentEventId: "evt_same",
    incomingStatus: "succeeded",
    incomingEventCreated: 500,
    incomingEventId: "evt_same",
  }), false);
});

test("equal-second failed refund status triggers seller restoration", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-refund-status": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_RefundStatus1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      paymentProviderStatus: "paid",
      financialEpoch: 4,
      financialHold: true,
    },
    "marketplace_financial_cases/refund-case-1": {
      type: "refund_request",
      transactionId: "sale-refund-status",
      refundStatus: "pending",
      lastStripeRefundEventCreated: 800,
      lastStripeRefundEventId: "evt_refund_pending",
      status: "refund_pending",
    },
  });
  const rebalances = [];
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    sellerFunds: {
      rebalanceSellerFunds: async (request) => {
        rebalances.push(request);
        return {
          outstandingRecoveryMinor: 0,
          outstandingRestorationMinor: 0,
        };
      },
    },
  });
  const result = await financial.handleRefundStatusEvent({
    id: "re_RefundFailed1",
    status: "failed",
    metadata: {pipeBuyerFinancialCaseId: "refund-case-1"},
  }, "refund.failed", 800, "evt_refund_failed");
  assert.equal(result.status, "failed");
  assert.equal(rebalances.length, 1);
  assert.equal(rebalances[0].allowRestoration, true);
  assert.equal(
      memory.read("marketplace_financial_cases/refund-case-1").refundStatus,
      "failed",
  );
});

test("failed refund restoration retries the same terminal event after stale work", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-refund-retry": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_RefundRetry1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      paymentProviderStatus: "paid",
      financialEpoch: 2,
      financialHold: true,
    },
    "marketplace_financial_cases/refund-case-retry": {
      type: "refund_request",
      transactionId: "sale-refund-retry",
      refundStatus: "pending",
      lastStripeRefundEventCreated: 900,
      lastStripeRefundEventId: "evt_refund_pending_retry",
      status: "refund_pending",
    },
  });
  let calls = 0;
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    sellerFunds: {
      rebalanceSellerFunds: async () => {
        calls += 1;
        return calls === 1 ? {stale: true} : {
          stale: false,
          inProgress: false,
          outstandingRecoveryMinor: 0,
          outstandingRestorationMinor: 0,
        };
      },
    },
  });
  const refund = {
    id: "re_RefundRetry1",
    status: "failed",
    metadata: {pipeBuyerFinancialCaseId: "refund-case-retry"},
  };
  await assert.rejects(
      financial.handleRefundStatusEvent(
          refund,
          "refund.failed",
          900,
          "evt_refund_failed_retry",
      ),
      /restoration changed/u,
  );
  assert.equal(
      memory.read("marketplace_financial_cases/refund-case-retry").status,
      "refund_restoration_reconciliation_required",
  );
  const retried = await financial.handleRefundStatusEvent(
      refund,
      "refund.failed",
      900,
      "evt_refund_failed_retry",
  );
  assert.equal(retried.status, "failed");
  assert.equal(calls, 2);
  assert.equal(
      memory.read("marketplace_financial_cases/refund-case-retry").status,
      "refund_retry_required",
  );
});

test("stale dispute completion cannot clear a newer refund hold", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_Sale1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      paymentProviderStatus: "paid",
      financialEpoch: 2,
      financialHold: false,
    },
    "platform_configuration/payment_provider_readiness": {
      marketplaceDisputeAutomationEnabled: false,
    },
  });
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    beforeSaleDisputeFinalization: async () => {
      const ref = memory.db.collection("marketplace_transactions").doc("sale-1");
      await memory.db.runTransaction(async (transaction) => {
        const current = await transaction.get(ref);
        transaction.set(ref, financialMutationValues(current.data(), {
          financialStatus: "refund_processing",
          activeFinancialCaseId: "refund-newer",
        }), {merge: true});
      });
    },
  });
  await financial.handleDisputeEvent({
    id: "du_SaleWon1",
    charge: "ch_Sale1",
    amount: 10000,
    currency: "usd",
    reason: "fraudulent",
    status: "won",
    evidence_details: {submission_count: 0},
  }, "charge.dispute.closed");
  const sale = memory.read("marketplace_transactions/sale-1");
  assert.equal(sale.financialStatus, "refund_processing");
  assert.equal(sale.activeFinancialCaseId, "refund-newer");
  assert.equal(sale.financialHold, true);
});

test("stale seller restoration is compensated after financial epoch changes", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_SaleRestore1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      originalSellerProceedsMinor: 9500,
      stripeSellerTransferId: "tr_Original1",
      sellerPayoutTransferIds: ["tr_Original1"],
      stripeTransferGroup: "PB_sale-1",
      paymentProviderStatus: "paid",
      financialEpoch: 2,
      financialHold: false,
    },
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
    "platform_configuration/payment_provider_readiness": {
      marketplaceDisputeAutomationEnabled: true,
    },
  });
  const calls = [];
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    sellerFundsOptions: {
      stripeSecret: () => "test-secret",
      stripeRequest: async (request) => {
        calls.push(request.path);
        if (request.path === "/v1/transfers/tr_Original1") {
          return {amount: 9500, amount_reversed: 9500};
        }
        if (request.path === "/v1/transfers") {
          const ref = memory.db.collection("marketplace_transactions")
              .doc("sale-1");
          await memory.db.runTransaction(async (transaction) => {
            const current = await transaction.get(ref);
            transaction.set(ref, financialMutationValues(current.data(), {
              financialStatus: "refund_processing",
              activeFinancialCaseId: "refund-newer",
            }), {merge: true});
          });
          return {id: "tr_StaleRestoration1"};
        }
        assert.equal(
            request.path,
            "/v1/transfers/tr_StaleRestoration1/reversals",
        );
        return {id: "trr_stale_restoration_1"};
      },
    },
  });
  await financial.handleDisputeEvent({
    id: "du_SaleRestoreWon1",
    charge: "ch_SaleRestore1",
    amount: 10000,
    currency: "usd",
    reason: "fraudulent",
    status: "won",
    evidence_details: {submission_count: 0},
  }, "charge.dispute.closed");
  const sale = memory.read("marketplace_transactions/sale-1");
  assert.deepEqual(calls, [
    "/v1/transfers/tr_Original1",
    "/v1/transfers",
    "/v1/transfers/tr_StaleRestoration1/reversals",
  ]);
  assert.equal(sale.financialStatus, "refund_processing");
  assert.equal(sale.activeFinancialCaseId, "refund-newer");
  assert.equal(sale.financialHold, true);
  assert.deepEqual(
      sale.sellerRebalanceInvalidatedTransferIds,
      ["tr_StaleRestoration1"],
  );
  assert.deepEqual(
      sale.sellerRebalanceCompensationReversalIds,
      ["trr_stale_restoration_1"],
  );
});

test("ambiguous seller restoration retries the exact reserved request", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-restoration-retry": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_RestorationRetry1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      originalSellerProceedsMinor: 9500,
      stripeSellerTransferId: "tr_OriginalRetry1",
      sellerPayoutTransferIds: ["tr_OriginalRetry1"],
      stripeTransferGroup: "PB_sale_restoration_retry",
      paymentProviderStatus: "paid",
      financialEpoch: 6,
      financialHold: false,
    },
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  const restorationRequests = [];
  let firstRestoration = true;
  const sellerFunds = createMarketplaceSellerFunds(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      if (request.path === "/v1/transfers/tr_OriginalRetry1") {
        return {amount: 9500, amount_reversed: 9500};
      }
      if (request.path === "/v1/transfers/tr_RestorationRetry1") {
        return {amount: 9500, amount_reversed: 0};
      }
      assert.equal(request.path, "/v1/transfers");
      restorationRequests.push(request);
      if (firstRestoration) {
        firstRestoration = false;
        const error = new Error("connection lost after Stripe accepted transfer");
        error.code = "ECONNRESET";
        throw error;
      }
      return {id: "tr_RestorationRetry1"};
    },
  });
  const sale = memory.read(
      "marketplace_transactions/sale-restoration-retry",
  );
  const first = await sellerFunds.rebalanceSellerFunds({
    transactionId: "sale-restoration-retry",
    sale,
    caseId: "dispute-restoration-retry",
    customerExposureMinor: 0,
    reason: "dispute_closed_restoration",
    allowRestoration: true,
    expectedFinancialEpoch: 6,
  });
  assert.equal(first.failures[0].ambiguous, true);
  assert.equal(
      memory.read("marketplace_transactions/sale-restoration-retry")
          .sellerRestorationRequestState,
      "outcome_unknown",
  );
  assert.equal(
      memory.read("marketplace_transactions/sale-restoration-retry")
          .financialHold,
      true,
  );

  const second = await sellerFunds.rebalanceSellerFunds({
    transactionId: "sale-restoration-retry",
    sale,
    caseId: "dispute-restoration-retry",
    customerExposureMinor: 0,
    reason: "dispute_closed_restoration",
    allowRestoration: true,
    expectedFinancialEpoch: 6,
  });
  assert.equal(second.outstandingRestorationMinor, 0);
  assert.equal(restorationRequests.length, 2);
  assert.equal(
      restorationRequests[0].idempotencyKey,
      restorationRequests[1].idempotencyKey,
  );
  assert.deepEqual(
      restorationRequests[0].fields,
      restorationRequests[1].fields,
  );
  const updated = memory.read(
      "marketplace_transactions/sale-restoration-retry",
  );
  assert.equal(updated.sellerRestorationRequestState, "succeeded");
  assert.deepEqual(updated.sellerPayoutTransferIds, [
    "tr_OriginalRetry1",
    "tr_RestorationRetry1",
  ]);
  assert.equal(updated.financialHold, false);
});

test("financial mutation after restoration reservation prevents transfer", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-restoration-race": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_RestorationRace1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      originalSellerProceedsMinor: 9500,
      stripeSellerTransferId: "tr_OriginalRace1",
      sellerPayoutTransferIds: ["tr_OriginalRace1"],
      stripeTransferGroup: "PB_sale_restoration_race",
      paymentProviderStatus: "paid",
      financialEpoch: 6,
      financialHold: false,
      activeFinancialCaseId: "dispute-restoration-race",
    },
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  const providerPaths = [];
  const sellerFunds = createMarketplaceSellerFunds(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      providerPaths.push(request.path);
      assert.equal(request.path, "/v1/transfers/tr_OriginalRace1");
      return {amount: 9500, amount_reversed: 9500};
    },
    afterRestorationRequestReservation: async () => {
      await memory.db.runTransaction(async (transaction) => {
        const ref = memory.db.collection("marketplace_transactions")
            .doc("sale-restoration-race");
        const current = await transaction.get(ref);
        transaction.set(ref, financialMutationValues(current.data(), {
          activeFinancialCaseId: "refund-newer",
          financialStatus: "refund_processing",
        }), {merge: true});
      });
    },
  });

  const result = await sellerFunds.rebalanceSellerFunds({
    transactionId: "sale-restoration-race",
    sale: memory.read("marketplace_transactions/sale-restoration-race"),
    caseId: "dispute-restoration-race",
    customerExposureMinor: 0,
    reason: "dispute_closed_restoration",
    allowRestoration: true,
    expectedFinancialEpoch: 6,
  });
  const sale = memory.read("marketplace_transactions/sale-restoration-race");
  assert.equal(result.stale, true);
  assert.deepEqual(providerPaths, ["/v1/transfers/tr_OriginalRace1"]);
  assert.equal(sale.sellerRestorationRequestState, "abandoned");
  assert.equal(sale.sellerRestorationRequestTransferId, undefined);
  assert.equal(sale.sellerRebalanceInvalidatedTransferIds, undefined);
  assert.equal(sale.sellerRebalanceRecoveryOutstandingMinor, undefined);
});

function administratorRefundRequest(caseId) {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "totp"},
      },
    },
    data: {caseId, refundReasonCode: "requested_by_customer"},
    rawRequest: {path: "/executeMarketplaceRefund"},
  };
}

function executableRefundFixture(caseId = "refund-race") {
  return createMemoryAdmin({
    "marketplace_transactions/sale-refund-race": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      currency: "USD",
      stripeChargeId: "ch_RefundRace1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      originalSellerProceedsMinor: 9500,
      paymentProvider: "stripe",
      paymentProviderStatus: "paid",
      financialStatus: "refund_requested",
      financialEpoch: 2,
      financialHold: true,
      activeFinancialCaseId: caseId,
      refundedMinor: 0,
    },
    [`marketplace_financial_cases/${caseId}`]: {
      type: "refund_request",
      transactionId: "sale-refund-race",
      requestedRefundMinor: 1000,
      requestedByUid: "buyer-1",
      currency: "USD",
      status: "requested",
    },
    "platform_configuration/payment_provider_readiness": {
      stripeMode: "sandbox",
      stripeWebhookVerified: true,
      stripeReconciliationReady: true,
      marketplaceFinancialResolutionEnabled: true,
      platformFundedRefundOverrideEnabled: false,
    },
  });
}

test("dispute mutation after refund reservation prevents Stripe dispatch", async () => {
  const memory = executableRefundFixture();
  const providerPaths = [];
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      providerPaths.push(request.path);
      if (request.method === "GET") {
        return {
          id: "ch_RefundRace1",
          amount: 10000,
          amount_refunded: 0,
          currency: "usd",
        };
      }
      return {id: "re_should_not_dispatch", status: "succeeded"};
    },
    sellerFunds: {
      rebalanceSellerFunds: async () => ({
        stale: false,
        inProgress: false,
        outstandingRecoveryMinor: 0,
        outstandingRestorationMinor: 0,
        failures: [],
      }),
    },
    afterRefundRequestReservation: async () => {
      await memory.db.runTransaction(async (transaction) => {
        const ref = memory.db.collection("marketplace_transactions")
            .doc("sale-refund-race");
        const current = await transaction.get(ref);
        transaction.set(ref, financialMutationValues(current.data(), {
          disputeStatus: "open",
          activeDisputeIds: ["du_refund_race"],
          financialStatus: "disputed",
        }), {merge: true});
      });
    },
  });

  await assert.rejects(
      financial.executeMarketplaceRefund(
          administratorRefundRequest("refund-race"),
      ),
      (error) => error && error.code === "aborted",
  );
  const financialCase = memory.read(
      "marketplace_financial_cases/refund-race",
  );
  assert.deepEqual(providerPaths, ["/v1/charges/ch_RefundRace1"]);
  assert.equal(financialCase.refundRequestState, "reserved");
  assert.equal(financialCase.status, "refund_retry_required");
  assert.equal(financialCase.stripeRefundId, undefined);
});

test("ambiguous refund retry reuses the exact immutable provider request", async () => {
  const memory = executableRefundFixture("refund-ambiguous");
  const refundRequests = [];
  let firstRefund = true;
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      if (request.method === "GET") {
        return {
          id: "ch_RefundRace1",
          amount: 10000,
          amount_refunded: 0,
          currency: "usd",
        };
      }
      refundRequests.push(request);
      if (firstRefund) {
        firstRefund = false;
        const error = new Error("connection lost after refund acceptance");
        error.code = "ECONNRESET";
        throw error;
      }
      return {id: "re_RefundRace1", status: "succeeded"};
    },
    sellerFunds: {
      rebalanceSellerFunds: async () => ({
        stale: false,
        inProgress: false,
        outstandingRecoveryMinor: 0,
        outstandingRestorationMinor: 0,
        failures: [],
      }),
    },
  });
  const request = administratorRefundRequest("refund-ambiguous");
  await assert.rejects(
      financial.executeMarketplaceRefund(request),
      (error) => error && error.code === "failed-precondition",
  );
  assert.equal(
      memory.read("marketplace_financial_cases/refund-ambiguous")
          .refundRequestState,
      "outcome_unknown",
  );
  const result = await financial.executeMarketplaceRefund(request);
  assert.equal(result.status, "succeeded");
  assert.equal(refundRequests.length, 2);
  assert.equal(refundRequests[0].idempotencyKey, refundRequests[1].idempotencyKey);
  assert.deepEqual(refundRequests[0].fields, refundRequests[1].fields);
});

test("dispute win preserves a pending refund hold and forbids restoration", async () => {
  const memory = executableRefundFixture("refund-pending");
  const rebalances = [];
  await memory.db.collection("marketplace_transactions")
      .doc("sale-refund-race").set({
        stripeSellerTransferId: "tr_RefundPending1",
        sellerPayoutTransferIds: ["tr_RefundPending1"],
      }, {merge: true});
  await memory.db.collection("platform_configuration")
      .doc("payment_provider_readiness").set({
        marketplaceDisputeAutomationEnabled: true,
      }, {merge: true});
  const financial = createMarketplaceFinancialResolution(memory.admin, {
    sellerFunds: {
      rebalanceSellerFunds: async (args) => {
        rebalances.push(args);
        return {
          stale: false,
          inProgress: false,
          outstandingRecoveryMinor: 0,
          outstandingRestorationMinor: 9500,
          failures: [],
        };
      },
    },
  });

  await financial.handleDisputeEvent({
    id: "du_RefundPendingWon1",
    charge: "ch_RefundRace1",
    amount: 10000,
    currency: "usd",
    status: "won",
    evidence_details: {submission_count: 0},
  }, "charge.dispute.closed");
  const sale = memory.read("marketplace_transactions/sale-refund-race");
  assert.equal(rebalances.length, 1);
  assert.equal(rebalances[0].allowRestoration, false);
  assert.equal(sale.financialStatus, "refund_requested");
  assert.equal(sale.financialHold, true);
  assert.equal(sale.activeFinancialCaseId, "refund-pending");
  assert.equal(sale.sellerRestorationOutstandingMinor, 9500);
});

test("seller restoration rejects missing currency before transfer dispatch", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-restoration-no-currency": {
      listingId: "listing-1",
      buyerUid: "buyer-1",
      sellerUid: "seller-1",
      buyerChargedMinor: 10000,
      sellerProceedsMinor: 9500,
      originalSellerProceedsMinor: 9500,
      sellerPayoutTransferIds: [],
      paymentProviderStatus: "paid",
      financialEpoch: 3,
      financialHold: false,
    },
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  let stripeCalls = 0;
  const sellerFunds = createMarketplaceSellerFunds(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      stripeCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
  });
  await assert.rejects(
      sellerFunds.rebalanceSellerFunds({
        transactionId: "sale-restoration-no-currency",
        sale: memory.read(
            "marketplace_transactions/sale-restoration-no-currency",
        ),
        caseId: "restore-no-currency",
        customerExposureMinor: 0,
        reason: "restoration",
        allowRestoration: true,
        expectedFinancialEpoch: 3,
      }),
      (error) => error && error.code === "failed-precondition",
  );
  assert.equal(stripeCalls, 0);
});
