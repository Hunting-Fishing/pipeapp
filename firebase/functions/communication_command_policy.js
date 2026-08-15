"use strict";

const REPORT_REASONS = new Set([
  "duplicate_listing",
  "reused_photos",
  "fraud_or_scam",
  "hate_or_racist_content",
  "vulgar_or_harassing_content",
  "misleading_information",
  "prohibited_or_unsafe_item",
  "spam",
  "other",
]);

const TARGET_TYPES = new Set(["listing", "message", "offer", "user"]);
const UPLOAD_PURPOSES = Object.freeze({
  chat_attachment: {
    maximumBytes: 15 * 1024 * 1024,
    maximumVideoBytes: 25 * 1024 * 1024,
    contentTypes: new Set([
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
      "video/mp4",
      "video/quicktime",
    ]),
  },
  report_evidence: {
    maximumBytes: 10 * 1024 * 1024,
    contentTypes: new Set(["image/jpeg", "image/png", "image/webp"]),
  },
});

class CommunicationPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CommunicationPolicyError";
    this.code = code;
  }
}

function requiredText(data, fieldName, maximumLength) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > maximumLength) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function optionalText(data, fieldName, maximumLength) {
  const value = String(data && data[fieldName] || "").trim();
  if (value.length > maximumLength) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        `${fieldName} is too long.`,
    );
  }
  return value;
}

function validateMessageInput(data) {
  const text = optionalText(data, "text", 4000);
  const attachment = data && data.attachment;
  if (!text && !attachment) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "Write a message or attach a file before sending.",
    );
  }
  if (attachment != null) {
    if (typeof attachment !== "object" || Array.isArray(attachment)) {
      throw new CommunicationPolicyError(
          "invalid-argument",
          "The message attachment is invalid.",
      );
    }
    requiredText(attachment, "authorizationId", 180);
    requiredText(attachment, "url", 2048);
    optionalText(attachment, "name", 240);
  }
  return {text, attachment: attachment || null};
}

function validateUploadInput(data) {
  const purpose = requiredText(data, "purpose", 40);
  const policy = UPLOAD_PURPOSES[purpose];
  if (!policy) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "This upload purpose is not supported.",
    );
  }
  const contentType = requiredText(data, "contentType", 120).toLowerCase();
  if (!policy.contentTypes.has(contentType)) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "This file type is not supported for the selected upload.",
    );
  }
  const maximumBytes = contentType.startsWith("video/") &&
      policy.maximumVideoBytes ?
    policy.maximumVideoBytes : policy.maximumBytes;
  const sizeBytes = Number(data && data.sizeBytes);
  if (!Number.isInteger(sizeBytes) || sizeBytes < 1 ||
      sizeBytes > maximumBytes) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        `The upload must be between 1 byte and ${maximumBytes} bytes.`,
    );
  }
  return {
    purpose,
    contentType,
    sizeBytes,
    originalName: optionalText(data, "originalName", 240),
    conversationId: optionalText(data, "conversationId", 180),
    reportId: optionalText(data, "reportId", 180),
  };
}

function validateReportInput(data) {
  const targetType = requiredText(data, "targetType", 30);
  const reason = requiredText(data, "reason", 80);
  const details = requiredText(data, "details", 5000);
  const reportedUid = requiredText(data, "reportedUid", 180);
  if (!TARGET_TYPES.has(targetType)) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "The report target is invalid.",
    );
  }
  if (!REPORT_REASONS.has(reason)) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "Select an approved report reason.",
    );
  }
  if (details.length < 10) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "Please provide at least 10 characters explaining the concern.",
    );
  }
  const attachments = data && data.attachments || [];
  if (!Array.isArray(attachments) || attachments.length > 5 ||
      attachments.some((attachment) =>
        !attachment || typeof attachment !== "object" ||
        Array.isArray(attachment) ||
        !String(attachment.authorizationId || "").trim() ||
        !String(attachment.url || "").trim())) {
    throw new CommunicationPolicyError(
        "invalid-argument",
        "Report evidence is invalid or exceeds five attachments.",
    );
  }
  return {
    targetType,
    reason,
    details,
    reportedUid,
    attachments,
    listingId: optionalText(data, "listingId", 180),
    conversationId: optionalText(data, "conversationId", 180),
    messageId: optionalText(data, "messageId", 180),
    offerId: optionalText(data, "offerId", 180),
  };
}

function validateUploadAuthorization(
    authorization,
    {uid, purpose, targetId, nowMillis},
) {
  if (!authorization || authorization.ownerUid !== uid ||
      authorization.purpose !== purpose ||
      authorization.targetId !== targetId ||
      authorization.status !== "uploaded") {
    throw new CommunicationPolicyError(
        "failed-precondition",
        "The attached file is not authorized for this action.",
    );
  }
  const expiry = authorization.expiresAt;
  const expiryMillis = expiry && typeof expiry.toMillis === "function" ?
    expiry.toMillis() : Number(expiry || 0);
  if (!expiryMillis || expiryMillis <= nowMillis) {
    throw new CommunicationPolicyError(
        "failed-precondition",
        "The upload authorization expired. Attach the file again.",
    );
  }
}

function downloadUrlMatchesStoragePath(value, storagePath) {
  try {
    const url = new URL(String(value || ""));
    const approvedHost = url.hostname === "firebasestorage.googleapis.com" ||
      url.hostname === "127.0.0.1" ||
      url.hostname === "localhost" ||
      url.hostname === "::1";
    const marker = "/o/";
    const markerIndex = url.pathname.indexOf(marker);
    if (!approvedHost || markerIndex < 0 ||
        (url.protocol !== "https:" && url.protocol !== "http:")) {
      return false;
    }
    const encodedObject = url.pathname.substring(markerIndex + marker.length);
    return decodeURIComponent(encodedObject) === storagePath;
  } catch (_) {
    return false;
  }
}

module.exports = {
  CommunicationPolicyError,
  REPORT_REASONS,
  TARGET_TYPES,
  UPLOAD_PURPOSES,
  downloadUrlMatchesStoragePath,
  requiredText,
  validateMessageInput,
  validateReportInput,
  validateUploadAuthorization,
  validateUploadInput,
};
