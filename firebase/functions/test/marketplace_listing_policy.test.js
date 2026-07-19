"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  ListingPolicyError,
  validateLocation,
  validateMarketplaceListingInput,
  validateReserve,
} = require("../marketplace_listing_policy");

const now = new Date("2026-07-19T12:00:00.000Z");

function validListing(overrides = {}) {
  return {
    title: "54 joints of drill pipe",
    category: "Pipe, Tubing & Materials",
    transactionType: "For Sale",
    price: 73,
    priceBasis: "Per piece",
    quantity: 54,
    description: "Inspected used pipe.",
    ...overrides,
  };
}

test("normalizes a marketplace listing and ignores server-owned fields", () => {
  const result = validateMarketplaceListingInput(validListing({
    sellerUid: "forged-user",
    status: "sold",
    createdAt: 1,
  }), now);
  assert.equal(result.title, "54 joints of drill pipe");
  assert.equal(result.price, 73);
  assert.equal(result.sellerUid, undefined);
  assert.equal(result.status, undefined);
  assert.equal(result.createdAt, undefined);
});

test("rejects unsupported fields and nested client data", () => {
  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        administratorOverride: true,
      }), now),
      (error) =>
        error instanceof ListingPolicyError &&
        error.code === "invalid-argument",
  );
  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        description: {unsafe: true},
      }), now),
      (error) => error instanceof ListingPolicyError,
  );
});

test("requires complete future auction timing and positive pricing", () => {
  const result = validateMarketplaceListingInput(validListing({
    transactionType: "Auction",
    startingBid: 73,
    minimumBidIncrement: 0.5,
    auctionStartAt: now.getTime(),
    auctionEndAt: now.getTime() + 7 * 24 * 60 * 60 * 1000,
  }), now);
  assert.equal(result.auctionStatus, "live");
  assert.equal(result.currentBid, 0);
  assert.equal(result.bidCount, 0);

  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        transactionType: "Auction",
        startingBid: 73,
        minimumBidIncrement: 0,
        auctionStartAt: now.getTime(),
        auctionEndAt: now.getTime() + 1000,
      }), now),
      (error) => error instanceof ListingPolicyError,
  );
});

test("keeps auction reserve private and validates mapped locations", () => {
  assert.deepEqual(validateReserve({
    reservePrice: 90,
    reserveTotal: 4860,
  }, "Auction"), {
    reservePrice: 90,
    reserveTotal: 4860,
  });
  assert.equal(validateReserve({reservePrice: 90}, "For Sale"), null);

  const location = validateLocation({
    visibility: "approximate",
    point: {latitude: 55.76, longitude: -120.24},
    publicName: "Dawson Creek area, BC",
    nearestTown: "Dawson Creek",
    country: "Canada",
  });
  assert.equal(location.visibility, "approximate");
  assert.equal(location.point.latitude, 55.76);
  assert.throws(
      () => validateLocation({
        visibility: "exact",
        point: {latitude: 200, longitude: -120.24},
        publicName: "Invalid",
      }),
      (error) => error instanceof ListingPolicyError,
  );
});

test("keeps property and business listing facts structured", () => {
  const listing = validateMarketplaceListingInput(validListing({
    title: "Income-producing industrial yard",
    category: "Site & Property",
    productType: "Industrial Real Estate",
    propertyOffering: "Business and property",
    propertyInterest: "Freehold with active lease(s)",
    landAreaInputValue: 160,
    landAreaInputUnit: "Acres",
    landAreaAcres: 160,
    landAreaHectares: 64.7497,
    buildingAreaValue: 24000,
    buildingAreaUnit: "Square feet",
    monthlyRevenue: 25000,
    annualRevenue: 300000,
    propertyFeatures: ["Power", "Fenced / gated"],
  }), now);

  assert.equal(listing.landAreaAcres, 160);
  assert.equal(listing.annualRevenue, 300000);
  assert.deepEqual(listing.propertyFeatures, ["Power", "Fenced / gated"]);
});
