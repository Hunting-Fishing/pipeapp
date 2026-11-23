"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  guardCallableHandler,
  requireCallableAccountActive,
} = require("../callable_account_guard");

function fakeAdmin(tombstoneExists) {
  return {
    firestore: () => ({
      collection: (name) => {
        assert.equal(name, "account_deletion_tombstones");
        return {
          doc: (uid) => ({
            get: async () => ({exists: tombstoneExists, id: uid}),
          }),
        };
      },
    }),
  };
}

test("callable guard allows signed-out and active-account requests", async () => {
  await assert.doesNotReject(
      requireCallableAccountActive(fakeAdmin(false), {}),
  );
  const guarded = guardCallableHandler(
      fakeAdmin(false),
      async (request) => ({uid: request.auth.uid}),
  );
  assert.deepEqual(
      await guarded({auth: {uid: "active-user"}}),
      {uid: "active-user"},
  );
});

test("callable guard rejects cached tokens after deletion starts", async () => {
  const guarded = guardCallableHandler(
      fakeAdmin(true),
      async () => ({unsafe: true}),
  );
  await assert.rejects(
      guarded({auth: {uid: "deleting-user"}}),
      /Account deletion is processing/,
  );
});

test("every Functions callable entrypoint applies the shared guard", () => {
  for (const fileName of ["index.js", "bootstrap.js", "production_bootstrap.js"]) {
    const source = fs.readFileSync(path.join(__dirname, "..", fileName), "utf8");
    assert.match(
        source,
        /timeoutSeconds:\s*CALLABLE_TIMEOUT_SECONDS/,
        `${fileName} must enforce the bounded callable timeout`,
    );
    assert.match(
        source,
        /guardCallableHandler\(admin, handler\)/,
        `${fileName} must wrap Firebase onCall with the account guard`,
    );
    assert.doesNotMatch(
        source,
        /\bonCall\s*:\s*onCall\b/,
        `${fileName} must not import an unguarded onCall binding`,
    );
  }
});

test("protected callables finish before the deletion drain window", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "..", "app_check_config.js"),
      "utf8",
  );
  assert.match(source, /CALLABLE_TIMEOUT_SECONDS = 60/);
  assert.match(source, /timeoutSeconds:\s*CALLABLE_TIMEOUT_SECONDS/);
  const accountPrivacy = fs.readFileSync(
      path.join(__dirname, "..", "account_privacy_commands.js"),
      "utf8",
  );
  assert.match(accountPrivacy, /DELETION_MUTATION_DRAIN_MINUTES = 2/);
  assert.match(
      accountPrivacy,
      /now \+ DELETION_MUTATION_DRAIN_MINUTES \* 60 \* 1000/,
  );
});
