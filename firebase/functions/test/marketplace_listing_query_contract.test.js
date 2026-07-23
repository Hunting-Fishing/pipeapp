"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const workspace = path.join(__dirname, "..", "..", "..");

function source(relativePath) {
  return fs.readFileSync(path.join(workspace, relativePath), "utf8");
}

test("shared marketplace listing pages always apply a Firestore limit", () => {
  const query = source("lib/marketplace/marketplace_listing_query.dart");
  assert.match(query, /query\.limit\(pageSize\)/);
  assert.match(query, /marketplaceListingPageSize = 24/);
});

test("auction and seller listing surfaces use bounded pages", () => {
  const auctions = source("lib/marketplace/marketplace_auctions_page.dart");
  const account = source("lib/marketplace/marketplace_account_hub.dart");
  const profile = source(
      "lib/marketplace/marketplace_public_profile_page.dart",
  );
  assert.match(auctions, /loadMarketplaceListingPage\(/);
  assert.match(account, /loadMarketplaceListingPage\(/);
  assert.match(profile, /loadMarketplaceListingPage\(/);
});

test("map and Dispatch selectors use explicit maximum result counts", () => {
  const map = source("lib/marketplace/marketplace_location_picker.dart");
  const dispatch = source("lib/marketplace/marketplace_dispatch_page.dart");
  assert.match(map, /_mapResultLimit = 200/);
  assert.match(map, /\.limit\(_mapResultLimit\)/);
  assert.match(dispatch, /\.limit\(50\)/);
});
