"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const workspace = path.join(__dirname, "..", "..", "..");

function source(relativePath) {
  return fs.readFileSync(path.join(workspace, relativePath), "utf8");
}

test("conversation and notification activity feeds are bounded", () => {
  const query = source("lib/core/data/bounded_firestore_query.dart");
  const messages = source("lib/marketplace/marketplace_messages_page.dart");
  const account = source("lib/marketplace/marketplace_account_hub.dart");

  assert.match(query, /defaultActivityFeedLimit = 100/);
  assert.match(query, /defaultBatchMutationLimit = 450/);
  assert.match(
      messages,
      /where\('memberUids', arrayContains: uid\)[\s\S]{0,160}orderBy\('lastMessageAt', descending: true\)[\s\S]{0,100}limit\(defaultActivityFeedLimit\)/,
  );
  assert.ok(
      messages.match(/\.limit\(defaultActivityFeedLimit\)/g).length >= 3,
      "conversation and notification badge streams must stay bounded",
  );
  assert.ok(
      account.match(/\.limit\(defaultActivityFeedLimit\)/g).length >= 3,
      "notification surfaces must stay bounded",
  );
  assert.match(
      account,
      /where\('listingId', isEqualTo: listingId\)[\s\S]{0,180}limit\(defaultBatchMutationLimit\)/,
  );
});

test("high-volume history and operational streams stay bounded", () => {
  const query = source("lib/core/data/bounded_firestore_query.dart");
  const messages = source("lib/marketplace/marketplace_messages_page.dart");
  const auctions = source("lib/marketplace/marketplace_auctions_page.dart");
  const account = source("lib/marketplace/marketplace_account_hub.dart");
  const actions = source("lib/marketplace/marketplace_actions_repository.dart");
  const reporting = source("lib/marketplace/marketplace_reporting.dart");
  const tags = source("lib/marketplace/marketplace_profile_tags.dart");
  const indexes = source("firebase/firestore.indexes.json");

  assert.match(query, /defaultReferenceDataLimit = 500/);
  assert.match(
      messages,
      /collection\('offers'\)[\s\S]{0,100}where\('listingId', isEqualTo: listingId\)[\s\S]{0,180}orderBy\('createdAt', descending: true\)[\s\S]{0,100}limit\(defaultActivityFeedLimit\)/,
  );
  assert.match(
      messages,
      /collection\('messages'\)[\s\S]{0,140}orderBy\('createdAt', descending: true\)[\s\S]{0,100}limit\(defaultActivityFeedLimit\)/,
  );
  assert.match(
      auctions,
      /collection\('auction_bids'\)[\s\S]{0,140}orderBy\('createdAt', descending: true\)[\s\S]{0,100}limit\(defaultActivityFeedLimit\)/,
  );
  assert.match(
      account,
      /collection\('moderation_notices'\)[\s\S]{0,160}orderBy\('updatedAt', descending: true\)[\s\S]{0,100}limit\(defaultActivityFeedLimit\)/,
  );
  assert.match(
      actions,
      /collection\('saved_listings'\)[\s\S]{0,180}limit\(defaultReferenceDataLimit\)/,
  );
  assert.match(
      reporting,
      /collection\('verification_requests'\)[\s\S]{0,160}limit\(defaultActivityFeedLimit\)/,
  );
  assert.ok(
      tags.match(/\.limit\((?:defaultActivityFeedLimit|defaultReferenceDataLimit)\)/g)
          .length >= 3,
      "tag catalogs, user selections, and review queues must stay bounded",
  );
  assert.match(
      indexes,
      /"collectionGroup": "offers"[\s\S]{0,240}"fieldPath": "listingId"[\s\S]{0,140}"fieldPath": "buyerUid"/,
  );
});
