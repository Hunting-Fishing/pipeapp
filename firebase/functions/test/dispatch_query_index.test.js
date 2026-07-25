"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const configuration = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "..", "firestore.indexes.json"),
    "utf8",
));

function hasIndex(collectionGroup, fields) {
  return configuration.indexes.some((index) =>
    index.collectionGroup === collectionGroup &&
    index.queryScope === "COLLECTION" &&
    JSON.stringify(index.fields) === JSON.stringify(fields),
  );
}

test("bounded Dispatch job feeds have required indexes", () => {
  assert.equal(hasIndex("dispatch_jobs", [
    {fieldPath: "status", order: "ASCENDING"},
    {fieldPath: "createdAt", order: "DESCENDING"},
  ]), true);
  assert.equal(hasIndex("dispatch_jobs", [
    {fieldPath: "createdByUid", order: "ASCENDING"},
    {fieldPath: "updatedAt", order: "DESCENDING"},
  ]), true);
});

test("bounded Dispatch bid feeds have required indexes", () => {
  for (const fields of [
    [
      {fieldPath: "carrierUid", order: "ASCENDING"},
      {fieldPath: "updatedAt", order: "DESCENDING"},
    ],
    [
      {fieldPath: "jobId", order: "ASCENDING"},
      {fieldPath: "updatedAt", order: "DESCENDING"},
    ],
    [
      {fieldPath: "carrierUid", order: "ASCENDING"},
      {fieldPath: "jobId", order: "ASCENDING"},
      {fieldPath: "updatedAt", order: "DESCENDING"},
    ],
  ]) {
    assert.equal(hasIndex("dispatch_bids", fields), true);
  }
});

test("Dispatch feeds use bounded pages and aggregate counts", () => {
  const workspace = path.join(__dirname, "..", "..", "..");
  const page = fs.readFileSync(path.join(
      workspace,
      "lib/marketplace/marketplace_dispatch_page.dart",
  ), "utf8");
  const repository = fs.readFileSync(path.join(
      workspace,
      "lib/marketplace/marketplace_dispatch_repository.dart",
  ), "utf8");
  assert.match(page, /_DispatchPagedCollection/);
  assert.match(page, /loadFirestoreDocumentPage\(/);
  assert.match(page, /\.limit\(defaultFirestorePageSize\)\.snapshots\(\)/);
  assert.match(repository, /\.count\(\)/);
  assert.match(repository, /\.where\('jobId', isEqualTo: jobId\)/);
  assert.match(repository, /\.limit\(1\)/);
});
