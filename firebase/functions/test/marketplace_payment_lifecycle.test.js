"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  auctionMirrorShouldApply,
  createMarketplacePaymentLifecycle,
  releaseEligible,
  sourceRevision,
  transactionIdForAuction,
} = require("../marketplace_payment_lifecycle");
const {financialMutationValues} = require("../marketplace_financial_epoch");
const {createMemoryAdmin} = require("./memory_firestore");

test("Timed Buying maps to one deterministic marketplace transaction id", () => {
  assert.equal(transactionIdForAuction("listing-123"), "auction_listing-123");
});

test("seller release requires paid physical-goods completion", () => {
  const paid = {
    status: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    refundedMinor: 0,
    financialHold: false,
  };
  assert.equal(releaseEligible(paid), true);
  assert.equal(releaseEligible({...paid, status: "pending_completion"}), false);
  assert.equal(releaseEligible({...paid, paymentProviderStatus: "processing"}), false);
  assert.equal(releaseEligible({...paid, refundedMinor: 1}), false);
  assert.equal(releaseEligible({...paid, disputeStatus: "open"}), false);
});

test("Timed Buying completion may release after the winner has paid", () => {
  assert.equal(releaseEligible({
    status: "pending_payment",
    auctionSettlementStatus: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    refundedMinor: 0,
  }), true);
});

test("Timed Buying mirror rejects reversed trigger delivery by source revision", async () => {
  const memory = createMemoryAdmin({
    "public_listings/listing-123": {
      title: "Drill collar lot",
      currency: "USD",
    },
  });
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin);
  const newest = {
    revision: 3,
    buyerUid: "buyer-1",
    sellerUid: "seller-1",
    status: "completed",
    buyerConfirmed: true,
    sellerConfirmed: true,
    agreedQuantity: 2,
    agreedTotal: 5000,
    currency: "USD",
  };
  await lifecycle.syncAuctionTransaction({
    listingId: "listing-123",
    transactionData: newest,
  });
  const stale = await lifecycle.syncAuctionTransaction({
    listingId: "listing-123",
    transactionData: {
      ...newest,
      revision: 2,
      status: "pending_completion",
      buyerConfirmed: false,
      sellerConfirmed: false,
    },
  });
  const mirror = memory.read("marketplace_transactions/auction_listing-123");
  assert.equal(stale.stale, true);
  assert.equal(mirror.auctionSourceRevision, 3);
  assert.equal(mirror.auctionSettlementStatus, "completed");
  assert.equal(mirror.buyerConfirmed, true);
  assert.equal(sourceRevision({revision: 9}), 9);
  assert.equal(auctionMirrorShouldApply(mirror, {revision: 2}), false);
});

test("Timed Buying mirror rejects missing currency instead of assuming CAD", async () => {
  const memory = createMemoryAdmin({
    "public_listings/listing-missing-currency": {
      title: "Legacy equipment lot",
    },
  });
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin);

  await assert.rejects(
      lifecycle.syncAuctionTransaction({
        listingId: "listing-missing-currency",
        transactionData: {
          revision: 1,
          buyerUid: "buyer-1",
          sellerUid: "seller-1",
          status: "pending_completion",
          agreedQuantity: 1,
          agreedTotal: 5000,
        },
      }),
      (error) => error &&
        error.name === "CommandPolicyError" &&
        error.code === "failed-precondition",
  );
  assert.equal(
      memory.read(
          "marketplace_transactions/auction_listing-missing-currency",
      ),
      undefined,
  );
});

function paidSale() {
  return {
    listingId: "listing-1",
    sellerUid: "seller-1",
    buyerUid: "buyer-1",
    status: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    sellerProceedsMinor: 9700,
    currency: "USD",
    stripeChargeId: "ch_paid_1",
    stripeTransferGroup: "PB_sale_1",
    refundedMinor: 0,
    financialEpoch: 2,
    financialHold: false,
  };
}

test("seller release rejects a legacy sale without explicit currency", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": {
      ...paidSale(),
      currency: undefined,
    },
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  let transferCalls = 0;
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      transferCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
  });
  await assert.rejects(
      lifecycle.releaseSellerFunds({transactionId: "sale-1"}),
      (error) => error && error.code === "failed-precondition",
  );
  assert.equal(transferCalls, 0);
});

test("seller release lease prevents concurrent transfer attempts", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": paidSale(),
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  let enterTransfer;
  const transferEntered = new Promise((resolve) => {
    enterTransfer = resolve;
  });
  let finishTransfer;
  const transferResult = new Promise((resolve) => {
    finishTransfer = resolve;
  });
  let transferCalls = 0;
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async ({path}) => {
      assert.equal(path, "/v1/transfers");
      transferCalls += 1;
      enterTransfer();
      return transferResult;
    },
  });
  const first = lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  await transferEntered;
  await assert.rejects(
      lifecycle.releaseSellerFunds({transactionId: "sale-1"}),
      (error) => error.code === "seller_release_in_progress",
  );
  finishTransfer({id: "tr_release_1"});
  const released = await first;
  assert.equal(released.released, true);
  assert.equal(transferCalls, 1);
  assert.equal(
      memory.read("marketplace_transactions/sale-1").stripeSellerTransferId,
      "tr_release_1",
  );
});

