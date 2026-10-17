"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  CLAIM_NAME,
  EXPECTED_PROJECT_ID,
  GUARD_CONFIRMATION_VALUE,
  GUARD_ENVIRONMENT_VARIABLE,
  execute,
  safeFailureMessage,
  targetFingerprint,
} = require("../scripts/set_apple_sandbox_tester_claim");

const TARGET_UID = "firebase-user-uid-that-must-never-be-printed";
const TARGET_EMAIL = "private.tester@example.com";
const SECRET_CLAIM_VALUE = "must-never-be-printed";
const TARGET_FINGERPRINT = targetFingerprint(EXPECTED_PROJECT_ID, TARGET_UID);

function environment() {
  return {[GUARD_ENVIRONMENT_VARIABLE]: GUARD_CONFIRMATION_VALUE};
}

function fakeAuth(customClaims = {}, options = {}) {
  const calls = {getUser: [], getUserByEmail: [], setCustomUserClaims: []};
  let storedClaims = {...customClaims};
  const user = () => ({
    uid: TARGET_UID,
    email: TARGET_EMAIL,
    customClaims: {...storedClaims},
  });
  return {
    calls,
    auth: {
      async getUser(uid) {
        calls.getUser.push(uid);
        const prewriteRead = calls.setCustomUserClaims.length === 0 &&
          (calls.getUserByEmail.length > 0 || calls.getUser.length > 1);
        if (options.claimsDriftBeforeWrite && prewriteRead) {
          return {
            ...user(),
            customClaims: {...storedClaims, concurrentRoleChange: true},
          };
        }
        if (options.verificationMismatch &&
            calls.setCustomUserClaims.length > 0) {
          return {...user(), customClaims: {different: true}};
        }
        return user();
      },
      async getUserByEmail(email) {
        calls.getUserByEmail.push(email);
        return user();
      },
      async setCustomUserClaims(uid, claims) {
        calls.setCustomUserClaims.push({uid, claims: {...claims}});
        storedClaims = {...claims};
      },
    },
  };
}

async function run(argv, authState) {
  const lines = [];
  const result = await execute(argv, {
    environment: environment(),
    authFactory: async (projectId) => {
      assert.equal(projectId, EXPECTED_PROJECT_ID);
      return authState.auth;
    },
    writeLine: (line) => lines.push(String(line)),
  });
  return {lines, result};
}

test("dry-run is the default and emits only redacted target information", async () => {
  const authState = fakeAuth({accountType: SECRET_CLAIM_VALUE});
  const {lines, result} = await run([
    "--project", EXPECTED_PROJECT_ID,
    "--email", TARGET_EMAIL,
    "--grant",
  ], authState);

  assert.equal(result.mode, "dry-run");
  assert.equal(result.verified, false);
  assert.equal(result.targetFingerprint, TARGET_FINGERPRINT);
  assert.equal(authState.calls.getUserByEmail.length, 1);
  assert.equal(authState.calls.getUser.length, 0);
  assert.equal(authState.calls.setCustomUserClaims.length, 0);
  const output = lines.join("\n");
  assert.doesNotMatch(output, new RegExp(TARGET_EMAIL, "u"));
  assert.doesNotMatch(output, new RegExp(TARGET_UID, "u"));
  assert.doesNotMatch(output, new RegExp(SECRET_CLAIM_VALUE, "u"));
  assert.match(output, new RegExp(TARGET_FINGERPRINT, "u"));
  assert.match(output, /Dry run complete/u);
});

test("apply grant preserves unrelated claims and verifies by re-reading", async () => {
  const existing = {accountType: "business", staff: false};
  const authState = fakeAuth(existing);
  const {result} = await run([
    "--project", EXPECTED_PROJECT_ID,
    "--uid", TARGET_UID,
    "--grant",
    "--apply",
    "--confirm-target", TARGET_FINGERPRINT,
  ], authState);

  assert.equal(result.verified, true);
  assert.equal(result.writeSkipped, false);
  assert.deepEqual(authState.calls.setCustomUserClaims, [{
    uid: TARGET_UID,
    claims: {...existing, [CLAIM_NAME]: true},
  }]);
  assert.deepEqual(
      authState.calls.getUser,
      [TARGET_UID, TARGET_UID, TARGET_UID],
  );
});

test("apply revoke removes only the Apple Sandbox tester claim", async () => {
  const authState = fakeAuth({
    accountType: "business",
    [CLAIM_NAME]: true,
    unrelated: 7,
  });
  const {result} = await run([
    "--project", EXPECTED_PROJECT_ID,
    "--email", TARGET_EMAIL,
    "--revoke",
    "--apply",
    "--confirm-target", TARGET_FINGERPRINT,
  ], authState);

  assert.equal(result.resultingEnabled, false);
  assert.equal(result.writeSkipped, false);
  assert.deepEqual(authState.calls.setCustomUserClaims[0].claims, {
    accountType: "business",
    unrelated: 7,
  });
  assert.equal(authState.calls.getUserByEmail.length, 1);
  assert.equal(authState.calls.getUser.length, 2);
});

