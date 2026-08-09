"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  calculateMarketplaceFeeSnapshot,
  inferMarketplaceFeeClass,
} = require("../marketplace_fee_policy");

test("classifies pipe, tubing, casing and OCTG listings as pipe", () => {
  for (const productType of ["Pipe", "Tubing", "Casing", "OCTG", "Drill Pipe"]) {
    assert.equal(inferMarketplaceFeeClass({productType}), "pipe");
  }
});

test("charges one dollar per stick for a normal pipe sale", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: {productType: "Oilfield Pipe"},
    agreedQuantity: 1000,
    agreedTotal: 40000,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 100000);
  assert.equal(fee.marketplaceFee, 1000);
  assert.equal(fee.feePayer, "seller");
  assert.equal(fee.affiliateCommissionMinor, 20000);
});

test("caps very large pipe lots at five thousand dollars", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: {category: "Casing"},
    agreedQuantity: 10000,
    agreedTotal: 500000,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 500000);
});

test("percentage cap wins over the pipe minimum on very small-value sales", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: {category: "Tubing"},
    agreedQuantity: 5,
    agreedTotal: 100,
    currency: "CAD",
  });
  assert.equal(fee.marketplaceFeeMinor, 300);
});

test("equipment fee uses launch percentage tiers", () => {
  const cases = [
    [5000, 25000],
    [25000, 75000],
    [100000, 200000],
    [500000, 500000],
  ];
  for (const [total, expectedFeeMinor] of cases) {
    const fee = calculateMarketplaceFeeSnapshot({
      listing: {category: "Heavy Equipment"},
      agreedQuantity: 1,
      agreedTotal: total,
      currency: "CAD",
    });
    assert.equal(fee.marketplaceFeeMinor, expectedFeeMinor);
  }
});

test("supports USD without changing the one-dollar-per-stick concept", () => {
  const fee = calculateMarketplaceFeeSnapshot({
    listing: {productType: "Line Pipe"},
    agreedQuantity: 250,
    agreedTotal: 25000,
    currency: "USD",
  });
  assert.equal(fee.marketplaceFeeMinor, 25000);
  assert.equal(fee.currency, "USD");
});
