"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const configuration = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "..", "firestore.indexes.json"),
    "utf8",
));

function hasListingIndex(expectedFields) {
  return configuration.indexes.some((index) =>
    index.collectionGroup === "public_listings" &&
    index.queryScope === "COLLECTION" &&
    JSON.stringify(index.fields) === JSON.stringify(expectedFields),
  );
}

test("bounded marketplace browse queries have required indexes", () => {
  assert.equal(hasListingIndex([
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ]), true);
  assert.equal(hasListingIndex([
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "category", order: "ASCENDING"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ]), true);
});

test("filtered marketplace browse queries have required indexes", () => {
  const equalityShapes = [
    [],
    [{fieldPath: "category", order: "ASCENDING"}],
    [{fieldPath: "condition", order: "ASCENDING"}],
    [
      {fieldPath: "category", order: "ASCENDING"},
      {fieldPath: "condition", order: "ASCENDING"},
    ],
  ];
  for (const equalityFields of equalityShapes) {
    assert.equal(hasListingIndex([
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "transactionType", order: "ASCENDING"},
      ...equalityFields,
      {fieldPath: "createdAt", order: "DESCENDING"},
    ]), true);
    for (const priceOrder of ["ASCENDING", "DESCENDING"]) {
      assert.equal(hasListingIndex([
        {fieldPath: "status", order: "ASCENDING"},
        {fieldPath: "transactionType", order: "ASCENDING"},
        ...equalityFields,
        {fieldPath: "price", order: priceOrder},
        {fieldPath: "createdAt", order: "DESCENDING"},
      ]), true);
    }
  }
});

test("bounded auction queries have required indexes", () => {
  for (const fields of [
    [
      {fieldPath: "transactionType", order: "ASCENDING"},
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "auctionEndAt", order: "ASCENDING"},
    ],
    [
      {fieldPath: "transactionType", order: "ASCENDING"},
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "auctionEndAt", order: "DESCENDING"},
    ],
    [
      {fieldPath: "transactionType", order: "ASCENDING"},
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "auctionStartAt", order: "ASCENDING"},
    ],
    [
      {fieldPath: "sellerUid", order: "ASCENDING"},
      {fieldPath: "transactionType", order: "ASCENDING"},
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "createdAt", order: "DESCENDING"},
    ],
  ]) {
    assert.equal(hasListingIndex(fields), true);
  }
});

test("bounded seller listing queries have required indexes", () => {
  assert.equal(hasListingIndex([
    {fieldPath: "sellerUid", order: "ASCENDING"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ]), true);
  assert.equal(hasListingIndex([
    {fieldPath: "sellerUid", order: "ASCENDING"},
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ]), true);
});
