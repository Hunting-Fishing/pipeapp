"use strict";

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
const {
  deleteDoc,
  doc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-trust-rules";
let testEnvironment;

before(async () => {
  const rules = fs.readFileSync(
      path.join(__dirname, "..", "firestore.rules"),
      "utf8",
  );
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {rules, host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

async function seed(callback) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await callback(context.firestore());
  });
}

test("owners cannot grant themselves VIP or membership state on their user document", async () => {
  await seed((db) => setDoc(doc(db, "users", "owner"), {
    uid: "owner",
    accountType: "personal",
    display_name: "Owner",
    userScore: 70,
    accountVerified: false,
  }));
  const db = testEnvironment.authenticatedContext("owner").firestore();
  const ref = doc(db, "users", "owner");

  await assertSucceeds(updateDoc(ref, {display_name: "Renamed"}));
  await assertFails(updateDoc(ref, {vipActive: true}));
  await assertFails(updateDoc(ref, {isVip: true}));
  await assertFails(updateDoc(ref, {membershipTier: "vip"}));
  await assertFails(updateDoc(ref, {subscriptionTier: "gold"}));
  await assertFails(updateDoc(ref, {membership: {tier: "vip"}}));
  await assertFails(updateDoc(ref, {vipExpiresAt: new Date("2030-01-01")}));
});

test("no client can create notifications in any inbox", async () => {
  const attacker = testEnvironment.authenticatedContext("attacker").firestore();
  const victimOwner = testEnvironment.authenticatedContext("victim").firestore();
  const forged = {
    recipientUid: "victim",
    actorUid: "attacker",
    type: "message",
    title: "Your account is locked",
  };
  await assertFails(setDoc(doc(attacker, "users", "victim", "notifications", "n1"), forged));
  await assertFails(setDoc(doc(victimOwner, "users", "victim", "notifications", "n2"), {
    ...forged,
    actorUid: "victim",
  }));
});

for (const [collection, label] of [
  ["public_seller_profiles", "seller"],
  ["public_business_profiles", "business"],
]) {
  test(`${label} public profile owners cannot write server-owned trust fields`, async () => {
    const owner = testEnvironment.authenticatedContext("u1").firestore();
    const stranger = testEnvironment.authenticatedContext("u2").firestore();
    const ref = doc(owner, collection, "u1");

    await assertFails(setDoc(ref, {displayName: "A", reputationScore: 100}));
    await assertFails(setDoc(ref, {displayName: "A", membershipTier: "vip"}));
    await assertSucceeds(setDoc(ref, {displayName: "A"}));
    await assertSucceeds(updateDoc(ref, {displayName: "B"}));
    await assertFails(updateDoc(ref, {membershipTier: "vip"}));
    await assertFails(updateDoc(ref, {reviewAverage: 5, reviewCount: 99}));
    await assertFails(updateDoc(ref, {completedTransactionCount: 500}));
    await assertFails(updateDoc(ref, {verified: true}));
    await assertFails(setDoc(doc(stranger, collection, "u1"), {displayName: "Hijack"}));
    await assertSucceeds(deleteDoc(ref));
  });

  test(`${label} public profile owners can edit around server-written trust fields but not change them`, async () => {
    await seed((db) => setDoc(doc(db, collection, "u1"), {
      displayName: "A",
      membershipTier: "standard",
      reputationStatus: "new",
      completedTransactionCount: 3,
    }));
    const ref = doc(testEnvironment.authenticatedContext("u1").firestore(), collection, "u1");
    await assertSucceeds(updateDoc(ref, {displayName: "Edited"}));
    await assertFails(updateDoc(ref, {membershipTier: "vip"}));
    await assertFails(updateDoc(ref, {completedTransactionCount: 300}));
  });
}

test("location requests are bounded and must target the listing's real seller", async () => {
  await seed((db) => setDoc(doc(db, "public_listings", "listingA"), {
    sellerUid: "seller",
    title: "Casing",
  }));
  const requester = testEnvironment.authenticatedContext("buyer").firestore();
  const valid = () => ({
    listingId: "listingA",
    requesterUid: "buyer",
    sellerUid: "seller",
    note: "Where exactly is the pipe yard?",
    status: "pending",
    createdAt: serverTimestamp(),
  });
  const request = (id, overrides) =>
    setDoc(doc(requester, "location_requests", id), {...valid(), ...overrides});

  await assertSucceeds(request("ok", {}));
  await assertFails(request("wrong-seller", {sellerUid: "someone-else"}));
  await assertFails(request("spoofed-requester", {requesterUid: "not-me"}));
  await assertFails(request("long-note", {note: "x".repeat(501)}));
  await assertFails(request("non-string-note", {note: 42}));
  await assertFails(request("bad-status", {status: "accepted"}));
  await assertFails(request("extra-key", {admin: true}));
  await assertFails(request("missing-listing", {listingId: "does-not-exist"}));

  const sellerDb = testEnvironment.authenticatedContext("seller").firestore();
  await assertFails(setDoc(doc(sellerDb, "location_requests", "self"), {
    ...valid(),
    requesterUid: "seller",
  }));
});
