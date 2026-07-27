"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  AdministratorAuthorizationError,
  administratorClaimUpdate,
  administratorClaims,
  enrolledFactorCount,
  isAdministrator,
  requireAdministrator,
  validateAdministratorCandidate,
} = require("../administrator_authorization");

test("administrator access requires role, admin, and MFA claims", () => {
  assert.equal(administratorClaims({}), false);
  assert.equal(administratorClaims({admin: true}), false);
  assert.equal(administratorClaims({
    admin: true,
    role: "administrator",
  }), false);
  assert.equal(administratorClaims({
    admin: true,
    role: "administrator",
    firebase: {sign_in_second_factor: "phone"},
  }), true);
  assert.equal(isAdministrator({
    auth: {uid: "admin", token: {
      admin: true,
      role: "administrator",
      firebase: {sign_in_second_factor: "phone"},
    }},
  }), true);
});

test("an email address never grants administrator access", () => {
  assert.equal(isAdministrator({
    auth: {
      uid: "ordinary-user",
      token: {email: "jordilwbailey@gmail.com", email_verified: true},
    },
  }), false);
});

test("requireAdministrator fails closed with actionable errors", () => {
  assert.throws(
      () => requireAdministrator({}),
      (error) => error instanceof AdministratorAuthorizationError &&
        error.code === "unauthenticated",
  );
  assert.throws(
      () => requireAdministrator({auth: {uid: "user", token: {admin: true}}}),
      (error) => error instanceof AdministratorAuthorizationError &&
        error.code === "permission-denied",
  );
});

test("administrator candidates require verified email and an enrolled factor", () => {
  const valid = {
    uid: "admin",
    disabled: false,
    emailVerified: true,
    multiFactor: {enrolledFactors: [{factorId: "phone"}]},
  };
  assert.equal(enrolledFactorCount(valid), 1);
  assert.equal(validateAdministratorCandidate(valid), "admin");
  assert.throws(
      () => validateAdministratorCandidate({...valid, emailVerified: false}),
      /Verify the account email/,
  );
  assert.throws(
      () => validateAdministratorCandidate({
        ...valid,
        multiFactor: {enrolledFactors: []},
      }),
      /Enroll a supported Firebase multi-factor method/,
  );
});

test("claim updates preserve unrelated roles and revoke admin fields", () => {
  const granted = administratorClaimUpdate({accountType: "business"}, true);
  assert.deepEqual(granted, {
    accountType: "business",
    admin: true,
    role: "administrator",
  });
  assert.deepEqual(administratorClaimUpdate(granted, false), {
    accountType: "business",
  });
});
