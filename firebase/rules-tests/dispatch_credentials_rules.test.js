"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {getBytes, ref, uploadBytes} = require("firebase/storage");

const projectId = "demo-pipe-buyer-dispatch-credential-rules";
let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "firestore.rules"),
          "utf8",
      ),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "storage.rules"),
          "utf8",
      ),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.clearStorage();
});

after(async () => {
  await testEnvironment.cleanup();
});

test("Dispatch credential metadata is owner-only private Firestore data", async () => {
  const ownerDb = testEnvironment.authenticatedContext("provider-1").firestore();
  const strangerDb = testEnvironment.authenticatedContext("provider-2").firestore();
  const privateRef = doc(ownerDb, "business_private", "provider-1");

  await assertSucceeds(setDoc(privateRef, {
    ownerUid: "provider-1",
    memberUids: ["provider-1"],
    dispatchCredentials: {
      general_liability_insurance: {
        type: "general_liability_insurance",
        state: "self_reported_current",
        issuer: "Example Insurer",
        referenceNumber: "PRIVATE-123",
        expiryDate: "2027-05-31",
        notes: "Private provider note",
        documentStoragePath:
            "business_documents/provider-1/dispatch_credential_general_liability_insurance_evidence",
      },
    },
  }, {merge: true}));

  await assertSucceeds(getDoc(privateRef));
  await assertFails(getDoc(doc(
      strangerDb,
      "business_private",
      "provider-1",
  )));
  await assertFails(setDoc(doc(
      strangerDb,
      "business_private",
      "provider-1",
  ), {
    dispatchCredentials: {
      general_liability_insurance: {state: "verified"},
    },
  }, {merge: true}));
});

test("Dispatch credential evidence is private to owner and MFA admin", async () => {
  const ownerStorage = testEnvironment
      .authenticatedContext("provider-1")
      .storage();
  const strangerStorage = testEnvironment
      .authenticatedContext("provider-2")
      .storage();
  const adminStorage = testEnvironment.authenticatedContext("admin", {
    admin: true,
    role: "administrator",
    firebase: {sign_in_second_factor: "phone"},
  }).storage();
  const pathName =
      "business_documents/provider-1/dispatch_credential_general_liability_insurance_evidence";

  await assertSucceeds(uploadBytes(
      ref(ownerStorage, pathName),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));

  await assertSucceeds(getBytes(ref(ownerStorage, pathName)));
  await assertSucceeds(getBytes(ref(adminStorage, pathName)));
  await assertFails(getBytes(ref(strangerStorage, pathName)));
});

test("private business document boundary accepts PDF but rejects arbitrary files", async () => {
  const ownerStorage = testEnvironment
      .authenticatedContext("provider-1")
      .storage();

  await assertSucceeds(uploadBytes(
      ref(
          ownerStorage,
          "business_documents/provider-1/dispatch_credential_operating_authority_evidence.pdf",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "application/pdf"},
  ));

  await assertFails(uploadBytes(
      ref(
          ownerStorage,
          "business_documents/provider-1/dispatch_credential_operating_authority_evidence.exe",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "application/octet-stream"},
  ));
});
