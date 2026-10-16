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
  deleteField,
  doc,
  GeoPoint,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-trust-rules";
const firestorePort = Number(process.env.FIRESTORE_EMULATOR_PORT || 8080);
let testEnvironment;

before(async () => {
  const rules = fs.readFileSync(
      path.join(__dirname, "..", "firestore.rules"),
      "utf8",
  );
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {rules, host: "127.0.0.1", port: firestorePort},
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
    await assertFails(setDoc(ref, {displayName: "A", publicPhone: "+1 555 0100"}));
    await assertFails(setDoc(ref, {displayName: "A", publicEmail: "seller@example.com"}));
    await assertFails(setDoc(ref, {displayName: "A", website: "example.com"}));
    await assertFails(setDoc(ref, {displayName: "A", telegram: "@direct_deals"}));
    await assertFails(setDoc(ref, {displayName: "A", directContact: "hidden"}));
    await assertFails(setDoc(ref, {displayName: "seller@example.com"}));
    await assertFails(setDoc(ref, {
      displayName: "A",
      description: "Call +1 (555) 555-0100",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      description: "See https://example.com for pricing",
    }));
    await assertFails(setDoc(ref, {
      displayName: "sales at example dot com",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      description: "See example dot com for pricing",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      sellerBio: "555-1234",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      photoUrl: "https://example.com/avatar.png",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      approvedTagIds: ["sales at example dot com"],
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      serviceCountryCodes: ["example dot com"],
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      dispatchProfile: {website: "example.com"},
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      dispatchProfile: {description: "Telegram @direct_deals"},
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      dispatchProfile: {operatingName: "A", telegram: "@direct_deals"},
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      dispatchProfile: {
        operatingName: "A",
        serviceCodes: ["sales at example dot com"],
      },
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      dispatchProfile: {
        operatingName: "A",
        serviceArea: {
          mode: "places",
          centerLabel: "Grande Prairie",
          places: [{name: "example dot com"}],
        },
      },
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      primaryCommunity: {
        publicLocationName: "Grande Prairie, Alberta",
        directContact: "seller at example dot com",
      },
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      primaryCommunityGeoPoint: "sales at example dot com",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      updatedAt: "555-1234",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      visualSandbox: "example dot com",
    }));
    await assertFails(setDoc(ref, {
      displayName: "A",
      schemaVersion: "sales at example dot com",
    }));
    await assertSucceeds(setDoc(ref, {
      displayName: "A",
      description: "CAT-320-2026 excavator with API 5CT casing",
      photoUrl: "https://firebasestorage.googleapis.com/v0/b/" +
        "flutter-flow-pipe.firebasestorage.app/o/" +
        "profile_media%2Fuser123%2Favatar_1792156800000.png?alt=media",
    }));
    await assertSucceeds(updateDoc(ref, {
      dispatchProfile: {
        schemaVersion: 2,
        operatingName: "CAT-320-2026 Transport",
        businessType: "corporation",
        description: "API 5CT pipe and heavy-equipment transport",
        serviceCodes: ["transport_pipe_hauling"],
        serviceAreaLabel: "Grande Prairie, Alberta",
        homeLocation: {
          label: "Grande Prairie, Alberta",
          point: new GeoPoint(55.17, -118.8),
          precision: "approximate_1km",
          source: "service_area_center",
        },
        availability: "available_now",
        emergencyCallout: true,
        remoteSiteCapable: true,
        profileCompleteness: 100,
      },
    }));
    await assertSucceeds(updateDoc(ref, {
      primaryCommunityGeoPoint: new GeoPoint(55.17, -118.8),
      dispatchProfileUpdatedAt: serverTimestamp(),
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      contactPrivacyMigratedAt: serverTimestamp(),
      visualSandbox: false,
      schemaVersion: 2,
    }));
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

  test(`${label} public profile owners can remove legacy contact keys`, async () => {
    await seed((db) => setDoc(doc(db, collection, "u1"), {
      displayName: "Legacy",
      publicPhone: "+1 555 0100",
      publicEmail: "seller@example.com",
      website: "example.com",
      dispatchProfile: {website: "dispatch.example.com"},
    }));
    const ref = doc(
        testEnvironment.authenticatedContext("u1").firestore(),
        collection,
        "u1",
    );
    await assertSucceeds(updateDoc(ref, {
      displayName: "Private",
      publicPhone: deleteField(),
      publicEmail: deleteField(),
      website: deleteField(),
      "dispatchProfile.website": deleteField(),
    }));
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
    note: "",
    status: "pending",
    createdAt: serverTimestamp(),
  });
  const request = (id, overrides) =>
    setDoc(doc(requester, "location_requests", id), {...valid(), ...overrides});

  await assertSucceeds(request("ok", {}));
  await assertFails(request("free-form-note", {
    note: "Call me with the exact yard location",
  }));
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
