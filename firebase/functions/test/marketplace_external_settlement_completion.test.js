"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  paymentStatusAllowsCompletion,
  validateAuctionTransactionAction,
  validateMarketplaceTransactionAction,
} = require("../marketplace_command_policy");
const {
  externalFeeCheckoutMatchesReservation,
  reserveExternalSettlementState,
  stripeCheckoutHasStarted,
  validateExternalSettlementWithdrawal,
} = require("../external_settlement_commands");
const {
  marketplaceStatusForAuctionSync,
} = require("../marketplace_payment_lifecycle");

function acceptedMarketplaceSale(overrides = {}) {
  return {
    offerId: "offer_1",
    listingId: "listing_1",
    buyerUid: "buyer_1",
    sellerUid: "seller_1",
    status: "pending_completion",
    buyerConfirmed: false,
    sellerConfirmed: false,
    paymentMethod: "external_settlement",
    paymentProvider: "external",
    paymentProviderStatus: "external_agreed",
    marketplaceFeeStatus: "pending_collection",
    ...overrides,
  };
}

const acceptedOffer = {
  id: "offer_1",
  listingId: "listing_1",
  buyerUid: "buyer_1",
  sellerUid: "seller_1",
  status: "accepted",
};

test("external completion requires the marketplace fee to be collected", () => {
  assert.equal(paymentStatusAllowsCompletion("paid", "pending_collection"), false);
  assert.equal(paymentStatusAllowsCompletion("paid", "collected"), true);
  assert.equal(
      paymentStatusAllowsCompletion("external_agreed", "pending_collection"),
      false,
  );
  assert.equal(
      paymentStatusAllowsCompletion("external_agreed", "checkout_created"),
      false,
  );
  assert.equal(
      paymentStatusAllowsCompletion("external_agreed", "collected"),
      true,
  );
});

test("completion fails closed for refund, dispute, chargeback, or financial hold", () => {
  for (const financialState of [
    {financialHold: true},
    {financialStatus: "disputed"},
    {financialStatus: "charged_back"},
    {financialStatus: "partially_refunded"},
    {refundedMinor: 1},
    {disputeStatus: "open"},
    {lostDisputeIds: ["du_lost"]},
    {marketplaceFeeDisputeStatus: "open"},
    {marketplaceFeeRefundedMinor: 1},
  ]) {
    assert.equal(
        paymentStatusAllowsCompletion("paid", "collected", financialState),
        false,
    );
    assert.equal(
        paymentStatusAllowsCompletion(
            "external_agreed",
            "collected",
            financialState,
        ),
        false,
    );
  }
});

test("Marketplace and Timed Buying reject completion during a financial hold", () => {
  assert.throws(
      () => validateMarketplaceTransactionAction({
        sale: acceptedMarketplaceSale({
          paymentProviderStatus: "paid",
          marketplaceFeeStatus: "collected",
          financialHold: true,
        }),
        offer: acceptedOffer,
        actorUid: "buyer_1",
        action: "confirm_completion",
      }),
      /Secure payment/u,
  );
  assert.throws(
      () => validateAuctionTransactionAction({
        sale: {
          listingId: "listing_1",
          buyerUid: "buyer_1",
          sellerUid: "seller_1",
          status: "pending_completion",
        },
        listing: {id: "listing_1"},
        actorUid: "buyer_1",
        action: "confirm_completion",
        paymentProviderStatus: "paid",
        marketplaceFeeStatus: "collected",
        paymentState: {
          financialStatus: "charged_back",
          financialHold: true,
        },
      }),
      /marketplace fee must be paid/u,
  );
});

test("Marketplace blocks external completion until its fee is collected", () => {
  assert.throws(
      () => validateMarketplaceTransactionAction({
        sale: acceptedMarketplaceSale(),
        offer: acceptedOffer,
        actorUid: "buyer_1",
        action: "confirm_completion",
      }),
      /marketplace fee for external settlement/u,
  );
  const transition = validateMarketplaceTransactionAction({
    sale: acceptedMarketplaceSale({marketplaceFeeStatus: "collected"}),
    offer: acceptedOffer,
    actorUid: "buyer_1",
    action: "confirm_completion",
  });
  assert.equal(transition.status, "awaiting_seller_confirmation");
  assert.equal(transition.buyerConfirmed, true);
});

test("Timed Buying uses the mirrored fee status before completion", () => {
  const sale = {
    listingId: "listing_1",
    buyerUid: "buyer_1",
    sellerUid: "seller_1",
    status: "pending_completion",
  };
  const listing = {id: "listing_1"};
  assert.throws(
      () => validateAuctionTransactionAction({
        sale,
        listing,
        actorUid: "buyer_1",
        action: "confirm_completion",
        paymentProviderStatus: "external_agreed",
        marketplaceFeeStatus: "pending_collection",
      }),
      /marketplace fee must be paid/u,
  );
  const transition = validateAuctionTransactionAction({
    sale,
    listing,
    actorUid: "buyer_1",
    action: "confirm_completion",
    paymentProviderStatus: "external_agreed",
    marketplaceFeeStatus: "collected",
  });
  assert.equal(transition.status, "awaiting_seller_confirmation");
  assert.equal(transition.buyerConfirmed, true);
});

