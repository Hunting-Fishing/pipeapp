"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, Timestamp} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-dispatch-directory-rules";
let testEnvironment;

function featureFlags(dispatch = true) {
  return {
    marketplace: true,
    wantedAds: true,
    offers: true,
    auctions: true,
    dispatch,
    paidFeatures: false,
    regulatedListings: false,
    revision: 1,
    updatedAt: Timestamp.fromDate(new Date("2026-08-19T12:00:00.000Z")),
    updatedByUid: "system",
  };
}

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "platform_configuration", "phase1_features"), featureFlags(true));
    await setDoc(doc(db, "dispatch_directory_entries", "provider-1"), {
      schemaVersion: 1,
      companyId: "provider-1",
      operatingName: "Northline Heavy Haul",
      serviceCodes: ["transport.heavy_haul"],
      availability: "available_now",
      verified: false,
    });
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test("signed-in Dispatch user can read server-owned directory entries", async () => {
  const buyerDb = testEnvironment.authenticatedContext("buyer").firestore();
  await assertSucceeds(getDoc(doc(buyerDb, "dispatch_directory_entries", "provider-1")));
});

test("signed-out access is blocked by the existing mandatory Pipe Buyer sign-in boundary", async () => {
  const publicDb = testEnvironment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(publicDb, "dispatch_directory_entries", "provider-1")));
});

test("provider and administrator clients cannot forge or edit directory projection documents", async () => {
  const providerDb = testEnvironment.authenticatedContext("provider-1").firestore();
  const adminDb = testEnvironment.authenticatedContext("admin", {
    admin: true,
    role: "administrator",
    firebase: {sign_in_second_factor: "phone"},
  }).firestore();

  await assertFails(setDoc(doc(providerDb, "dispatch_directory_entries", "provider-1"), {
    operatingName: "Forged Provider",
    verified: true,
  }, {merge: true}));
  await assertFails(setDoc(doc(adminDb, "dispatch_directory_entries", "provider-1"), {
    verified: true,
  }, {merge: true}));
});

test("Directory reads close when the Dispatch feature gate is disabled", async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "platform_configuration", "phase1_features"),
      featureFlags(false),
    );
  });
  const buyerDb = testEnvironment.authenticatedContext("buyer").firestore();
  await assertFails(getDoc(doc(buyerDb, "dispatch_directory_entries", "provider-1")));
});
