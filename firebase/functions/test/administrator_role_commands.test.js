"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  PRIMARY_ADMIN_MANAGER_EMAIL,
  createAdministratorRoleCommands,
  normalizedEmail,
  requireAdministratorManager,
} = require("../administrator_role_commands");

function administratorRequest(email = PRIMARY_ADMIN_MANAGER_EMAIL, data = {}) {
  return {
    auth: {
      uid: "primary-admin-uid",
      token: {
        admin: true,
        role: "administrator",
        email,
        email_verified: true,
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data,
  };
}

function fakeAdmin(target = {}) {
  const calls = {
    claims: [],
    revoked: [],
    writes: [],
  };
  const targetUser = {
    uid: "target-admin-uid",
    email: "newadmin@example.com",
    emailVerified: true,
    disabled: false,
    multiFactor: {enrolledFactors: [{factorId: "phone"}]},
    customClaims: {accountType: "business"},
    ...target,
  };
  const auth = {
    getUserByEmail: async (email) => ({...targetUser, email}),
    getUser: async () => targetUser,
    setCustomUserClaims: async (uid, claims) => calls.claims.push({uid, claims}),
    revokeRefreshTokens: async (uid) => calls.revoked.push(uid),
  };
  const db = {
    collection: (name) => ({
      doc: (id = `${name}-generated`) => ({name, id}),
      where: () => ({
        get: async () => ({
          docs: [{id: targetUser.uid}],
          empty: false,
        }),
      }),
    }),
    batch: () => ({
      set: (ref, data, options) => calls.writes.push({ref, data, options}),
      commit: async () => {},
    }),
  };
  const firestore = () => db;
  firestore.FieldValue = {serverTimestamp: () => "server-time"};
  return {
    runtime: {
      auth: () => auth,
      firestore,
    },
    calls,
  };
}

test("administrator manager identity requires normal admin claims, MFA and the primary email", () => {
  assert.equal(normalizedEmail(" JORDILWBAILEY@GMAIL.COM "), PRIMARY_ADMIN_MANAGER_EMAIL);
  assert.equal(requireAdministratorManager(administratorRequest()).uid, "primary-admin-uid");
  assert.throws(
      () => requireAdministratorManager(administratorRequest("goldcity4u@icloud.com")),
      /Only the primary Pipe Buyer administrator/,
  );
  const withoutMfa = administratorRequest();
  withoutMfa.auth.token.firebase = {};
  assert.throws(() => requireAdministratorManager(withoutMfa), /multi-factor authentication/);
});

test("primary administrator can grant an eligible account and unrelated claims are preserved", async () => {
  const {runtime, calls} = fakeAdmin();
  const commands = createAdministratorRoleCommands(runtime);
  const result = await commands.manageAdministratorRole(
      administratorRequest(PRIMARY_ADMIN_MANAGER_EMAIL, {
        email: "newadmin@example.com",
        enabled: true,
      }),
  );
  assert.equal(result.active, true);
  assert.deepEqual(calls.claims[0], {
    uid: "target-admin-uid",
    claims: {
      accountType: "business",
      admin: true,
      role: "administrator",
    },
  });
  assert.deepEqual(calls.revoked, ["target-admin-uid"]);
  assert.equal(calls.writes.length, 2);
});

test("primary administrator cannot revoke the protected primary account through the app", async () => {
  const {runtime} = fakeAdmin({
    uid: "primary-admin-uid",
    email: PRIMARY_ADMIN_MANAGER_EMAIL,
  });
  const commands = createAdministratorRoleCommands(runtime);
  await assert.rejects(
      commands.manageAdministratorRole(
          administratorRequest(PRIMARY_ADMIN_MANAGER_EMAIL, {
            email: PRIMARY_ADMIN_MANAGER_EMAIL,
            enabled: false,
          }),
      ),
      /primary administrator cannot remove their own administrator access/i,
  );
});

test("administrator grant fails closed when the target does not have MFA", async () => {
  const {runtime} = fakeAdmin({
    multiFactor: {enrolledFactors: []},
  });
  const commands = createAdministratorRoleCommands(runtime);
  await assert.rejects(
      commands.manageAdministratorRole(
          administratorRequest(PRIMARY_ADMIN_MANAGER_EMAIL, {
            email: "newadmin@example.com",
            enabled: true,
          }),
      ),
      /Enroll a supported Firebase multi-factor method/,
  );
});
