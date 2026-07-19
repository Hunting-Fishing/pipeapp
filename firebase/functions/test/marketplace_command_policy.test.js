"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  CommandPolicyError,
  minimumAuctionBid,
  validateAcceptBelowReserve,
  validateBuyNow,
  validateLeadingBidRecord,
  validateOfferAcceptance,
  validateOfferFrequency,
  validateOfferProposal,
  validatePlaceBid,
  validateWithdrawal,
} = require("../marketplace_command_policy");

const now = new Date("2026-07-19T12:00:00.000Z");

function liveAuction(overrides = {}) {
  return {
    transactionType: "Auction",
    sellerUid: "seller",
    status: "active",
    auctionStatus: "live",
    auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
    auctionEndAt: new Date("2026-08-31T00:00:00.000Z"),
    startingBid: 100,
    currentBid: 0,
    minimumBidIncrement: 5,
    buyItNowPrice: 200,
    ...overrides,
  };
}

test("minimum bid follows starting price then current plus increment", () => {
  assert.equal(minimumAuctionBid(liveAuction()), 100);
  assert.equal(
      minimumAuctionBid(liveAuction({currentBid: 125})),
      130,
  );
});

test("bid must meet the server-calculated minimum", () => {
  assert.throws(
      () => validatePlaceBid(liveAuction(), "buyer", 99, now),
      (error) =>
        error instanceof CommandPolicyError &&
        error.code === "failed-precondition",
  );
  assert.deepEqual(
      validatePlaceBid(liveAuction(), "buyer", 100, now),
      {amount: 100, minimum: 100},
  );
});

test("money commands reject fractions smaller than a cent", () => {
  assert.throws(
      () => validatePlaceBid(liveAuction(), "buyer", 100.001, now),
      (error) =>
        error instanceof CommandPolicyError &&
        error.code === "invalid-argument",
  );
  assert.throws(
      () => validatePlaceBid(
          liveAuction({minimumBidIncrement: -5}),
          "buyer",
          100,
          now,
      ),
      (error) =>
        error instanceof CommandPolicyError &&
        error.code === "invalid-argument",
  );
});

test("seller cannot bid or use Buy It Now on their auction", () => {
  assert.throws(
      () => validatePlaceBid(liveAuction(), "seller", 100, now),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateBuyNow(liveAuction(), "seller", now),
      (error) => error.code === "permission-denied",
  );
});

test("seller may accept only a real leading bid below reserve", () => {
  const accepted = validateAcceptBelowReserve(
      liveAuction({
        currentBid: 150,
        reservePrice: 175,
        highBidderUid: "buyer",
      }),
      "seller",
      now,
  );
  assert.deepEqual(accepted, {amount: 150, bidderUid: "buyer"});
  assert.throws(
      () => validateAcceptBelowReserve(
          liveAuction({
            currentBid: 175,
            reservePrice: 175,
            highBidderUid: "buyer",
          }),
          "seller",
          now,
      ),
      (error) => error.code === "failed-precondition",
  );
});

test("custom auction withdrawal starts only after day 32", () => {
  const bid = {
    listingId: "auction-1",
    bidderUid: "buyer",
    status: "leading",
  };
  assert.throws(
      () => validateWithdrawal(
          "auction-1",
          liveAuction({
            customAuction: true,
            auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
          }),
          bid,
          "buyer",
          now,
      ),
      (error) => error.code === "failed-precondition",
  );
  assert.doesNotThrow(
      () => validateWithdrawal(
          "auction-1",
          liveAuction({
            customAuction: true,
            auctionStartAt: new Date("2026-06-01T00:00:00.000Z"),
          }),
          bid,
          "buyer",
          now,
      ),
  );
});

test("bid records must belong to the auction they change", () => {
  const listing = liveAuction({
    currentBid: 100,
    highBidderUid: "buyer",
  });
  assert.throws(
      () => validateLeadingBidRecord(
          "auction-1",
          listing,
          {
            listingId: "auction-2",
            bidderUid: "buyer",
            amount: 100,
            status: "leading",
          },
      ),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => validateWithdrawal(
          "auction-1",
          liveAuction({
            customAuction: true,
            auctionStartAt: new Date("2026-06-01T00:00:00.000Z"),
          }),
          {
            listingId: "auction-2",
            bidderUid: "buyer",
            status: "leading",
          },
          "buyer",
          now,
      ),
      (error) => error.code === "permission-denied",
  );
});

