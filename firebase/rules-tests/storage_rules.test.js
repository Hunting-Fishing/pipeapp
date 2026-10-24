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
const {deleteObject, getBytes, ref, uploadBytes} = require("firebase/storage");

const projectId = "demo-pipe-buyer-rules";
let testEnvironment;

before(async () => {
  const [firestoreHost, firestorePort] = String(
      process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080",
  ).split(":");
  const [storageHost, storagePort] = String(
      process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199",
  ).split(":");
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "firestore.rules"),
          "utf8",
      ),
      host: firestoreHost,
      port: Number(firestorePort),
    },
    storage: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "storage.rules"),
          "utf8",
      ),
      host: storageHost,
      port: Number(storagePort),
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
    await setDoc(doc(db, "media_upload_authorizations", "dispatch-upload"), {
      ownerUid: "buyer",
      purpose: "dispatch_request_attachment",
      targetId: "request-1",
      status: "authorized",
      contentType: "application/pdf",
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
    await setDoc(doc(db, "marketplace_listing_drafts", "listing-draft"), {
      sellerUid: "buyer",
      status: "awaiting_media",
      expectedPhotoCount: 1,
      expectsVideo: false,
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

test("listing uploads require an owned open draft and bounded file type", async () => {
  const buyerStorage = testEnvironment
      .authenticatedContext("buyer")
      .storage();
  const sellerStorage = testEnvironment
      .authenticatedContext("seller")
      .storage();
  const photo = ref(
      buyerStorage,
      "listing_media/buyer/listing-draft/photo_1.jpg",
  );

  await assertSucceeds(uploadBytes(
      photo,
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(buyerStorage, "listing_media/buyer/no-draft/photo_1.jpg"),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(sellerStorage, "listing_media/buyer/listing-draft/photo_1.jpg"),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(buyerStorage, "listing_media/buyer/listing-draft/photo_13.jpg"),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/jpeg"},
  ));
  await assertFails(uploadBytes(
      ref(buyerStorage, "listing_media/buyer/listing-draft/photo_2.pdf"),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "application/pdf"},
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

test("Dispatch request attachments require exact private authorization", async () => {
  const buyerStorage = testEnvironment.authenticatedContext("buyer").storage();
  const strangerStorage =
      testEnvironment.authenticatedContext("stranger").storage();
  const attachmentPath =
      "dispatch_request_attachments/request-1/buyer/dispatch-upload";

  await assertSucceeds(uploadBytes(
      ref(buyerStorage, attachmentPath),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "application/pdf"},
  ));
  await assertSucceeds(getBytes(ref(buyerStorage, attachmentPath)));
  await assertFails(getBytes(ref(strangerStorage, attachmentPath)));
  await assertFails(uploadBytes(
      ref(
          buyerStorage,
          "dispatch_request_attachments/request-2/buyer/dispatch-upload",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "application/pdf"},
  ));
  await assertFails(uploadBytes(
      ref(
          buyerStorage,
          "dispatch_request_attachments/request-1/buyer/no-ticket",
      ),
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "application/pdf"},
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

test("report evidence admin access requires approved MFA claims", async () => {
  const buyerStorage = testEnvironment.authenticatedContext("buyer").storage();
  const evidence = ref(
      buyerStorage,
      "report_evidence/buyer/report-1/report-upload",
  );
  await assertSucceeds(uploadBytes(
      evidence,
      Uint8Array.from([1, 2, 3, 4]),
      {contentType: "image/png"},
  ));

  const approvedAdmin = testEnvironment.authenticatedContext("admin", {
    admin: true,
    role: "administrator",
    firebase: {sign_in_second_factor: "phone"},
  }).storage();
  const emailOnly = testEnvironment.authenticatedContext("email-only", {
    email: "jordilwbailey@gmail.com",
    email_verified: true,
  }).storage();
  const adminWithoutMfa = testEnvironment.authenticatedContext(
      "admin-without-mfa",
      {admin: true, role: "administrator"},
  ).storage();

  await assertSucceeds(getBytes(ref(
      approvedAdmin,
      "report_evidence/buyer/report-1/report-upload",
  )));
  await assertFails(getBytes(ref(
      emailOnly,
      "report_evidence/buyer/report-1/report-upload",
  )));
  await assertFails(getBytes(ref(
      adminWithoutMfa,
      "report_evidence/buyer/report-1/report-upload",
  )));
  await assertSucceeds(deleteObject(ref(
      approvedAdmin,
      "report_evidence/buyer/report-1/report-upload",
  )));
});

test("listing videos accept every phone container up to 100 MB and nothing else", async () => {
  const buyerStorage = testEnvironment
      .authenticatedContext("buyer")
      .storage();
  const video = (name) => ref(
      buyerStorage,
      `listing_media/buyer/listing-draft/${name}`,
  );
  const tiny = () => Uint8Array.from([1, 2, 3, 4]);

  for (const [name, contentType] of [
    ["video.mp4", "video/mp4"],
    ["video.mov", "video/quicktime"],
    ["video.m4v", "video/x-m4v"],
    ["video.3gp", "video/3gpp"],
    ["video.3g2", "video/3gpp2"],
    ["video.webm", "video/webm"],
  ]) {
    await assertSucceeds(uploadBytes(video(name), tiny(), {contentType}));
  }

  // Above the former 25 MB cap, still within the 100 MB limit.
  await assertSucceeds(uploadBytes(
      video("video.mp4"),
      new Uint8Array(26 * 1024 * 1024),
      {contentType: "video/mp4"},
  ));
  await assertFails(uploadBytes(
      video("video.mp4"),
      new Uint8Array(101 * 1024 * 1024),
      {contentType: "video/mp4"},
  ));

  await assertFails(uploadBytes(video("video.avi"), tiny(), {contentType: "video/x-msvideo"}));
  await assertFails(uploadBytes(video("video.mkv"), tiny(), {contentType: "video/x-matroska"}));
  await assertFails(uploadBytes(video("video.mp4"), tiny(), {contentType: "image/jpeg"}));
});

test("listing photos are stored only as JPEG or PNG (the app converts other formats first)", async () => {
  const buyerStorage = testEnvironment
      .authenticatedContext("buyer")
      .storage();
  const photo = (name) => ref(
      buyerStorage,
      `listing_media/buyer/listing-draft/${name}`,
  );
  const tiny = () => Uint8Array.from([1, 2, 3, 4]);

  await assertSucceeds(uploadBytes(photo("photo_2.jpg"), tiny(), {contentType: "image/jpeg"}));
  await assertSucceeds(uploadBytes(photo("photo_3.png"), tiny(), {contentType: "image/png"}));
  await assertFails(uploadBytes(photo("photo_4.heic"), tiny(), {contentType: "image/heic"}));
  await assertFails(uploadBytes(photo("photo_4.webp"), tiny(), {contentType: "image/webp"}));
  await assertFails(uploadBytes(photo("photo_4.gif"), tiny(), {contentType: "image/gif"}));
});
