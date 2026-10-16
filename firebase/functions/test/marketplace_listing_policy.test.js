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
  assert.equal(result.currency, "USD");
  assert.equal(result.sellerUid, undefined);
  assert.equal(result.status, undefined);
  assert.equal(result.createdAt, undefined);
});

test("new marketplace and timed listings are USD only", () => {
  assert.equal(
      validateMarketplaceListingInput(validListing({currency: "usd"}), now)
          .currency,
      "USD",
  );
  for (const currency of ["CAD", "EUR", "PHP"]) {
    assert.throws(
        () => validateMarketplaceListingInput(validListing({currency}), now),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument" &&
          /must use USD/u.test(error.message),
    );
    assert.throws(
        () => validateMarketplaceListingInput(validListing({
          transactionType: "Auction",
          currency,
          startingBid: 73,
          minimumBidIncrement: 1,
          auctionStartAt: now.getTime(),
          auctionEndAt: now.getTime() + 7 * 24 * 60 * 60 * 1000,
        }), now),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument" &&
          /must use USD/u.test(error.message),
    );
  }
});

test("For Sale offer intent is canonical and firm listings require a price", () => {
  const open = validateMarketplaceListingInput(validListing(), now);
  assert.equal(open.priceFlexibility, "Open to offers");
  assert.equal(open.openToOffers, true);

  const firm = validateMarketplaceListingInput(validListing({
    priceFlexibility: "Firm",
    openToOffers: false,
  }), now);
  assert.equal(firm.priceFlexibility, "Firm");
  assert.equal(firm.openToOffers, false);

  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        priceFlexibility: "Firm",
        openToOffers: true,
      }), now),
      (error) => error instanceof ListingPolicyError &&
        error.code === "invalid-argument",
  );
  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        price: null,
        priceFlexibility: "Firm",
        openToOffers: false,
      }), now),
      (error) => error instanceof ListingPolicyError &&
        error.code === "invalid-argument",
  );
});

test("unsupported rental and quote transaction models fail closed", () => {
  for (const transactionType of ["For Rent", "Request for Quote"]) {
    assert.throws(
        () => validateMarketplaceListingInput(
            validListing({transactionType}),
            now,
        ),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument" &&
          /destination is invalid/u.test(error.message),
    );
  }
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

test("rejects contact details across public listing text", () => {
  for (const overrides of [
    {description: "Email sales (at) example (dot) com"},
    {model: "Details at pipebuyer.com"},
    {propertyFeatures: ["Fenced", "Telegram @pipe_sales"]},
    {title: "Call 780-555-1212 for details"},
  ]) {
    assert.throws(
        () => validateMarketplaceListingInput(validListing(overrides), now),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument",
    );
  }

});

test("accepts industrial specifications, prices, and calendar dates", () => {
  const result = validateMarketplaceListingInput(validListing({
    title: "CAT-320-2026 excavator",
    productType: "API 5CT casing",
    pipeSize: "5-1/2 pipe",
    description: "Asking $100,000; inspected 2026-10-16.",
  }), now);
  assert.equal(result.title, "CAT-320-2026 excavator");
});

test("requires complete future auction timing and positive pricing", () => {
  const result = validateMarketplaceListingInput(validListing({
    transactionType: "Auction",
    startingBid: 73,
    minimumBidIncrement: 0.5,
    buyItNowPrice: 120,
    auctionStartAt: now.getTime(),
    auctionEndAt: now.getTime() + 7 * 24 * 60 * 60 * 1000,
  }), now);
  assert.equal(result.auctionStatus, "live");
  assert.equal(result.currentBid, 0);
  assert.equal(result.bidCount, 0);
  assert.equal(result.buyItNowPrice, 120);

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

  for (const overrides of [
    {startingBid: 73.001, minimumBidIncrement: 1},
    {startingBid: 73, minimumBidIncrement: 0.49},
    {startingBid: 73, minimumBidIncrement: 1000.01},
    {startingBid: 73, minimumBidIncrement: 1, buyItNowPrice: 72},
  ]) {
    assert.throws(
        () => validateMarketplaceListingInput(validListing({
          transactionType: "Auction",
          auctionStartAt: now.getTime(),
          auctionEndAt: now.getTime() + 7 * 24 * 60 * 60 * 1000,
          ...overrides,
        }), now),
        (error) => error instanceof ListingPolicyError &&
          error.code === "invalid-argument",
    );
  }

  assert.throws(
      () => validateMarketplaceListingInput(validListing({
        transactionType: "Auction",
        startingBid: 73,
        minimumBidIncrement: 1,
        auctionStartAt: now.getTime(),
        auctionEndAt: now.getTime() + 361 * 24 * 60 * 60 * 1000,
      }), now),
      (error) => error instanceof ListingPolicyError &&
        error.code === "invalid-argument" &&
        /360 days/u.test(error.message),
  );
});

test("keeps auction reserve private and validates mapped locations", () => {
  assert.deepEqual(validateReserve({
    startingBid: 73,
    reservePrice: 90,
    reserveTotal: 4860,
    buyItNowPrice: 120,
  }, "Auction"), {
    reservePrice: 90,
    reserveTotal: 4860,
  });
  assert.throws(
      () => validateReserve({
        startingBid: 100,
        reservePrice: 90,
      }, "Auction"),
      (error) => error instanceof ListingPolicyError,
  );
  assert.throws(
      () => validateReserve({
        startingBid: 50,
        reservePrice: 100,
        buyItNowPrice: 99,
      }, "Auction"),
      (error) => error instanceof ListingPolicyError,
  );
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
  assert.throws(
      () => validateLocation({
        visibility: "approximate",
        point: {latitude: 55.76, longitude: -120.24},
        publicName: "Call 780-555-1212 for the yard location",
      }),
      (error) => error instanceof ListingPolicyError &&
        error.code === "invalid-argument",
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