test("Timed Buying mirror does not publish unpaid external completion", () => {
  assert.equal(
      marketplaceStatusForAuctionSync({
        paymentProviderStatus: "external_agreed",
        marketplaceFeeStatus: "pending_collection",
      }, "completed"),
      "pending_payment",
  );
  assert.equal(
      marketplaceStatusForAuctionSync({
        paymentProviderStatus: "external_agreed",
        marketplaceFeeStatus: "collected",
      }, "completed"),
      "completed",
  );
});

test("external mode reservation is exclusive with Stripe checkout", () => {
  assert.deepEqual(reserveExternalSettlementState({}), {
    settlementMode: "external_settlement",
    settlementGeneration: 1,
  });
  assert.deepEqual(reserveExternalSettlementState({
    settlementMode: "external_settlement",
    settlementGeneration: 3,
    paymentProviderStatus: "external_agreed",
    paymentProvider: "external",
    paymentMethod: "external_settlement",
  }), {
    settlementMode: "external_settlement",
    settlementGeneration: 3,
  });
  for (const startedState of [
    {settlementMode: "stripe_checkout", paymentProviderStatus: "checkout_creating"},
    {paymentProviderStatus: "checkout_created"},
    {paymentProviderStatus: "processing"},
    {paymentProviderStatus: "failed", stripeCheckoutSessionId: "cs_123"},
    {stripeCheckoutAttemptId: "attempt_123"},
    {stripePaymentIntentId: "pi_123"},
  ]) {
    assert.equal(stripeCheckoutHasStarted(startedState), true);
    assert.throws(
        () => reserveExternalSettlementState(startedState),
        /Stripe marketplace checkout has already started/u,
    );
  }
});

test("one-sided external confirmation can be withdrawn without a rail race", () => {
  assert.deepEqual(validateExternalSettlementWithdrawal({
    settlementMode: "external_settlement",
    settlementGeneration: 1,
    externalSettlementBuyerConfirmed: true,
    externalSettlementSellerConfirmed: false,
    paymentProviderStatus: "not_started",
    marketplaceFeeStatus: "pending_collection",
  }, "buyer"), {
    alreadyApplied: false,
    settlementGeneration: 2,
  });
  assert.deepEqual(validateExternalSettlementWithdrawal({
    settlementGeneration: 2,
    externalSettlementBuyerConfirmed: false,
    externalSettlementSellerConfirmed: false,
  }, "buyer"), {
    alreadyApplied: true,
    settlementGeneration: 2,
  });
  assert.throws(
      () => validateExternalSettlementWithdrawal({
        settlementMode: "external_settlement",
        settlementGeneration: 1,
        externalSettlementBuyerConfirmed: true,
        externalSettlementSellerConfirmed: false,
      }, "seller"),
      /Only your pending/u,
  );
});

test("external withdrawal closes after mutual agreement or payment activity", () => {
  for (const lockedState of [
    {
      externalSettlementBuyerConfirmed: true,
      externalSettlementSellerConfirmed: true,
    },
    {
      externalSettlementBuyerConfirmed: true,
      stripeMarketplaceFeeAttemptId: "fee_attempt_1",
    },
    {
      externalSettlementBuyerConfirmed: true,
      stripeCheckoutSessionId: "cs_123",
    },
  ]) {
    assert.throws(
        () => validateExternalSettlementWithdrawal({
          settlementMode: "external_settlement",
          settlementGeneration: 1,
          ...lockedState,
        }, "buyer"),
        /cannot be withdrawn/u,
    );
  }
});

test("expired fee checkout replacement CAS binds attempt, session, and generation", () => {
  const sale = {
    settlementMode: "external_settlement",
    settlementGeneration: 4,
    stripeMarketplaceFeeSettlementGeneration: 4,
    stripeMarketplaceFeeAttemptId: "attempt_4",
    stripeMarketplaceFeeSessionId: "cs_expired_4",
  };
  const reservation = {
    settlementGeneration: 4,
    attemptId: "attempt_4",
    sessionId: "cs_expired_4",
  };
  assert.equal(
      externalFeeCheckoutMatchesReservation(sale, reservation),
      true,
  );
  assert.equal(externalFeeCheckoutMatchesReservation(
      {...sale, stripeMarketplaceFeeAttemptId: "attempt_5"},
      reservation,
  ), false);
  assert.equal(externalFeeCheckoutMatchesReservation(
      {...sale, stripeMarketplaceFeeSessionId: "cs_new"},
      reservation,
  ), false);
  assert.equal(externalFeeCheckoutMatchesReservation(
      {...sale, settlementGeneration: 5},
      reservation,
  ), false);
});
