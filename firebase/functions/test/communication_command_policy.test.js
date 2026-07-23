"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  CommunicationPolicyError,
  downloadUrlMatchesStoragePath,
  validateMessageInput,
  validateReportInput,
  validateUploadAuthorization,
  validateUploadInput,
} = require("../communication_command_policy");

test("download URLs are restricted to the authorized Firebase object", () => {
  const storagePath = "chat_attachments/conversation/buyer/upload-1";
  const encoded = encodeURIComponent(storagePath);
  assert.equal(downloadUrlMatchesStoragePath(
      `https://firebasestorage.googleapis.com/v0/b/app/o/${encoded}?alt=media`,
      storagePath,
  ), true);
  assert.equal(downloadUrlMatchesStoragePath(
      `https://attacker.example/v0/b/app/o/${encoded}`,
      storagePath,
  ), false);
  assert.equal(downloadUrlMatchesStoragePath(
      "https://firebasestorage.googleapis.com/v0/b/app/o/another-file",
      storagePath,
  ), false);
});

test("message policy requires text or a server upload authorization", () => {
  assert.deepEqual(validateMessageInput({text: "  Ready for pickup.  "}), {
    text: "Ready for pickup.",
    attachment: null,
  });
  assert.throws(
      () => validateMessageInput({text: ""}),
      (error) => error instanceof CommunicationPolicyError &&
        error.code === "invalid-argument",
  );
  assert.equal(validateMessageInput({
    attachment: {
      authorizationId: "upload-1",
      url: "https://storage.test/file",
      name: "photo.jpg",
    },
  }).attachment.authorizationId, "upload-1");
});

test("upload policy enforces purpose, exact size, and approved MIME types", () => {
  assert.deepEqual(validateUploadInput({
    purpose: "chat_attachment",
    contentType: "image/jpeg",
    sizeBytes: 1024,
    originalName: "pipe.jpg",
    conversationId: "conversation-1",
  }), {
    purpose: "chat_attachment",
    contentType: "image/jpeg",
    sizeBytes: 1024,
    originalName: "pipe.jpg",
    conversationId: "conversation-1",
    reportId: "",
  });
  assert.throws(
      () => validateUploadInput({
        purpose: "report_evidence",
        contentType: "application/pdf",
        sizeBytes: 100,
      }),
      (error) => error.code === "invalid-argument",
  );
  assert.throws(
      () => validateUploadInput({
        purpose: "chat_attachment",
        contentType: "image/jpeg",
        sizeBytes: 16 * 1024 * 1024,
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("reports use approved reasons and no more than five evidence files", () => {
  const report = validateReportInput({
    targetType: "listing",
    reportedUid: "seller-1",
    reason: "fraud_or_scam",
    details: "The payment instructions appear fraudulent.",
    listingId: "listing-1",
    attachments: [{
      authorizationId: "upload-1",
      url: "https://storage.test/evidence",
    }],
  });
  assert.equal(report.reason, "fraud_or_scam");
  assert.equal(report.attachments.length, 1);
  assert.throws(
      () => validateReportInput({
        targetType: "listing",
        reportedUid: "seller-1",
        reason: "invented_reason",
        details: "This description is long enough.",
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("consumption rejects uploads for another user, target, or expiry", () => {
  const now = 1_000_000;
  const authorization = {
    ownerUid: "buyer-1",
    purpose: "chat_attachment",
    targetId: "conversation-1",
    status: "uploaded",
    expiresAt: {toMillis: () => now + 1000},
  };
  assert.doesNotThrow(() => validateUploadAuthorization(authorization, {
    uid: "buyer-1",
    purpose: "chat_attachment",
    targetId: "conversation-1",
    nowMillis: now,
  }));
  assert.throws(
      () => validateUploadAuthorization(authorization, {
        uid: "attacker",
        purpose: "chat_attachment",
        targetId: "conversation-1",
        nowMillis: now,
      }),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => validateUploadAuthorization(authorization, {
        uid: "buyer-1",
        purpose: "chat_attachment",
        targetId: "conversation-1",
        nowMillis: now + 2000,
      }),
      (error) => error.code === "failed-precondition",
  );
});
