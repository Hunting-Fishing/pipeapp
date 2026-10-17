"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  ListingPolicyError,
  validateMarketplaceListingInput,
  validateReserve,
} = require("../marketplace_listing_policy");
const {
  CommandPolicyError,
  validateAuctionConversion,
  validateAuctionFinalization,
  validateListingDetailsUpdate,
  validateOfferProposal,
} = require("../marketplace_command_policy");
const {
  assertAuctionSettlementMatches,
} = require("../marketplace_commands");

const now = new Date("2026-07-19T12:00:00.000Z");

function saleListing(overrides = {}) {
  return {
    title: "54 joints of drill pipe",
    category: "Pipe, Tubing & Materials",
    transactionType: "For Sale",
    price: 73,
    priceBasis: "Per piece",
    quantity: 54,
    currency: "USD",
    description: "Inspected used pipe.",
    ...overrides,
  };
}

function storedSaleListing(overrides = {}) {
  return {
    sellerUid: "seller",
    status: "active",
    revision: 1,
    transactionType: "Marketplace",
    price: 73,
    priceBasis: "Per piece",
    quantity: 54,
    currency: "USD",
    ...overrides,
  };
}

function expiredAuction(overrides = {}) {
  return {
    id: "auction-1",
    sellerUid: "seller",
    status: "active",
    transactionType: "Auction",
    auctionStatus: "live",
    auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
    auctionEndAt: new Date(now.getTime() - 1000),
    currentBid: 100,
    highBidderUid: "buyer",
    quantity: 2,
    auctionQuantity: 2,
    priceBasis: "Per item",
    auctionPricingBasis: "Per item",
    currency: "USD",
    ...overrides,
  };
}

function conversionRequest(listing) {
  return {
    listing,
    actorUid: "seller",
    user: {},
    administrator: true,
    data: {
      startingBid: 50,
      minimumBidIncrement: 1,
      durationDays: 7,
    },
    paidFeaturesEnabled: false,
    now,
  };
}

test("sale publication accepts only launch-safe total and count bases", () => {
  const accepted = [
    ["total", "Total asking price"],
    ["Total for all", "Total for all"],
    ["Per piece", "Per piece"],
    ["Per joint", "Per joint"],
    ["Per item", "Per item"],
    ["Price per machine", "Price per machine"],
  ];
  for (const [input, canonical] of accepted) {
    const listing = validateMarketplaceListingInput(
        saleListing({priceBasis: input}),
        now,
    );
    assert.equal(listing.priceBasis, canonical);
  }

  for (const priceBasis of [
    "Per foot",
    "Per metre",
    "Per acre",
    "Per hectare",
    "Per bundle",
    "Monthly lease",
    "Call for price",
  ]) {
    assert.throws(
        () => validateMarketplaceListingInput(
            saleListing({priceBasis}),
            now,
        ),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument" &&
          /cannot be settled|unavailable/u.test(error.message),
    );
  }
});

test("publication normalizes total quantity and rejects unsafe quantities", () => {
  const total = saleListing({priceBasis: "total"});
  delete total.quantity;
  const normalized = validateMarketplaceListingInput(total, now);
  assert.equal(normalized.priceBasis, "Total asking price");
  assert.equal(normalized.quantity, 1);

  for (const quantity of [0, -1, 1.5, 1_000_001, "54", true]) {
    assert.throws(
        () => validateMarketplaceListingInput(
            saleListing({quantity}),
            now,
        ),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument",
    );
  }
});

test("listing edits reject coerced or out-of-range quantities and bases", () => {
  for (const quantity of [0, -1, 1.5, 1_000_001, "54", true]) {
    assert.throws(
        () => validateListingDetailsUpdate({
          listing: storedSaleListing(),
          actorUid: "seller",
          data: {expectedRevision: 1, patch: {quantity}},
        }),
        (error) => error instanceof CommandPolicyError &&
          error.code === "invalid-argument",
    );
  }
  assert.throws(
      () => validateListingDetailsUpdate({
        listing: storedSaleListing(),
        actorUid: "seller",
        data: {expectedRevision: 1, patch: {priceBasis: "Per foot"}},
      }),
      (error) => error instanceof CommandPolicyError &&
        error.code === "invalid-argument",
  );
});

test("auction conversion rejects dimensional bases and malformed quantities", () => {
  for (const priceBasis of ["Per foot", "Per acre", "Per bundle"]) {
    assert.throws(
        () => validateAuctionConversion(conversionRequest(
            storedSaleListing({priceBasis}),
        )),
        (error) => error instanceof CommandPolicyError &&
          error.code === "failed-precondition",
    );
  }
  for (const quantity of [0, -1, 1.5, 1_000_001, "54", true]) {
    assert.throws(
        () => validateAuctionConversion(conversionRequest(
            storedSaleListing({quantity}),
        )),
        (error) => error instanceof CommandPolicyError &&
          error.code === "failed-precondition",
    );
  }
});

