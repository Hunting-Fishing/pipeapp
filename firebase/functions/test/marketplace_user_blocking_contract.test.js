"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const test = require("node:test");
const {
  blockDocumentId,
  normalizeConversationMembers,
} = require("../marketplace_user_block_commands");

test("block document ids are directional and deterministic", () => {
  assert.equal(blockDocumentId("buyer", "seller"), blockDocumentId("buyer", "seller"));
  assert.notEqual(blockDocumentId("buyer", "seller"), blockDocumentId("seller", "buyer"));
});

test("conversation member normalization is defensive", () => {
  assert.deepEqual(normalizeConversationMembers({memberUids: ["buyer", "seller"]}), ["buyer", "seller"]);
  assert.deepEqual(normalizeConversationMembers({}), []);
  assert.deepEqual(normalizeConversationMembers(null), []);
});

test("sendMarketplaceMessage is guarded by server-authoritative block status", () => {
  const index = fs.readFileSync(require.resolve("../index.js"), "utf8");
  assert.match(index, /requireConversationMessagingAllowed\(request\)/);
  assert.match(index, /sendMarketplaceMessageWithBlockGuard/);
  assert.match(index, /readMarketplaceUserBlockStatus/);
  assert.match(index, /setMarketplaceUserBlocked/);
});

test("client block UI preserves history and moderation evidence", () => {
  const messages = fs.readFileSync(
      require.resolve("../../../lib/marketplace/marketplace_messages_page.dart"),
      "utf8",
  );
  assert.match(messages, /Block member/);
  assert.match(messages, /Unblock member/);
  assert.match(messages, /Existing messages and any Trust & Safety reports stay saved/);
  assert.match(messages, /Message history and reports stay saved/);
  assert.doesNotMatch(messages, /marketplace_user_blocks.*delete/);
});


test("client permits reciprocal blocking when the other member blocked first", () => {
  const messages = fs.readFileSync(
      require.resolve("../../../lib/marketplace/marketplace_messages_page.dart"),
      "utf8",
  );
  assert.match(messages, /enabled:\s*!_blockBusy,/);
  assert.match(messages, /if \(_blockBusy\) return;/);
  assert.doesNotMatch(
      messages,
      /enabled:\s*!_blockBusy\s*&&\s*!_blockedMe/,
  );
  assert.doesNotMatch(
      messages,
      /if\s*\(_blockBusy\s*\|\|\s*_blockedMe\)\s*return/,
  );
});
