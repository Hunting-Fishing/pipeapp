"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildEngagementAnalytics,
  buildMarketplaceListingInsights,
  comparableListingScore,
  engagementSignal,
  median,
  safePercent,
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

test("safePercent returns a bounded precision ratio only with a denominator", () => {
  assert.equal(safePercent(5, 40), 12.5);
  assert.equal(safePercent(1, 3), 33.3);
  assert.equal(safePercent(1, 0), null);
  assert.equal(safePercent("bad", 10), null);
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

test("engagement analytics produce transparent funnel rates", () => {
  const engagement = buildEngagementAnalytics(pipeListing({
    viewCount: 200,
    saveCount: 20,
    shareCount: 8,
    messageCount: 12,
    offerCount: 5,
  }));
  assert.deepEqual(
      {
        views: engagement.views,
        saves: engagement.saves,
        shares: engagement.shares,
        messages: engagement.messages,
        offers: engagement.offers,
        actions: engagement.actions,
      },
      {views: 200, saves: 20, shares: 8, messages: 12, offers: 5, actions: 37},
  );
  assert.equal(engagement.saveRatePercent, 10);
  assert.equal(engagement.messageRatePercent, 6);
  assert.equal(engagement.offerRatePercent, 2.5);
  assert.equal(engagement.actionRatePercent, 18.5);
  assert.equal(engagement.signal.code, "strong");
});

test("engagement signal waits for enough traffic before interpreting demand", () => {
  const signal = engagementSignal({views: 6, saves: 3, messages: 2, offers: 1});
  assert.equal(signal.code, "building");
  assert.equal(signal.strong, false);
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
  assert.equal(insights.comparablePricing.deltaFromMedianPercent, 37);
  assert.equal(insights.engagement.views, 30);
  assert.equal(insights.engagement.saves, 2);
  assert.equal(insights.engagement.signal.code, "developing");
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

test("high traffic without downstream actions produces conversion suggestions", () => {
  const listing = pipeListing({
    id: "source",
    viewCount: 80,
    saveCount: 0,
    messageCount: 4,
    offerCount: 0,
  });
  const insights = buildMarketplaceListingInsights({listing, candidates: []});
  assert.equal(insights.engagement.signal.code, "developing");
  assert.ok(insights.suggestions.some((item) => item.code === "views_no_offers"));
  assert.ok(insights.suggestions.some((item) => item.code === "views_no_saves"));
  assert.ok(insights.suggestions.some((item) => item.code === "messages_no_offers"));
});
