"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  reconcileNativeMembershipPages,
} = require("../native_membership_reconciliation");

function documents(count) {
  return Array.from({length: count}, (_, index) => ({
    id: `user-${String(index + 1).padStart(4, "0")}`,
  }));
}

test("native reconciliation walks deterministic pages beyond 200 records", async () => {
  const source = documents(450);
  const cursors = [];
  const visited = [];
  const result = await reconcileNativeMembershipPages({
    pageSize: 200,
    maxPages: 10,
    loadPage: async ({startAfter, limit}) => {
      cursors.push(startAfter);
      const offset = startAfter ?
        source.findIndex((document) => document.id === startAfter) + 1 : 0;
      return source.slice(offset, offset + limit);
    },
    reconcileDocument: async (document) => {
      visited.push(document.id);
      return {skipped: false};
    },
  });
  assert.deepEqual(cursors, ["", "user-0200", "user-0400"]);
  assert.equal(new Set(visited).size, 450);
  assert.deepEqual(result, {
    checked: 450,
    updated: 450,
    failed: 0,
    pages: 3,
    complete: true,
    nextCursor: "",
  });
});

test("native reconciliation reports failures and skipped providers", async () => {
  const source = documents(3);
  const result = await reconcileNativeMembershipPages({
    pageSize: 10,
    loadPage: async () => source,
    reconcileDocument: async (document) => {
      if (document.id === "user-0001") return {skipped: true};
      if (document.id === "user-0002") throw new Error("provider unavailable");
      return {skipped: false};
    },
  });
  assert.equal(result.checked, 3);
  assert.equal(result.updated, 1);
  assert.equal(result.failed, 1);
  assert.equal(result.complete, true);
});

test("native reconciliation returns a continuation cursor when bounded", async () => {
  const source = documents(500);
  const result = await reconcileNativeMembershipPages({
    pageSize: 100,
    maxPages: 2,
    startAfter: "user-0100",
    loadPage: async ({startAfter, limit}) => {
      const offset = source.findIndex((document) => document.id === startAfter) + 1;
      return source.slice(offset, offset + limit);
    },
    reconcileDocument: async () => ({skipped: false}),
  });
  assert.equal(result.checked, 200);
  assert.equal(result.complete, false);
  assert.equal(result.nextCursor, "user-0300");
});
