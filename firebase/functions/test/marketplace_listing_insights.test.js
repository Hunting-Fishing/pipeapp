"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildMarketplaceListingInsights,
  comparableListingScore,
  median,
} = require("../marketplace_listing_insights");

function pipeListing(overrides = {}) {
  return {
    category: "Pipe, Tubing & Materials",
    productType: "Drill Pipe",
    pipeSize: "4-1/2 in",
    condition: "Used — Premium class",
    transactionType: "For Sale",
    priceBasis: "Per piece",
    price: 73,
    status: "active",
    description: "Straight used drill pipe with inspection details and loading information.",
    mediaPhotoCount: 4,
    searchTokens: ["drill", "pipe", "4-1/2"],
    ...overrides,
  };
}

test("median handles odd and even comparable samples", () => {
  assert.equal(median([10, 30, 20]), 20);
  assert.equal(median([10, 20, 30, 40]), 25);
  assert.equal(median([]), null);
});

test("same product and pipe size outrank category-only listing", () => {
  const source = pipeListing();
  const close = pipeListing({price: 70});
  const categoryOnly = pipeListing({
    productType: "Casing",
    pipeSize: "9-5/8 in",
    searchTokens: ["casing"],
  });
  assert.ok(
      comparableListingScore(source, close) >
      comparableListingScore(source, categoryOnly),
  );
});

test("seller analytics calculate comparable median and high-price suggestion", () => {
  const listing = pipeListing({
    id: "source",
    status: "expired",
    price: 100,
    mediaPhotoCount: 1,
    description: "Used pipe.",
    saveCount: 2,
    viewCount: 30,
    offerCount: 0,
  });
  const candidates = [70, 72, 74, 76].map((price, index) => ({
    id: `compare-${index}`,
    data: pipeListing({price}),
  }));
  const insights = buildMarketplaceListingInsights({
    listing,
    candidates,
    nowMillis: Date.UTC(2026, 7, 15),
  });
  assert.equal(insights.comparablePricing.sampleCount, 4);
  assert.equal(insights.comparablePricing.median, 73);
  assert.ok(insights.suggestions.some((item) => item.code === "renew"));
  assert.ok(insights.suggestions.some((item) => item.code === "price_high"));
  assert.ok(insights.suggestions.some((item) => item.code === "photos"));
  assert.ok(insights.suggestions.some((item) => item.code === "saved_interest"));
});

test("different pricing bases are excluded from price analytics", () => {
  const listing = pipeListing({id: "source", price: 5000});
  const candidates = [
    {
      id: "unit-price",
      data: pipeListing({price: 70, priceBasis: "Per piece"}),
    },
    {
      id: "lot-price",
      data: pipeListing({price: 4000, priceBasis: "Total lot"}),
    },
  ];
  const insights = buildMarketplaceListingInsights({listing, candidates});
  assert.equal(insights.comparablePricing.sampleCount, 1);
});
