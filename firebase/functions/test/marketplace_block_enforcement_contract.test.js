"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  blockDocumentId,
  createMarketplaceUserBlockCommands,
} = require("../marketplace_user_block_commands");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");

function fakeAdmin(blocks) {
  const db = {
    collection: (name) => {
      assert.equal(name, "marketplace_user_blocks");
      return {
        doc: (id) => ({
          get: async () => ({
            exists: Object.hasOwn(blocks, id),
            data: () => blocks[id],
          }),
        }),
      };
    },
  };
  return {firestore: Object.assign(() => db, {FieldValue: {}})};
}

test("pairBlockStatus reports directional blocks and ignores inactive or empty pairs", async () => {
  const blocks = {
    [blockDocumentId("seller", "buyer")]: {active: true},
    [blockDocumentId("carrier", "customer")]: {active: false},
  };
  const {pairBlockStatus} = createMarketplaceUserBlockCommands(fakeAdmin(blocks));

  assert.deepEqual(await pairBlockStatus("seller", "buyer"), {
    blocked: true, blockedByViewer: true, blockedViewer: false,
  });
  assert.deepEqual(await pairBlockStatus("buyer", "seller"), {
    blocked: true, blockedByViewer: false, blockedViewer: true,
  });
  assert.equal((await pairBlockStatus("carrier", "customer")).blocked, false);
  assert.equal((await pairBlockStatus("a", "b")).blocked, false);
  assert.equal((await pairBlockStatus("a", "a")).blocked, false);
  assert.equal((await pairBlockStatus("", "b")).blocked, false);
});

test("block status is created before, and shared with, every command module that starts contact", () => {
  const index = read("index.js");
  const blockAt = index.indexOf("createMarketplaceUserBlockCommands(admin)");
  const communicationAt = index.indexOf("createCommunicationCommands(admin, blockEnforcement)");
  const dispatchAt = index.indexOf("createDispatchCommands(admin, blockEnforcement)");
  const marketplaceAt = index.indexOf("createMarketplaceCommands(admin, blockEnforcement)");
  assert.ok(blockAt > 0, "block commands must be constructed in index.js");
  for (const at of [communicationAt, dispatchAt, marketplaceAt]) {
    assert.ok(at > blockAt, "block commands must exist before the modules that use them");
  }
  assert.match(index, /pairBlockStatus: marketplaceUserBlockCommands\.pairBlockStatus/);
  assert.equal(index.split("createMarketplaceUserBlockCommands(admin)").length - 1, 1);
});

test("new offers, new conversations, and new Dispatch quotes consult the pair block", () => {
  const communication = read("communication_commands.js");
  assert.equal(communication.split("await assertNotBlocked(").length - 1, 2);
  assert.match(communication, /if \(!\(await conversationRef\.get\(\)\)\.exists\)/);
  assert.match(read("marketplace_commands.js"), /pairBlockStatus\(\s*uid,\s*String\(listing\.sellerUid\)/);
  assert.match(read("dispatch_commands.js"), /pairBlockStatus\(\s*uid,\s*String\(job\.createdByUid\)/);
});

test("each module keeps an inert default so it still works without block wiring", () => {
  for (const file of ["communication_commands.js", "marketplace_commands.js", "dispatch_commands.js"]) {
    assert.match(read(file), /\{pairBlockStatus = async \(\) => \(\{blocked: false\}\)\} = \{\}/, file);
  }
});

test("refusal messages never reveal who blocked whom to the blocked member", () => {
  const sources = [
    read("communication_commands.js"),
    read("marketplace_commands.js"),
    read("dispatch_commands.js"),
  ].join("\n");
  assert.equal(/blocked you|you were blocked|has blocked/i.test(sources), false);
  assert.match(sources, /not accepting new contact right now/);
  assert.match(sources, /not accepting new offers right now/);
  assert.match(sources, /not accepting new quotes right now/);
});
