"use strict";

const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  downloadUrlMatchesStoragePath,
} = require("./communication_command_policy");

const MAXIMUM_ATTACHMENTS = 5;
const MAXIMUM_ATTACHMENT_BYTES = 15 * 1024 * 1024;
const SUPPORTED_ATTACHMENT_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
]);

function requiredId(value, fieldName) {
  const text = String(value || "").trim();
  if (!text || text.length > 180 || text.includes("/")) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return text;
}

function optionalName(value) {
  const name = String(value || "").trim();
  if (name.length > 240) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Attachment name must be 240 characters or fewer.",
    );
  }
  return name;
}

function validateDispatchRequestUploadInput(data) {
  const jobId = requiredId(data && data.jobId, "jobId");
  const contentType = String(data && data.contentType || "")
      .trim().toLowerCase();
  if (!SUPPORTED_ATTACHMENT_TYPES.has(contentType)) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Dispatch request attachments must be JPG, PNG, WebP, or PDF files.",
    );
  }
  const sizeBytes = Number(data && data.sizeBytes);
  if (!Number.isInteger(sizeBytes) || sizeBytes < 1 ||
      sizeBytes > MAXIMUM_ATTACHMENT_BYTES) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Dispatch request attachments must be 15 MB or smaller.",
    );
  }
  return {
    jobId,
    contentType,
    sizeBytes,
    originalName: optionalName(data && data.originalName),
  };
}

function validateDispatchRequestAttachmentReferences(value) {
  if (value == null) return [];
  if (!Array.isArray(value) || value.length > MAXIMUM_ATTACHMENTS) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Attach no more than five files to one Dispatch request.",
    );
  }
  return value.map((raw) => {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      throw new CommandPolicyError(
          "invalid-argument",
          "One or more Dispatch request attachments are invalid.",
      );
    }
    const authorizationId = requiredId(
        raw.authorizationId,
        "attachment authorizationId",
    );
    const url = String(raw.url || "").trim();
    if (!url || url.length > 2048) {
      throw new CommandPolicyError(
          "invalid-argument",
          "One or more Dispatch request attachment URLs are invalid.",
      );
    }
    return {
      authorizationId,
      url,
      name: optionalName(raw.name),
    };
  });
}

function validateUploadedDispatchAttachment(
    authorization,
    {uid, jobId, submittedUrl, nowMillis},
) {
  if (!authorization || authorization.ownerUid !== uid ||
      authorization.purpose !== "dispatch_request_attachment" ||
      authorization.targetId !== jobId ||
      authorization.status !== "uploaded") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch request attachment is not ready to use.",
    );
  }
  const expiry = authorization.expiresAt;
  const expiryMillis = expiry && typeof expiry.toMillis === "function" ?
    expiry.toMillis() : Number(expiry || 0);
  if (!expiryMillis || expiryMillis <= nowMillis) {
    throw new CommandPolicyError(
        "failed-precondition",
        "A Dispatch request attachment expired. Attach the file again.",
    );
  }
  if (authorization.downloadUrl !== submittedUrl ||
      !downloadUrlMatchesStoragePath(
          submittedUrl,
          authorization.storagePath,
      )) {
    throw new CommandPolicyError(
        "permission-denied",
        "A Dispatch request attachment does not match its authorized file.",
    );
  }
  return {
    authorizationId: authorization.id || null,
    type: String(authorization.contentType || "").startsWith("image/") ?
      "image" : "document",
    url: authorization.downloadUrl,
    name: authorization.originalName || "Dispatch attachment",
    storagePath: authorization.storagePath,
    contentType: authorization.contentType,
    sizeBytes: authorization.sizeBytes,
  };
}

module.exports = {
  MAXIMUM_ATTACHMENTS,
  MAXIMUM_ATTACHMENT_BYTES,
  SUPPORTED_ATTACHMENT_TYPES,
  validateDispatchRequestAttachmentReferences,
  validateDispatchRequestUploadInput,
  validateUploadedDispatchAttachment,
};
