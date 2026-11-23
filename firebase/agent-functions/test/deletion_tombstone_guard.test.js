"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  hasDeletionTombstone,
} = require("../deletion_tombstone_guard");

function fakeDb(exists) {
  return {
    collection: (name) => {
      assert.equal(name, "account_deletion_tombstones");
      return {doc: () => ({get: async () => ({exists})})};
    },
  };
}

test("administrator callable tombstone guard fails closed", async () => {
  assert.equal(await hasDeletionTombstone(fakeDb(false), "active"), false);
  assert.equal(await hasDeletionTombstone(fakeDb(true), "deleting"), true);
  assert.equal(await hasDeletionTombstone(fakeDb(true), ""), false);
});

test("both administrator callable entrypoints consult the tombstone guard", () => {
  const source = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  assert.match(
      source,
      /context\.auth && await hasDeletionTombstone\(/,
      "the v1 administrator agent must reject tombstoned accounts",
  );
  assert.match(
      source,
      /await hasDeletionTombstone\(db, adminUid\)/,
      "the v2 integration manager must reject tombstoned accounts",
  );
});
