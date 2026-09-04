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
  doc,
  getDoc,
  setDoc,
  Timestamp,
} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-r4-draft-rules";
let testEnvironment;

const administratorClaims = {
  admin: true,
  role: "administrator",
  firebase: {sign_in_second_factor: "phone"},
};

function phase1Features() {
  return {
    marketplace: true,
    wantedAds: true,
    offers: true,
    auctions: true,
    dispatch: true,
    paidFeatures: false,
    regulatedListings: false,
    revision: 1,
    updatedAt: Timestamp.fromDate(new Date("2026-09-03T00:00:00.000Z")),
    updatedByUid: "system",
  };
}

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
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
        doc(db, "platform_configuration", "phase1_features"),
        phase1Features(),
    );
    await setDoc(doc(db, "dispatch_jobs", "field-draft"), {
      createdByUid: "buyer",
      status: "draft",
      requestPath: "field_service",
      title: "Private field-service request",
    });
    await setDoc(doc(
        db,
        "dispatch_jobs",
        "field-draft",
        "revisions",
        "1",
    ), {
      createdByUid: "buyer",
      status: "draft",
      requestPath: "field_service",
      revision: 1,
    });
    await setDoc(doc(db, "dispatch_jobs", "freight-open"), {
      createdByUid: "buyer",
      status: "open",
      requestPath: "freight_route",
      title: "Open freight request",
    });
    await setDoc(doc(
        db,
        "dispatch_jobs",
        "freight-open",
        "revisions",
        "1",
    ), {
      createdByUid: "buyer",
      status: "open",
      requestPath: "freight_route",
      revision: 1,
    });
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test(
    "draft field-service jobs and history are owner/admin private while open freight remains readable",
    async () => {
      const buyerDb = testEnvironment.authenticatedContext("buyer").firestore();
      const strangerDb = testEnvironment
          .authenticatedContext("stranger")
          .firestore();
      const adminDb = testEnvironment
          .authenticatedContext("admin", administratorClaims)
          .firestore();

      await assertSucceeds(getDoc(doc(buyerDb, "dispatch_jobs", "field-draft")));
      await assertSucceeds(getDoc(doc(
          buyerDb,
          "dispatch_jobs",
          "field-draft",
          "revisions",
          "1",
      )));
      await assertSucceeds(getDoc(doc(adminDb, "dispatch_jobs", "field-draft")));
      await assertSucceeds(getDoc(doc(
          adminDb,
          "dispatch_jobs",
          "field-draft",
          "revisions",
          "1",
      )));

      await assertFails(getDoc(doc(strangerDb, "dispatch_jobs", "field-draft")));
      await assertFails(getDoc(doc(
          strangerDb,
          "dispatch_jobs",
          "field-draft",
          "revisions",
          "1",
      )));

      await assertSucceeds(getDoc(doc(
          strangerDb,
          "dispatch_jobs",
          "freight-open",
      )));
      await assertSucceeds(getDoc(doc(
          strangerDb,
          "dispatch_jobs",
          "freight-open",
          "revisions",
          "1",
      )));
    },
);