test("apply requires the exact redacted target fingerprint", async () => {
  const authState = fakeAuth({accountType: "business"});
  await assert.rejects(run([
    "--project", EXPECTED_PROJECT_ID,
    "--email", TARGET_EMAIL,
    "--grant",
    "--apply",
    "--confirm-target", "0".repeat(64),
  ], authState), /did not match the resolved redacted target/u);
  assert.equal(authState.calls.setCustomUserClaims.length, 0);

  let authFactoryCalls = 0;
  await assert.rejects(execute([
    "--project", EXPECTED_PROJECT_ID,
    "--email", TARGET_EMAIL,
    "--grant",
    "--apply",
  ], {
    environment: environment(),
    authFactory: async () => {
      authFactoryCalls += 1;
      return authState.auth;
    },
    writeLine: () => {},
  }), /requires the exact 64-character fingerprint/u);
  assert.equal(authFactoryCalls, 0);
});

test("apply aborts when unrelated claims drift before the write", async () => {
  const authState = fakeAuth({accountType: "business"}, {
    claimsDriftBeforeWrite: true,
  });
  await assert.rejects(run([
    "--project", EXPECTED_PROJECT_ID,
    "--email", TARGET_EMAIL,
    "--grant",
    "--apply",
    "--confirm-target", TARGET_FINGERPRINT,
  ], authState), /custom claims changed after resolution/u);
  assert.equal(authState.calls.setCustomUserClaims.length, 0);
});

test("apply verifies and skips an already-satisfied claim", async () => {
  const authState = fakeAuth({
    accountType: "business",
    [CLAIM_NAME]: true,
  });
  const {lines, result} = await run([
    "--project", EXPECTED_PROJECT_ID,
    "--uid", TARGET_UID,
    "--grant",
    "--apply",
    "--confirm-target", TARGET_FINGERPRINT,
  ], authState);
  assert.equal(result.verified, true);
  assert.equal(result.changeRequired, false);
  assert.equal(result.writeSkipped, true);
  assert.equal(authState.calls.setCustomUserClaims.length, 0);
  assert.deepEqual(authState.calls.getUser, [TARGET_UID, TARGET_UID]);
  assert.match(lines.join("\n"), /No custom claims were written/u);
});

test("the exact project and separate environment guard are mandatory", async () => {
  let authFactoryCalls = 0;
  const dependencies = {
    environment: {},
    authFactory: async () => {
      authFactoryCalls += 1;
      return fakeAuth().auth;
    },
    writeLine: () => {},
  };
  await assert.rejects(execute([
    "--project", "different-project",
    "--uid", TARGET_UID,
    "--grant",
  ], dependencies), /must be exactly flutter-flow-pipe/u);
  await assert.rejects(execute([
    "--project", EXPECTED_PROJECT_ID,
    "--uid", TARGET_UID,
    "--grant",
  ], dependencies), /environment guard|PIPE_APPLE_SANDBOX_CLAIM_GUARD/u);
  assert.equal(authFactoryCalls, 0);
});

test("exactly one selector and one action are required", async () => {
  const base = ["--project", EXPECTED_PROJECT_ID];
  const dependencies = {
    environment: environment(),
    authFactory: async () => fakeAuth().auth,
    writeLine: () => {},
  };
  await assert.rejects(execute([
    ...base,
    "--uid", TARGET_UID,
    "--email", TARGET_EMAIL,
    "--grant",
  ], dependencies), /exactly one target selector/u);
  await assert.rejects(execute([
    ...base,
    "--uid", TARGET_UID,
    "--grant",
    "--revoke",
  ], dependencies), /exactly one action/u);
  await assert.rejects(execute([
    ...base,
    "--uid", TARGET_UID,
    "--grant",
    "--unexpected-secret-like-value",
  ], dependencies), (error) => {
    assert.doesNotMatch(error.message, /unexpected-secret-like-value/u);
    return /Unknown argument/u.test(error.message);
  });
});

test("apply fails when the post-write claim set does not verify", async () => {
  const authState = fakeAuth({accountType: "business"}, {
    verificationMismatch: true,
  });
  await assert.rejects(run([
    "--project", EXPECTED_PROJECT_ID,
    "--uid", TARGET_UID,
    "--grant",
    "--apply",
    "--confirm-target", TARGET_FINGERPRINT,
  ], authState), /post-write verification/u);
  assert.equal(authState.calls.setCustomUserClaims.length, 1);
  assert.equal(authState.calls.getUser.length, 3);
});

test("help is offline and sanitized failures do not echo Firebase details", async () => {
  let authFactoryCalls = 0;
  const lines = [];
  await execute(["--help"], {
    environment: {},
    authFactory: async () => {
      authFactoryCalls += 1;
      throw new Error("should not run");
    },
    writeLine: (line) => lines.push(String(line)),
  });
  assert.equal(authFactoryCalls, 0);
  assert.match(lines.join("\n"), /dry-run/u);

  const unsafeError = Object.assign(
      new Error(`${TARGET_EMAIL} ${TARGET_UID} ${SECRET_CLAIM_VALUE}`),
      {code: `auth/user-not-found/${TARGET_EMAIL}`},
  );
  const safeMessage = safeFailureMessage(unsafeError);
  assert.doesNotMatch(safeMessage, new RegExp(TARGET_EMAIL, "u"));
  assert.doesNotMatch(safeMessage, new RegExp(TARGET_UID, "u"));
  assert.doesNotMatch(safeMessage, new RegExp(SECRET_CLAIM_VALUE, "u"));
  assert.equal(safeMessage, "Operation failed. Target details remain redacted.");
});
