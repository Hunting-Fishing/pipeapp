"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  MARKETPLACE_FEE_CLASS_SOURCE,
  MARKETPLACE_FEE_CLASSIFICATION_REVISION,
  calculateMarketplaceFeeSnapshot,
  inferMarketplaceFeeClass,
} = require("../marketplace_fee_policy");

function pipeListing(productType = "Tubing") {
  return {
    id: "listing-pipe-1",
    sellerUid: "seller-1",
    revision: 3,
    category: "Pipe, Tubing & Materials",
    productType,
  };
}

function approvedPipeClassification(listing, overrides = {}) {
  return {
    listingId: listing.id,
    sellerUid: listing.sellerUid,
    listingRevision: listing.revision,
    category: listing.category,
    productType: listing.productType,
    status: "approved",
    marketplaceFeeClass: "pipe",
    marketplaceFeeUnit: "item",
    marketplaceFeeClassSource: MARKETPLACE_FEE_CLASS_SOURCE,
    marketplaceFeeClassificationRevision:
      MARKETPLACE_FEE_CLASSIFICATION_REVISION,
    decisionRevision: 1,
    decisionReason: "Reviewed against the controlled pipe catalog.",
    decidedByUid: "admin-1",
    decidedAt: "server-timestamp",
    ...overrides,
  };
}

test("seller-selected pipe catalog fields alone default to equipment", () => {
  const listing = pipeListing();
  const fee = calculateMarketplaceFeeSnapshot({
    listing,
    agreedQuantity: 1000,
    agreedTotal: 40000,
    currency: "USD",
  });
  assert.equal(inferMarketplaceFeeClass(listing), "equipment_asset");
  assert.equal(fee.feeClass, "equipment_asset");
  assert.equal(fee.feeClassificationSource, "server_fail_closed_default");
});

test("fee fields embedded in a seller listing are never trusted", () => {
  const listing = {
    ...pipeListing(),
    marketplaceFeeClass: "pipe",
    marketplaceFeeUnit: "item",
    marketplaceFeeClassSource: MARKETPLACE_FEE_CLASS_SOURCE,
    marketplaceFeeClassificationRevision:
      MARKETPLACE_FEE_CLASSIFICATION_REVISION,
    status: "approved",
  };
  assert.equal(inferMarketplaceFeeClass(listing), "equipment_asset");
});

test("only a matching administrator approval grants pipe pricing", () => {
  const listing = pipeListing();
  const approval = approvedPipeClassification(listing);
  assert.equal(inferMarketplaceFeeClass(listing, approval), "pipe");
});

test("stale or mismatched approvals fail closed to equipment", () => {
  const listing = pipeListing();
  const mismatches = [
    {status: "revoked"},
    {listingId: "different-listing"},
    {sellerUid: "different-seller"},
    {listingRevision: listing.revision - 1},
    {category: "Heavy Equipment"},
    {productType: "Casing"},
    {marketplaceFeeClassSource: "server_canonical_catalog"},
    {marketplaceFeeClassificationRevision: "stale-revision"},
    {decisionRevision: 0},
    {decidedByUid: ""},
    {decidedAt: null},
  ];
  for (const override of mismatches) {
    assert.equal(
        inferMarketplaceFeeClass(
            listing,
            approvedPipeClassification(listing, override),
        ),
        "equipment_asset",
    );
  }
  assert.equal(
      inferMarketplaceFeeClass(
          pipeListing("Pipe"),
          approvedPipeClassification(pipeListing("Pipe")),
      ),
      "equipment_asset",
  );
  const invalidRevisionListing = {...listing, revision: 0};
  assert.equal(
      inferMarketplaceFeeClass(
          invalidRevisionListing,
          approvedPipeClassification(invalidRevisionListing),
      ),
      "equipment_asset",
  );
});

test("charges one dollar per stick for a normal pipe sale", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: pipeListing("Line Pipe"),
    feeClassification: approvedPipeClassification(pipeListing("Line Pipe")),
    agreedQuantity: 1000,
    agreedTotal: 40000,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 100000);
  assert.equal(fee.marketplaceFee, 1000);
  assert.equal(fee.feePayer, "seller");
  assert.equal(fee.affiliateCommissionMinor, 20000);
});

test("caps pipe-item fees at three percent for low-value lots", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: pipeListing(),
    feeClassification: approvedPipeClassification(pipeListing()),
    agreedQuantity: 5,
    agreedTotal: 100,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 300);
  assert.equal(fee.marketplaceFee, 3);
  assert.equal(fee.percentageCapBps, 300);
});

test("keeps the pipe fee proportional instead of rejecting small sales", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: pipeListing(),
    feeClassification: approvedPipeClassification(pipeListing()),
    agreedQuantity: 5,
    agreedTotal: 20,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 60);
});

test("caps very large pipe lots at twenty-five hundred dollars", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: pipeListing("Casing"),
    feeClassification: approvedPipeClassification(pipeListing("Casing")),
    agreedQuantity: 10000,
    agreedTotal: 500000,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 250000);
});

test("equipment fee uses marginal percentage brackets without price cliffs", () => {
  const cases = [
    [5000, 15000],
    [25000, 65000],
    [100000, 215000],
    [250000, 250000],
    [500000, 250000],
  ];
  for (const [total, expectedFeeMinor] of cases) {
    const fee = calculateMarketplaceFeeSnapshot({
      listing: {category: "Heavy Equipment"},
      agreedQuantity: 1,
      agreedTotal: total,
      currency: "CAD",
    });
    assert.equal(fee.marketplaceFeeMinor, expectedFeeMinor);
    assert.equal(fee.listingFeeMinor, 0);
    assert.equal(fee.collectionTiming, "sale_payment");
  }
});

test("equipment fee remains monotonic at every marginal bracket boundary", () => {
  for (const boundary of [5000, 25000, 100000, 250000]) {
    const before = calculateMarketplaceFeeSnapshot({
      listing: {category: "Heavy Equipment"},
      agreedQuantity: 1,
      agreedTotal: boundary - 0.01,
      currency: "USD",
    });
    const after = calculateMarketplaceFeeSnapshot({
      listing: {category: "Heavy Equipment"},
      agreedQuantity: 1,
      agreedTotal: boundary,
      currency: "USD",
    });
    assert.ok(after.marketplaceFeeMinor >= before.marketplaceFeeMinor);
  }
});

test("supports USD without changing the one-dollar-per-stick concept", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: pipeListing("Line Pipe"),
    feeClassification: approvedPipeClassification(pipeListing("Line Pipe")),
    agreedQuantity: 250,
    agreedTotal: 25000,
    currency: "USD",
  });
  assert.equal(fee.marketplaceFeeMinor, 25000);
  assert.equal(fee.currency, "USD");
});
