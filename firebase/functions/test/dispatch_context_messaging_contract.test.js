"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "../../..");
const read = (relativePath) => fs.readFileSync(
    path.join(root, relativePath),
    "utf8",
);

test("Dispatch conversations use existing safe messaging infrastructure", () => {
  const source = read("firebase/functions/communication_commands.js");
  const start = source.indexOf("const openDispatchConversation = secured(");
  const end = source.indexOf(
      "const markMarketplaceConversationRead = secured(",
      start,
  );
  assert.ok(start >= 0 && end > start, "Dispatch opener must exist");
  const opener = source.slice(start, end);

  assert.match(opener, /collection\("dispatch_jobs"\)/);
  assert.match(opener, /collection\("dispatch_bids"\)/);
  assert.match(opener, /collection\("dispatch_transactions"\)/);
  assert.match(opener, /uid !== customerUid && uid !== carrierUid/);
  assert.match(opener, /contextType: "dispatch_job"/);
  assert.match(opener, /memberUids/);
  assert.match(opener, /listingId: null/);
  assert.doesNotMatch(opener, /dispatch_job_private/);
  assert.doesNotMatch(opener, /pickupPoint/);
  assert.doesNotMatch(opener, /deliveryPoint/);
  assert.doesNotMatch(opener, /deliveryAddress/);
});

test("Dispatch conversation callable is exported through protected index", () => {
  const index = read("firebase/functions/index.js");
  assert.match(index, /exports\.openDispatchConversation = onCall\(/);
  assert.match(
      index,
      /communicationCommands\.openDispatchConversation/,
  );
  assert.match(index, /policyAcceptanceCommands\.requireCurrentPolicies/);
});