test("offer math rejects dimensional bases and coerced quantities", () => {
  const request = {
    listing: storedSaleListing(),
    conversation: null,
    actorUid: "buyer",
    data: {
      listingId: "listing-1",
      offeredUnitPrice: 70,
      requestedQuantity: 2,
      truckingPlan: "buyer_arranged",
    },
    now,
  };
  assert.throws(
      () => validateOfferProposal({
        ...request,
        listing: storedSaleListing({priceBasis: "Per foot"}),
      }),
      (error) => error instanceof CommandPolicyError &&
        error.code === "failed-precondition",
  );
  assert.throws(
      () => validateOfferProposal({
        ...request,
        data: {...request.data, requestedQuantity: "2"},
      }),
      (error) => error instanceof CommandPolicyError &&
        error.code === "invalid-argument",
  );
});

test("auction finalization treats an absent reserve as no reserve", () => {
  assert.deepEqual(
      validateAuctionFinalization({
        listing: expiredAuction(),
        privateAuction: null,
        now,
      }),
      {
        amount: 100,
        auctionStatus: "won",
        reserveMet: true,
        winnerUid: "buyer",
      },
  );
});

test("auction finalization fails closed on malformed reserve records", () => {
  for (const privateAuction of [
    {},
    {ownerUid: "other", reservePrice: 90},
    {ownerUid: 123, reservePrice: 90},
    {ownerUid: "seller"},
    {ownerUid: "seller", reservePrice: null},
    {ownerUid: "seller", reservePrice: -1},
    {ownerUid: "seller", reservePrice: "bad"},
    {ownerUid: "seller", reservePrice: 90, reserveTotal: 181},
  ]) {
    assert.throws(
        () => validateAuctionFinalization({
          listing: expiredAuction(),
          privateAuction,
          now,
        }),
        (error) => error instanceof CommandPolicyError &&
          error.code === "failed-precondition",
    );
  }

  assert.throws(
      () => validateAuctionFinalization({
        listing: expiredAuction({reservePrice: 90}),
        privateAuction: null,
        now,
      }),
      (error) => error instanceof CommandPolicyError &&
        error.code === "failed-precondition",
  );
});

test("auction finalization rejects malformed sale terms and bid identity", () => {
  for (const overrides of [
    {auctionPricingBasis: "Per foot"},
    {auctionPricingBasis: null},
    {auctionQuantity: 1.5},
    {auctionQuantity: "2"},
    {auctionQuantity: null},
    {currentBid: "100"},
    {currentBid: 100.001},
    {currentBid: 0, highBidderUid: "buyer"},
    {currentBid: 100, highBidderUid: ""},
    {sellerUid: ""},
  ]) {
    assert.throws(
        () => validateAuctionFinalization({
          listing: expiredAuction(overrides),
          privateAuction: null,
          now,
        }),
        (error) => error instanceof CommandPolicyError &&
          error.code === "failed-precondition",
    );
  }
});

test("reserve totals must match authoritative quantity and basis", () => {
  assert.deepEqual(
      validateReserve({
        startingBid: 50,
        reservePrice: 90,
        reserveTotal: 180,
      }, "Auction", expiredAuction({startingBid: 50})),
      {reservePrice: 90, reserveTotal: 180},
  );
  assert.throws(
      () => validateReserve({
        startingBid: 50,
        reservePrice: 90,
        reserveTotal: 181,
      }, "Auction", expiredAuction({startingBid: 50})),
      (error) => error instanceof ListingPolicyError &&
        error.code === "invalid-argument",
  );
  assert.throws(
      () => validateReserve({
        startingBid: 50,
        reserveTotal: 180,
      }, "Auction", expiredAuction({startingBid: 50})),
      (error) => error instanceof ListingPolicyError &&
        error.code === "invalid-argument",
  );
});

test("existing auction settlements must match immutable sale identity", () => {
  const expected = {
    listingId: "auction-1",
    buyerUid: "buyer",
    sellerUid: "seller",
    agreedUnitPrice: 100,
    agreedQuantity: 2,
    agreedTotal: 200,
    currency: "USD",
    priceBasis: "Per item",
    source: "auction_expiry",
  };
  assert.doesNotThrow(() => assertAuctionSettlementMatches(
      {...expected},
      expected,
  ));

  for (const mutation of [
    {listingId: "other"},
    {listingId: 1},
    {buyerUid: "other"},
    {buyerUid: 1},
    {sellerUid: "other"},
    {agreedUnitPrice: 100.001},
    {agreedQuantity: "2"},
    {agreedQuantity: 1},
    {agreedTotal: 200.001},
    {agreedTotal: 199.99},
    {currency: "CAD"},
    {priceBasis: "Total for all"},
    {source: "buy_now"},
  ]) {
    assert.throws(
        () => assertAuctionSettlementMatches(
            {...expected, ...mutation},
            expected,
        ),
        (error) => error instanceof CommandPolicyError &&
          error.code === "failed-precondition",
    );
  }
});
