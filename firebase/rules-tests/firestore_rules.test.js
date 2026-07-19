"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  after,
  before,
  beforeEach,
  test,
} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "demo-pipe-buyer-rules";
let testEnvironment;

before(async () => {
  const rules = fs.readFileSync(
      path.join(__dirname, "..", "firestore.rules"),
      "utf8",
  );
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

test("normal users cannot read or write jurisdiction policies", async () => {
  const userDb = testEnvironment
      .authenticatedContext("ordinary-user")
      .firestore();
  const policy = userDb
      .collection("jurisdiction_policies")
      .doc("ca-ab-test");

  await assertFails(policy.get());
  await assertFails(policy.set({status: "active"}));
});

test("admin claims can manage control-plane configuration", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", {admin: true})
      .firestore();
  const policy = adminDb
      .collection("jurisdiction_policies")
      .doc("ca-ab-test");

  await assertSucceeds(policy.set({status: "designOnly"}));
  const snapshot = await assertSucceeds(policy.get());
  assert.equal(snapshot.data().status, "designOnly");
});

test("property listings remain closed even to signed-in clients", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", {admin: true})
      .firestore();
  const listing = adminDb
      .collection("property_listings")
      .doc("not-yet-enabled");

  await assertFails(listing.get());
  await assertFails(listing.set({status: "draft"}));
});

test("property audit events cannot be forged by client admins", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", {admin: true})
      .firestore();
  const event = adminDb
      .collection("property_audit_events")
      .doc("forged-event");

  await assertFails(event.set({action: "approved"}));
});