test("financial epoch invalidates and reverses an in-flight seller release", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": paidSale(),
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  const calls = [];
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      calls.push(request);
      if (request.path === "/v1/transfers") {
        await memory.db.runTransaction(async (transaction) => {
          const ref = memory.db.collection("marketplace_transactions")
              .doc("sale-1");
          const current = await transaction.get(ref);
          transaction.set(ref, {
            financialEpoch: Number(current.data().financialEpoch || 0) + 1,
            financialHold: true,
            financialStatus: "disputed",
            disputeStatus: "open",
            sellerPayoutStatus: "blocked_financial_hold",
          }, {merge: true});
        });
        return {id: "tr_invalidated_1"};
      }
      if (request.path === "/v1/transfers/tr_invalidated_1") {
        assert.equal(request.method, "GET");
        return {
          id: "tr_invalidated_1",
          amount: 9700,
          amount_reversed: 0,
        };
      }
      assert.equal(
          request.path,
          "/v1/transfers/tr_invalidated_1/reversals",
      );
      return {id: "trr_invalidated_1"};
    },
  });
  const result = await lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  const sale = memory.read("marketplace_transactions/sale-1");
  assert.equal(result.released, false);
  assert.equal(result.reason, "financial_epoch_invalidated_reversed");
  assert.equal(calls.length, 3);
  assert.equal(sale.stripeSellerTransferId, undefined);
  assert.equal(sale.sellerReleaseInvalidatedTransferId, "tr_invalidated_1");
  assert.deepEqual(
      sale.sellerReleaseInvalidationReversalIds,
      ["trr_invalidated_1"],
  );
  assert.equal(sale.sellerPayoutStatus, "blocked_financial_hold");
  assert.equal(sale.sellerReleaseRecoveryOutstandingMinor, 0);
});

test("refund after seller release reservation prevents provider dispatch", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": paidSale(),
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  let providerCalls = 0;
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      providerCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
    afterReleaseRequestReservation: async () => {
      await memory.db.runTransaction(async (transaction) => {
        const ref = memory.db.collection("marketplace_transactions")
            .doc("sale-1");
        const current = await transaction.get(ref);
        transaction.set(ref, financialMutationValues(current.data(), {
          financialStatus: "refunded",
          refundedMinor: 10000,
        }), {merge: true});
      });
    },
  });

  const result = await lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  const sale = memory.read("marketplace_transactions/sale-1");
  assert.equal(result.released, false);
  assert.equal(result.reason, "financial_epoch_invalidated");
  assert.equal(providerCalls, 0);
  assert.equal(sale.sellerPayoutStatus, "blocked_financial_hold");
  assert.equal(sale.sellerReleaseInvalidatedTransferId, undefined);
  assert.equal(sale.sellerReleaseRecoveryOutstandingMinor, undefined);
});

test("crashed seller release reservation stays non-escaped after mutation", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": paidSale(),
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  let providerCalls = 0;
  let crashAfterReserve = true;
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async () => {
      providerCalls += 1;
      return {id: "tr_should_not_dispatch"};
    },
    afterReleaseRequestReservation: async () => {
      if (crashAfterReserve) {
        crashAfterReserve = false;
        throw new Error("simulated worker crash after reservation");
      }
    },
  });

  await assert.rejects(
      lifecycle.releaseSellerFunds({transactionId: "sale-1"}),
      /simulated worker crash/u,
  );
  assert.equal(
      memory.read("marketplace_transactions/sale-1").sellerPayoutStatus,
      "release_reserved",
  );
  await memory.db.runTransaction(async (transaction) => {
    const ref = memory.db.collection("marketplace_transactions").doc("sale-1");
    const current = await transaction.get(ref);
    transaction.set(ref, financialMutationValues(current.data(), {
      financialStatus: "disputed",
      disputeStatus: "open",
    }), {merge: true});
  });
  const retry = await lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  const sale = memory.read("marketplace_transactions/sale-1");
  assert.equal(retry.reason, "not_ready");
  assert.equal(providerCalls, 0);
  assert.equal(sale.sellerPayoutStatus, "blocked_financial_hold");
  assert.equal(sale.sellerReleaseInvalidatedTransferId, undefined);
  assert.equal(sale.sellerReleaseRecoveryOutstandingMinor, undefined);
});

test("failed seller transfer retries the same request after lease expiry", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": paidSale(),
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  let clock = 1000;
  const transferRequests = [];
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    now: () => clock,
    releaseLeaseMillis: 1000,
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      transferRequests.push(request);
      if (transferRequests.length === 1) {
        throw new Error("temporary provider failure");
      }
      return {id: "tr_retry_1"};
    },
  });

  await assert.rejects(
      lifecycle.releaseSellerFunds({transactionId: "sale-1"}),
      /temporary provider failure/u,
  );
  await assert.rejects(
      lifecycle.releaseSellerFunds({transactionId: "sale-1"}),
      (error) => error.code === "seller_release_in_progress",
  );
  clock += 1001;
  const result = await lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  assert.equal(result.released, true);
  assert.equal(result.transferId, "tr_retry_1");
  assert.equal(transferRequests.length, 2);
  assert.equal(
      transferRequests[0].idempotencyKey,
      transferRequests[1].idempotencyKey,
  );
  assert.deepEqual(transferRequests[0].fields, transferRequests[1].fields);
});

