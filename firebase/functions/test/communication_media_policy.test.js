"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  CommunicationPolicyError,
  validateUploadInput,
} = require("../communication_command_policy");

test("chat attachments accept MP4 video up to 25 MB", () => {
  const result = validateUploadInput({
    purpose: "chat_attachment",
    contentType: "video/mp4",
    sizeBytes: 20 * 1024 * 1024,
    originalName: "yard-walkaround.mp4",
    conversationId: "conversation-1",
  });
  assert.equal(result.contentType, "video/mp4");
  assert.equal(result.sizeBytes, 20 * 1024 * 1024);
});

test("chat images retain the smaller 15 MB safety limit", () => {
  assert.throws(
      () => validateUploadInput({
        purpose: "chat_attachment",
        contentType: "image/jpeg",
        sizeBytes: 16 * 1024 * 1024,
        originalName: "too-large.jpg",
        conversationId: "conversation-1",
      }),
      (error) => error instanceof CommunicationPolicyError &&
        error.code === "invalid-argument",
  );
});

test("chat video rejects files larger than 25 MB", () => {
  assert.throws(
      () => validateUploadInput({
        purpose: "chat_attachment",
        contentType: "video/mp4",
        sizeBytes: 26 * 1024 * 1024,
        originalName: "too-large.mp4",
        conversationId: "conversation-1",
      }),
      (error) => error instanceof CommunicationPolicyError &&
        error.code === "invalid-argument",
  );
});
