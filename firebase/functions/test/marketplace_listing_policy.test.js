"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  ListingPolicyError,
  validateLocation,
  validateListingMediaManifest,
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

test("wanted ads receive server-owned lifecycle and match counters", () => {
  const result = validateMarketplaceListingInput(validListing({
    transactionType: "Wanted / Seeking",
    wantedStatus: "fulfilled",
    responseCount: 900,
    requestType: "forged",
    matchCount: 900,
  }), now);
  assert.equal(result.wantedStatus, "open");
  assert.equal(result.responseCount, 0);
  assert.equal(result.requestType, "wanted_ad");
  assert.equal(result.matchCount, 0);
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
  }), now, {regulatedListingsEnabled: true});

  assert.equal(listing.landAreaAcres, 160);
  assert.equal(listing.annualRevenue, 300000);
  assert.deepEqual(listing.propertyFeatures, ["Power", "Fenced / gated"]);
});

test("regulated property listings fail closed by default", () => {
  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        title: "Industrial yard",
        category: "Site & Property",
        productType: "Industrial Real Estate",
        propertyOffering: "Property only",
        propertyInterest: "Freehold / fee simple",
      }), now),
      (error) =>
        error instanceof ListingPolicyError &&
        error.code === "failed-precondition",
  );
});

function mediaUrl(path) {
  return "https://firebasestorage.googleapis.com/v0/b/demo.appspot.com/o/" +
    `${encodeURIComponent(path)}?alt=media&token=test`;
}

test("accepts a complete listing draft media manifest and thumbnail", () => {
  const first = mediaUrl("listing_media/seller/draft-1/photo_1.jpg");
  const second = mediaUrl("listing_media/seller/draft-1/photo_2.png");
  const video = mediaUrl("listing_media/seller/draft-1/video.mp4");
  const result = validateListingMediaManifest({
    status: "complete",
    imageUrls: [first, second],
    imageHashes: ["a".repeat(64), "b".repeat(64)],
    thumbnailUrl: second,
    videoUrl: video,
  }, {
    ownerUid: "seller",
    listingId: "draft-1",
    expectedPhotoCount: 2,
    expectsVideo: true,
    requireComplete: true,
  });

  assert.equal(result.thumbnailUrl, second);
  assert.equal(result.videoUrl, video);
  assert.equal(result.imageUrls.length, 2);
});

test("draft publication rejects incomplete or foreign media", () => {
  const first = mediaUrl("listing_media/seller/draft-1/photo_1.jpg");
  assert.throws(
      () => validateListingMediaManifest({
        status: "uploading",
        imageUrls: [],
        imageHashes: [],
      }, {
        ownerUid: "seller",
        listingId: "draft-1",
        expectedPhotoCount: 1,
        expectsVideo: false,
        requireComplete: true,
      }),
      (error) => error instanceof ListingPolicyError &&
        error.code === "failed-precondition",
  );
  assert.throws(
      () => validateListingMediaManifest({
        status: "complete",
        imageUrls: [first],
        imageHashes: ["a".repeat(64)],
        thumbnailUrl: "",
      }, {
        ownerUid: "seller",
        listingId: "draft-1",
        expectedPhotoCount: 1,
        expectsVideo: false,
      }),
      (error) => error instanceof ListingPolicyError,
  );
  assert.throws(
      () => validateListingMediaManifest({
        status: "complete",
        imageUrls: [mediaUrl(
          "listing_media/another-user/draft-1/photo_1.jpg",
        )],
        imageHashes: ["a".repeat(64)],
        thumbnailUrl: mediaUrl(
          "listing_media/another-user/draft-1/photo_1.jpg",
        ),
      }, {
        ownerUid: "seller",
        listingId: "draft-1",
        expectedPhotoCount: 1,
        expectsVideo: false,
      }),
      (error) => error instanceof ListingPolicyError,
  );
});
