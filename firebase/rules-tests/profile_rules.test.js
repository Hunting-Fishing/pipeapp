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
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  GeoPoint,
  setDoc,
  Timestamp,
} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-profile-rules";
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

test("legacy profile can normalize account type and save mapped community", async () => {
  const uid = "legacy-profile-user";
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", uid), {
      uid,
      display_name: "Legacy Seller",
      profileCompletion: 50,
    });
  });

  const db = testEnvironment.authenticatedContext(uid).firestore();
  const updatedAt = Timestamp.fromDate(new Date("2026-08-06T00:00:00.000Z"));

  await assertSucceeds(setDoc(doc(db, "users", uid), {
    accountType: "personal",
    baseCommunity: "Grande Prairie, Alberta",
    display_name: "Legacy Seller",
    pendingPhoneE164: "+12507194015",
    personalProfileComplete: true,
    preferredContact: "In-app message",
    primaryCommunityLocation: {
      ownerUid: uid,
      exactGeoPoint: new GeoPoint(55.1707, -118.7947),
      fullAddress: "Private street address",
      nearestTown: "Grande Prairie",
      region: "Alberta",
      postalCode: "T8V 0X9",
      country: "Canada",
      accessNotes: "Private notes",
      visibility: "approximate",
      publicName: "Grande Prairie, Alberta",
      updatedAt,
    },
    profileComplete: true,
    profileCompletion: 100,
    profileUpdatedAt: updatedAt,
    sellerBio: "Oilfield marketplace seller and buyer.",
    uid,
  }, {merge: true}));

  await assertSucceeds(setDoc(doc(db, "public_seller_profiles", uid), {
    ownerUid: uid,
    displayName: "Legacy Seller",
    description: "Oilfield marketplace seller and buyer.",
    baseCommunity: "Grande Prairie, Alberta",
    primaryCommunity: {
      locationVisibility: "approximate",
      publicLocationName: "Grande Prairie, Alberta",
      nearestTown: "Grande Prairie",
      region: "Alberta",
      country: "Canada",
      approximateRadiusKm: 10,
      publicGeoPoint: new GeoPoint(55.15, -118.8),
    },
    primaryCommunityGeoPoint: new GeoPoint(55.15, -118.8),
    primaryCommunityTown: "Grande Prairie",
    primaryCommunityRegion: "Alberta",
    primaryCommunityCountry: "Canada",
    updatedAt,
  }, {merge: true}));
});
