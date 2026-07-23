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
