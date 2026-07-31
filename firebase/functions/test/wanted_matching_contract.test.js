"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const functionsRoot = path.join(__dirname, "..");
const serviceSource = fs.readFileSync(
    path.join(functionsRoot, "wanted_matching.js"), "utf8");
const triggerSource = fs.readFileSync(
    path.join(functionsRoot, "index.js"), "utf8");
const commandSource = fs.readFileSync(
    path.join(functionsRoot, "marketplace_commands.js"), "utf8");
const rulesSource = fs.readFileSync(
    path.join(functionsRoot, "..", "firestore.rules"), "utf8");
const indexes = JSON.parse(fs.readFileSync(
    path.join(functionsRoot, "..", "firestore.indexes.json"), "utf8"));

test("wanted matching uses bounded queries and deterministic writes", () => {
  assert.match(serviceSource, /limit\(MAXIMUM_WANTED_CANDIDATES\)/u);
  assert.match(serviceSource,
      /slice\(0, MAXIMUM_WANTED_MATCHES_PER_LISTING\)/u);
  assert.match(serviceSource, /collection\("wanted_matches"\)\.doc\(matchId\)/u);
  assert.match(triggerSource, /\.limit\(500\)/u);
  assert.match(triggerSource, /doc\(`watch-\$\{event\.params\.listingId\}`\)/u);
});

test("wanted match documents are participant-readable and server-written", () => {
  assert.match(rulesSource, /match \/wanted_matches\/\{matchId\}/u);
  assert.match(rulesSource, /resource\.data\.wantedOwnerUid/u);
  assert.match(rulesSource, /resource\.data\.sellerUid/u);
  assert.match(rulesSource, /allow create, update, delete: if false;/u);
  assert.match(rulesSource, /match \/events\/\{eventId\}/u);
  assert.match(triggerSource, /exports\.manageWantedMatch = onCall/u);
  assert.match(commandSource, /receiptData\(uid, "manageWantedMatch"/u);
  assert.match(commandSource, /collection\("events"\)/u);
  assert.match(commandSource, /responseCount: FieldValue\.increment\(1\)/u);
});

test("wanted match owner query has a deployed composite index declaration", () => {
  const found = indexes.indexes.some((index) =>
    index.collectionGroup === "wanted_matches" &&
    JSON.stringify(index.fields) === JSON.stringify([
      {fieldPath: "wantedListingId", order: "ASCENDING"},
      {fieldPath: "score", order: "DESCENDING"},
    ]));
  assert.equal(found, true);
});

test("counterpart candidate query has its required composite index", () => {
  const found = indexes.indexes.some((index) =>
    index.collectionGroup === "public_listings" &&
    JSON.stringify(index.fields) === JSON.stringify([
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "transactionType", order: "ASCENDING"},
      {fieldPath: "category", order: "ASCENDING"},
      {fieldPath: "createdAt", order: "DESCENDING"},
    ]));
  assert.equal(found, true);
});

test("supply owners have an indexed Wanted buyer match query", () => {
  const found = indexes.indexes.some((index) =>
    index.collectionGroup === "wanted_matches" &&
    JSON.stringify(index.fields) === JSON.stringify([
      {fieldPath: "supplyListingId", order: "ASCENDING"},
      {fieldPath: "score", order: "DESCENDING"},
    ]));
  assert.equal(found, true);
});