test("ambiguous seller transfer reuses its request before invalidation reversal", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": paidSale(),
    "payment_provider_accounts/seller-1": {
      transferStatus: "active",
      stripeAccountId: "acct_seller_1",
      sellerPayoutHold: false,
    },
  });
  const transferRequests = [];
  let firstDispatch = true;
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    stripeSecret: () => "test-secret",
    stripeRequest: async (request) => {
      if (request.path === "/v1/transfers") {
        transferRequests.push(request);
        if (firstDispatch) {
          firstDispatch = false;
          await memory.db.runTransaction(async (transaction) => {
            const ref = memory.db.collection("marketplace_transactions")
                .doc("sale-1");
            const current = await transaction.get(ref);
            transaction.set(ref, financialMutationValues(current.data(), {
              financialStatus: "disputed",
              disputeStatus: "open",
            }), {merge: true});
          });
          const error = new Error("connection reset after Stripe accepted request");
          error.code = "ECONNRESET";
          throw error;
        }
        return {id: "tr_ambiguous_1"};
      }
      if (request.path === "/v1/transfers/tr_ambiguous_1") {
        return {
          id: "tr_ambiguous_1",
          amount: 9700,
          amount_reversed: 0,
        };
      }
      assert.equal(
          request.path,
          "/v1/transfers/tr_ambiguous_1/reversals",
      );
      return {id: "trr_ambiguous_1"};
    },
  });

  await assert.rejects(
      lifecycle.releaseSellerFunds({transactionId: "sale-1"}),
      /connection reset/u,
  );
  assert.equal(
      memory.read("marketplace_transactions/sale-1").sellerPayoutStatus,
      "release_invalidated_attempt_unknown",
  );

  const result = await lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  const sale = memory.read("marketplace_transactions/sale-1");
  assert.equal(result.reason, "invalidated_release_reversed");
  assert.equal(transferRequests.length, 2);
  assert.equal(
      transferRequests[0].idempotencyKey,
      transferRequests[1].idempotencyKey,
  );
  assert.deepEqual(transferRequests[0].fields, transferRequests[1].fields);
  assert.equal(sale.sellerReleaseInvalidatedTransferId, "tr_ambiguous_1");
  assert.deepEqual(
      sale.sellerReleaseInvalidationReversalIds,
      ["trr_ambiguous_1"],
  );
  assert.equal(sale.sellerPayoutStatus, "blocked_financial_hold");
  assert.equal(sale.sellerReleaseRecoveryOutstandingMinor, 0);
});

test("expired recovery worker cannot overwrite a newer successful recovery", async () => {
  const memory = createMemoryAdmin({
    "marketplace_transactions/sale-1": {
      ...paidSale(),
      sellerPayoutStatus: "release_invalidated_recovery_required",
      sellerReleaseAttemptId: "attempt-1",
      sellerReleaseInvalidatedTransferId: "tr_stale_recovery_1",
      sellerReleaseInvalidatedAmountMinor: 9700,
      sellerReleaseRecoveryOutstandingMinor: 9700,
      financialHold: true,
    },
  });
  let clock = 1000;
  let firstReadEntered;
  const firstReadStarted = new Promise((resolve) => {
    firstReadEntered = resolve;
  });
  let failFirstRead;
  const firstRead = new Promise((resolve, reject) => {
    failFirstRead = reject;
  });
  let reads = 0;
  const lifecycle = createMarketplacePaymentLifecycle(memory.admin, {
    now: () => clock,
    releaseLeaseMillis: 1000,
    stripeSecret: () => "test-secret",
    stripeRequest: async ({path}) => {
      assert.equal(path, "/v1/transfers/tr_stale_recovery_1");
      reads += 1;
      if (reads === 1) {
        firstReadEntered();
        return firstRead;
      }
      if (reads === 2) {
        return {amount: 9700, amount_reversed: 9700};
      }
      throw new Error("stale recovery worker failed");
    },
  });

  const staleWorker = lifecycle.releaseSellerFunds({transactionId: "sale-1"});
  await firstReadStarted;
  clock += 1001;
  const currentWorker = await lifecycle.releaseSellerFunds({
    transactionId: "sale-1",
  });
  assert.equal(currentWorker.reason, "invalidated_release_reversed");
  failFirstRead(new Error("old request failed"));
  const staleResult = await staleWorker;
  assert.equal(staleResult.reason, "invalidated_release_recovery_required");

  const sale = memory.read("marketplace_transactions/sale-1");
  assert.equal(sale.sellerPayoutStatus, "blocked_financial_hold");
  assert.equal(sale.sellerReleaseRecoveryOutstandingMinor, 0);
  assert.equal(sale.sellerReleaseRecoveryLeaseId, "");
  assert.equal(sale.sellerReleaseRecoveryNextAttemptAtMillis, 0);
});
