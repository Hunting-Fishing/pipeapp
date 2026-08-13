"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  marketplaceListingActivityContext,
  marketplaceMessagePreview,
} = require("../marketplace_activity_context");

test("listing activity context includes public commerce details", () => {
  assert.deepEqual(marketplaceListingActivityContext({
    title: "Premium tubing lot",
    imageUrls: ["https://example.test/first.jpg"],
    thumbnailUrl: "https://example.test/first.jpg",
    quantity: 120,
    price: 75,
    priceBasis: "Per piece",
    category: "Pipe, Tubing & Materials",
    sellerName: "Northern Pipe",
  }), {
    listingContextVersion: 1,
    listingTitle: "Premium tubing lot",
    listingThumbnailUrl: "https://example.test/first.jpg",
    listingQuantity: 120,
    listingPrice: 75,
    listingPriceBasis: "Per piece",
    listingCategory: "Pipe, Tubing & Materials",
    listingSellerName: "Northern Pipe",
  });
});

test("listing activity context excludes private offer terms", () => {
  const context = marketplaceListingActivityContext({
    title: "Dozer",
    offeredTotal: 10000,
    buyerUid: "private-buyer",
    note: "Private negotiation",
  });
  assert.equal(context.listingTitle, "Dozer");
  assert.equal("offeredTotal" in context, false);
  assert.equal("buyerUid" in context, false);
  assert.equal("note" in context, false);
});

test("message previews explain text and photo activity", () => {
  assert.equal(
      marketplaceMessagePreview({text: "Is this ready for pickup?"}),
      "Is this ready for pickup?",
  );
  assert.equal(
      marketplaceMessagePreview({attachment: {type: "image"}}),
      "Sent a photo about this listing.",
  );
});
