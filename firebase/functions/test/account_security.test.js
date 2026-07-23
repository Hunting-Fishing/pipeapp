"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  AccountSecurityError,
  phoneRegistryKey,
  requireAuthenticatedIdentity,
  verificationState,
} = require("../account_security");

test("verification state trusts Firebase ownership claims only", () => {
  assert.deepEqual(verificationState({
    email: "Owner@Pipe.Test",
    email_verified: true,
    phone_number: "+12505550123",
  }), {
    email: "owner@pipe.test",
    emailVerified: true,
    phoneNumber: "+12505550123",
    phoneVerified: true,
  });
  assert.equal(verificationState({phone_number: "2505550123"}).phoneVerified,
      false);
});

test("protected commands require verified email and phone ownership", () => {
  assert.throws(
      () => requireAuthenticatedIdentity({auth: null}),
      (error) => error instanceof AccountSecurityError &&
        error.code === "unauthenticated",
  );
  assert.throws(
      () => requireAuthenticatedIdentity({auth: {uid: "u1", token: {}}}),
      (error) => error.code === "failed-precondition" &&
        error.message.includes("email"),
  );
  assert.throws(
      () => requireAuthenticatedIdentity({
        auth: {uid: "u1", token: {email_verified: true}},
      }),
      (error) => error.code === "failed-precondition" &&
        error.message.includes("phone"),
  );
  assert.equal(requireAuthenticatedIdentity({
    auth: {
      uid: "u1",
      token: {email_verified: true, phone_number: "+12505550123"},
    },
  }).uid, "u1");
});

test("phone registry keys are deterministic and do not expose phone numbers", () => {
  const first = phoneRegistryKey("+12505550123");
  const second = phoneRegistryKey("+12505550123");
  assert.equal(first, second);
  assert.equal(first.length, 64);
  assert.equal(first.includes("2505550123"), false);
  assert.throws(() => phoneRegistryKey("555-0123"), AccountSecurityError);
});