test("only the seller can accept a pending complete offer", () => {
  const offer = {
    sellerUid: "seller",
    buyerUid: "buyer",
    listingId: "listing",
    status: "pending",
  };
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
  };
  assert.doesNotThrow(
      () => validateOfferAcceptance(offer, "seller", listing),
  );
  assert.throws(
      () => validateOfferAcceptance(offer, "buyer", listing),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateOfferAcceptance(
          {...offer, status: "archived"},
          "seller",
          listing,
      ),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => validateOfferAcceptance(
          offer,
          "seller",
          {...listing, transactionType: "Auction"},
      ),
      (error) => error.code === "failed-precondition",
  );
});

test("listing offers use authoritative participants and quantity", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 54,
  };
  const proposal = validateOfferProposal({
    listing,
    conversation: null,
    actorUid: "buyer",
    data: {
      listingId: "listing",
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      truckingPlan: "buyer_arranged",
    },
    now,
  });
  assert.equal(proposal.sellerUid, "seller");
  assert.equal(proposal.buyerUid, "buyer");
  assert.equal(proposal.offeredTotal, 3780);
  assert.throws(
      () => validateOfferProposal({
        listing,
        conversation: null,
        actorUid: "seller",
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 54,
          truckingPlan: "buyer_arranged",
        },
        now,
      }),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateOfferProposal({
        listing,
        conversation: null,
        actorUid: "buyer",
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 55,
          truckingPlan: "buyer_arranged",
        },
        now,
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("seller counter-offers require the real listing conversation", () => {
  const proposal = validateOfferProposal({
    listing: {
      sellerUid: "seller",
      status: "active",
      transactionType: "Marketplace",
      quantity: 54,
    },
    conversation: {
      listingId: "listing",
      sellerUid: "seller",
      memberUids: ["seller", "buyer"],
    },
    actorUid: "seller",
    data: {
      listingId: "listing",
      offeredUnitPrice: 73,
      requestedQuantity: 54,
      truckingPlan: "seller_pickup",
    },
    now,
  });
  assert.equal(proposal.buyerUid, "buyer");
  assert.equal(proposal.sellerUid, "seller");
  assert.throws(
      () => validateOfferProposal({
        listing: {
          sellerUid: "seller",
          status: "active",
          transactionType: "Marketplace",
          quantity: 54,
        },
        conversation: {
          listingId: "listing",
          sellerUid: "seller",
          memberUids: ["seller", "buyer", "unrelated-user"],
        },
        actorUid: "seller",
        data: {
          listingId: "listing",
          offeredUnitPrice: 73,
          requestedQuantity: 54,
          truckingPlan: "seller_pickup",
        },
        now,
      }),
      (error) => error.code === "permission-denied",
  );
});

test("Dispatch offers require a dated mapped destination", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 54,
  };
  assert.throws(
      () => validateOfferProposal({
        listing,
        conversation: null,
        actorUid: "buyer",
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 54,
          truckingPlan: "request_dispatch",
        },
        now,
      }),
      (error) => error.code === "invalid-argument",
  );
  const proposal = validateOfferProposal({
    listing,
    conversation: null,
    actorUid: "buyer",
    data: {
      listingId: "listing",
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      truckingPlan: "request_dispatch",
      truckingDate: now.getTime() + 7 * 24 * 60 * 60 * 1000,
      dispatchDelivery: {
        label: "Dawson Creek yard",
        nearestTown: "Dawson Creek",
        latitude: 55.7596,
        longitude: -120.2377,
      },
    },
    now,
  });
  assert.equal(proposal.dispatchDelivery.nearestTown, "Dawson Creek");
});

test("offer revisions are rate limited per buyer and listing", () => {
  assert.equal(validateOfferFrequency([], "buyer", now), 1);
  assert.throws(
      () => validateOfferFrequency(
          [{
            buyerUid: "buyer",
            createdAt: new Date(now.getTime() - 1000),
          }],
          "buyer",
          now,
      ),
      (error) => error.code === "resource-exhausted",
  );
});
