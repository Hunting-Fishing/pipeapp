"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  MAXIMUM_ATTACHMENT_BYTES,
  validateDispatchRequestAttachmentReferences,
  validateDispatchRequestUploadInput,
  validateUploadedDispatchAttachment,
} = require("../dispatch_request_attachment_policy");

test("request upload accepts bounded image and PDF files", () => {
  assert.deepEqual(validateDispatchRequestUploadInput({
    jobId: "job-1",
    contentType: "application/pdf",
    sizeBytes: 1024,
    originalName: "BOL.pdf",
  }), {
    jobId: "job-1",
    contentType: "application/pdf",
    sizeBytes: 1024,
    originalName: "BOL.pdf",
  });
  assert.equal(validateDispatchRequestUploadInput({
    jobId: "job-1",
    contentType: "image/jpeg",
    sizeBytes: 4,
  }).contentType, "image/jpeg");
});

test("request upload rejects unsupported types and oversize files", () => {
  assert.throws(
      () => validateDispatchRequestUploadInput({
        jobId: "job-1",
        contentType: "video/mp4",
        sizeBytes: 4,
      }),
      (error) => error && error.code === "invalid-argument",
  );
  assert.throws(
      () => validateDispatchRequestUploadInput({
        jobId: "job-1",
        contentType: "application/pdf",
        sizeBytes: MAXIMUM_ATTACHMENT_BYTES + 1,
      }),
      (error) => error && error.code === "invalid-argument",
  );
});

test("request accepts no more than five attachment references", () => {
  const valid = Array.from({length: 5}, (_, index) => ({
    authorizationId: `upload-${index}`,
    url: `https://firebasestorage.googleapis.com/v0/b/demo/o/file-${index}`,
  }));
  assert.equal(validateDispatchRequestAttachmentReferences(valid).length, 5);
  assert.throws(
      () => validateDispatchRequestAttachmentReferences([...valid, valid[0]]),
      (error) => error && error.code === "invalid-argument",
  );
});

test("uploaded attachment must match owner, purpose, target and URL", () => {
  const expiresAt = {toMillis: () => Date.now() + 60000};
  const storagePath = "dispatch_request_attachments/job-1/buyer/upload-1";
  const encoded = encodeURIComponent(storagePath);
  const url = `https://firebasestorage.googleapis.com/v0/b/demo/o/${encoded}?alt=media`;
  const authorization = {
    ownerUid: "buyer",
    purpose: "dispatch_request_attachment",
    targetId: "job-1",
    status: "uploaded",
    expiresAt,
    downloadUrl: url,
    storagePath,
    contentType: "image/png",
    sizeBytes: 4,
    originalName: "site.png",
  };
  const value = validateUploadedDispatchAttachment(authorization, {
    uid: "buyer",
    jobId: "job-1",
    submittedUrl: url,
    nowMillis: Date.now(),
  });
  assert.equal(value.type, "image");
  assert.equal(value.storagePath, storagePath);

  assert.throws(
      () => validateUploadedDispatchAttachment(authorization, {
        uid: "stranger",
        jobId: "job-1",
        submittedUrl: url,
        nowMillis: Date.now(),
      }),
      (error) => error && error.code === "failed-precondition",
  );
});
