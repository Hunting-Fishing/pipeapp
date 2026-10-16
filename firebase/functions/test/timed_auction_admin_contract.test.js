"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

function read(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
}

function between(source, start, end) {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(startIndex, -1, `Missing contract start: ${start}`);
  assert.notEqual(endIndex, -1, `Missing contract end: ${end}`);
  return source.slice(startIndex, endIndex);
}

test("timed-auction administrator callable is App Check and policy protected", () => {
  const index = read("functions/index.js");
  const exported = between(
      index,
      "exports.administerTimedAuction",
      "exports.updateAuctionTransaction",
  );
  assert.match(exported, /onCall\(\s*protectedCallableOptions/u);
  assert.match(exported, /requireCurrentPolicies/u);
  assert.match(exported, /marketplaceCommands\.administerTimedAuction/u);
});

test("administrator auction controls require MFA and authoritative finalization", () => {
  const commands = read("functions/marketplace_commands.js");
  const handler = between(
      commands,
      "const administerTimedAuction",
      "const buyAuctionNow",
  );
  assert.match(handler, /requireAdministrator\(request\)/u);
  assert.match(handler, /validateTimedAuctionAdministration/u);
  assert.match(handler, /finalizeAuctionRecord\(/u);
  assert.match(handler, /auctionEndAt:\s*Timestamp\.fromMillis/u);
  assert.match(handler, /auction_transactions/u);
  assert.match(handler, /marketplace_transactions/u);
  assert.match(handler, /auction_administration_audits/u);
  assert.doesNotMatch(handler, /request\.data\.(winner|winnerUid|amount)/u);
  assert.doesNotMatch(handler, /collection\("auction_bids"\)/u);
});

test("Flutter auction controls invoke the server command instead of writing listings", () => {
  const dashboard = read("../lib/marketplace/marketplace_admin_dashboard.dart");
  const handler = between(
      dashboard,
      "Future<void> _adminAuctionAction",
      "// 3. Read-only transaction lifecycle records",
  );
  assert.match(handler, /MarketplaceCommandClient\(\)\.execute\('administerTimedAuction'/u);
  assert.match(handler, /'requestId': requestId/u);
  assert.doesNotMatch(handler, /collection\('public_listings'\)/u);
  assert.doesNotMatch(handler, /FieldValue\.(increment|serverTimestamp)/u);
});
