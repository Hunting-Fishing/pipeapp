"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, setDoc, Timestamp} = require("firebase/firestore");
const {ref, uploadBytes} = require("firebase/storage");

const projectId = "demo-pipe-buyer-rules";
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
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "conversations", "conversation"), {
      memberUids: ["buyer", "seller"],
      listingId: "listing",
      sellerUid: "seller",
    });
    const expiresAt = Timestamp.fromMillis(Date.now() + 60 * 60 * 1000);
    await setDoc(doc(db, "media_upload_authorizations", "chat-upload"), {
      ownerUid: "buyer",
      purpose: "chat_attachment",
      targetId: "conversation",
      status: "authorized",
      contentType: "image/jpeg",
      sizeBytes: 4,
      expiresAt,
    });
    await setDoc(doc(db, "media_upload_authorizations", "report-upload"), {
      ownerUid: "buyer",
      purpose: "report_evidence",
      targetId: "report-1",
      status: "authorized",
      contentType: "image/png",
      sizeBytes: 4,
      expiresAt,
    });
    await setDoc(doc(db, "media_upload_authorizations", "expired-upload"), {
      ownerUid: "buyer",
      purpose: "chat_attachment",
      targetId: "conversation",
      status: "authorized",
      contentType: "image/jpeg",
      sizeBytes: 4,
      expiresAt: Timestamp.fromMillis(Date.now() - 1000),
    });
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test("chat uploads require an exact live server authorization", async () => {
  const buyerStorage = testEnvironment
      .authenticatedContext("buyer")
      .storage();
  await assertSucceeds(uploadBytes(
      ref(
          buyerStorage,
          "chat_attachments/conversation/buyer/chat-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(buyerStorage, "chat_attachments/conversation/buyer/no-ticket"),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(
          buyerStorage,
          "chat_attachments/conversation/buyer/expired-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
});

test("upload authorization cannot be reused with another size or MIME type", async () => {
  const buyerStorage = testEnvironment
      .authenticatedContext("buyer")
      .storage();
  await assertFails(uploadBytes(
      ref(
          buyerStorage,
          "chat_attachments/conversation/buyer/chat-upload",
      ),
      Uint8Array.from([1, 2, 3]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(
          buyerStorage,
          "chat_attachments/conversation/buyer/chat-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/png"},
  ));
});

test("report evidence authorization is owner and report specific", async () => {
  const buyerStorage = testEnvironment
      .authenticatedContext("buyer")
      .storage();
  const strangerStorage = testEnvironment
      .authenticatedContext("stranger")
      .storage();
  await assertSucceeds(uploadBytes(
      ref(
          buyerStorage,
          "report_evidence/buyer/report-1/report-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/png"},
  ));
  await assertFails(uploadBytes(
      ref(
          strangerStorage,
          "report_evidence/buyer/report-1/report-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/png"},
  ));
  await assertFails(uploadBytes(
      ref(
          buyerStorage,
          "report_evidence/buyer/report-2/report-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/png"},
  ));
});
