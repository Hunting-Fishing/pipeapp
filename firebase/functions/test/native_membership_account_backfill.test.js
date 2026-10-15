"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  NativeMembershipAccountBackfillError,
  buildNativeMembershipAccountTokenBackfillPlan,
  createNativeMembershipAccountBackfill,
  preflightNativeMembershipAccountTokenIndexes,
} = require("../native_membership_account_backfill");

const firstToken = "123e4567-e89b-42d3-a456-426614174000";
const secondToken = "123e4567-e89b-42d3-a456-426614174001";

function accountDocument(id, token) {
  return {id, data: () => ({storeAccountToken: token})};
}

test("account-token backfill plan rejects duplicate ownership before writes", () => {
  assert.throws(
      () => buildNativeMembershipAccountTokenBackfillPlan([
        accountDocument("user-1", firstToken),
        accountDocument("user-2", firstToken),
      ]),
      (error) => error instanceof NativeMembershipAccountBackfillError &&
        error.code === "native_account_token_collision",
  );
  assert.throws(
      () => buildNativeMembershipAccountTokenBackfillPlan([
        accountDocument("user-1", "not-a-token"),
      ]),
      (error) => error.code === "native_account_token_source_invalid",
  );
});

test("account-token backfill preflight aborts on an existing index collision", async () => {
  const plan = buildNativeMembershipAccountTokenBackfillPlan([
    accountDocument("user-1", firstToken),
    accountDocument("user-2", secondToken),
  ]);
  const db = {
    collection() {
      return {
        doc(id) {
          return {id};
        },
      };
    },
    async getAll(...refs) {
      return refs.map((ref, index) => ({
        exists: true,
        data: () => ({
          ownerUid: index === 0 ? "another-user" : plan[index].ownerUid,
          storeAccountToken: plan[index].storeAccountToken,
        }),
      }));
    },
  };
  await assert.rejects(
      preflightNativeMembershipAccountTokenIndexes({db, plan}),
      (error) => error instanceof NativeMembershipAccountBackfillError &&
        error.code === "native_account_token_collision",
  );
});

function administratorRequest(data = {}) {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data,
  };
}

test("account-token backfill callable is administrator-only and dry-runs by default", async () => {
  const calls = [];
  const admin = {
    firestore: () => ({}),
  };
  const command = createNativeMembershipAccountBackfill(admin, {
    runBackfill: async (value) => {
      calls.push(value);
      return {
        dryRun: value.dryRun,
        scanned: 2,
        indexed: 2,
        pending: 2,
        written: value.dryRun ? 0 : 2,
        collisionFree: true,
      };
    },
    logger: {info() {}, error() {}},
  }).backfillNativeMembershipAccountTokensForAdmin;

  await assert.rejects(
      command({data: {}}),
      (error) => error.code === "unauthenticated",
  );
  const audit = await command(administratorRequest());
  assert.equal(audit.dryRun, true);
  assert.equal(audit.written, 0);
  const write = await command(administratorRequest({confirmWrite: true}));
  assert.equal(write.dryRun, false);
  assert.equal(write.written, 2);
  assert.deepEqual(calls.map((value) => value.dryRun), [true, false]);
});
