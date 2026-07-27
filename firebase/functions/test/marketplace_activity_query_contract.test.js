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
