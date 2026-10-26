"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {AccountSecurityError} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");

const MAX_LOGO_BYTES = 2 * 1024 * 1024;
const MAX_BASE64_LENGTH = Math.ceil((MAX_LOGO_BYTES * 4) / 3) + 128;

const ALLOWED_LOGO_PURPOSES = Object.freeze(new Set([
  "insurance_provider",
  "business_directory",
  "partner_brand",
]));

class BusinessLogoUploadError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "BusinessLogoUploadError";
    this.code = code;
  }
}

function detectImageFormatFromMagicBytes(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 16) {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Business logo must be a valid PNG, JPG, or WebP image.",
    );
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4E &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0D &&
    buffer[5] === 0x0A &&
    buffer[6] === 0x1A &&
    buffer[7] === 0x0A
  ) {
    return {contentType: "image/png", extension: "png"};
  }

  // JPEG: FF D8 FF
  if (
    buffer[0] === 0xFF &&
    buffer[1] === 0xD8 &&
    buffer[2] === 0xFF
  ) {
    return {contentType: "image/jpeg", extension: "jpg"};
  }

  // WEBP: "RIFF" .... "WEBP"
  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return {contentType: "image/webp", extension: "webp"};
  }

  throw new BusinessLogoUploadError(
      "invalid-argument",
      "Business logo must be a valid PNG, JPG, or WebP image (SVG and non-image files are not supported).",
  );
}

function normalizeLogoUrl(raw, {ErrorClass = null, fieldName = "logoUrl"} = {}) {
  const trimmed = String(raw == null ? "" : raw).trim();
  if (!trimmed) return "";

  const reject = (message) => {
    if (ErrorClass) {
      throw new ErrorClass("invalid-argument", message);
    }
    return "";
  };

  if (trimmed.length > 1000) {
    return reject(`${fieldName} cannot exceed 1000 characters.`);
  }

  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch (_) {
    return reject(`Enter a valid https:// ${fieldName}.`);
  }

  if (parsed.username || parsed.password) {
    return reject(`Enter a valid https:// ${fieldName}.`);
  }

  const host = String(parsed.hostname || "").toLowerCase();
  const isLocalEmulator =
    parsed.protocol === "http:" &&
    (host === "127.0.0.1" || host === "localhost");
  if (parsed.protocol !== "https:" && !isLocalEmulator) {
    return reject(`${fieldName} must use https://.`);
  }

  if (!isLocalEmulator && !host.includes(".")) {
    return reject(`Enter a valid https:// ${fieldName}.`);
  }

  return parsed.toString();
}

function validateBusinessLogoUpload(input) {
  if (!input || typeof input !== "object") {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Business logo image data is required.",
    );
  }

  const rawPurpose = String(
      input.purpose == null ? "business_directory" : input.purpose,
  ).trim().toLowerCase() || "business_directory";
  if (!ALLOWED_LOGO_PURPOSES.has(rawPurpose)) {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Unsupported business logo upload purpose.",
    );
  }

  const rawBase64 = String(input.base64Data == null ? "" : input.base64Data).trim();
  if (!rawBase64) {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Select a PNG, JPG, or WebP logo file to upload.",
    );
  }

  const stripped = rawBase64.replace(/^data:image\/[a-z0-9.+-]+;base64,/iu, "")
      .replace(/\s+/gu, "");
  if (!stripped || stripped.length > MAX_BASE64_LENGTH) {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Business logo must be 2 MB or smaller.",
    );
  }
  if (!/^[A-Za-z0-9+/]+={0,2}$/u.test(stripped)) {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Business logo image encoding is invalid.",
    );
  }

  const buffer = Buffer.from(stripped, "base64");
  if (buffer.length < 16 || buffer.length > MAX_LOGO_BYTES) {
    throw new BusinessLogoUploadError(
        "invalid-argument",
        "Business logo must be between 16 bytes and 2 MB.",
    );
  }

  const detected = detectImageFormatFromMagicBytes(buffer);
  return {
    buffer,
    contentType: detected.contentType,
    extension: detected.extension,
    sizeBytes: buffer.length,
    purpose: rawPurpose,
  };
}

function guestLogoActorKey(request) {
  const rawReq = (request && request.rawRequest) || {};
  const forwarded = rawReq.headers && rawReq.headers["x-forwarded-for"];
  const ipCandidate = Array.isArray(forwarded) ?
    forwarded[0] :
    (typeof forwarded === "string" ? forwarded.split(",")[0] : rawReq.ip);
  const ip = String(ipCandidate || "anonymous").trim();
  const digest = crypto.createHash("sha256")
      .update(`business-logo|${ip}`)
      .digest("hex")
      .slice(0, 24);
  return `guest_logo_${digest}`;
}

function resolveDefaultBucket(admin) {
  try {
    const bucket = admin.storage().bucket();
    if (bucket && bucket.name) return bucket;
  } catch (_) {
    // Fallback when default bucket is not explicitly configured in test/emulator
  }
  const projectId = process.env.GCLOUD_PROJECT || "flutter-flow-pipe";
  return admin.storage().bucket(`${projectId}.firebasestorage.app`);
}

function buildStorageDownloadUrl({bucketName, objectPath, downloadToken}) {
  const encodedBucket = encodeURIComponent(bucketName);
  const encodedPath = encodeURIComponent(objectPath);
  const encodedToken = encodeURIComponent(downloadToken);
  const emulatorHost = String(
      process.env.FIREBASE_STORAGE_EMULATOR_HOST || "",
  ).trim();
  if (emulatorHost) {
    const base = /^https?:\/\//iu.test(emulatorHost) ?
      emulatorHost :
      `http://${emulatorHost}`;
    return `${base}/v0/b/${encodedBucket}/o/${encodedPath}?alt=media&token=${encodedToken}`;
  }
  return `https://firebasestorage.googleapis.com/v0/b/${encodedBucket}/o/${encodedPath}?alt=media&token=${encodedToken}`;
}

function createBusinessLogoUploadCommands(admin) {
  const db = () => admin.firestore();

  const uploadBusinessLogo = async (request) => {
    try {
      const validated = validateBusinessLogoUpload((request && request.data) || {});

      const effectiveRequest = request && request.auth && request.auth.uid ?
        request :
        {
          ...(request || {}),
          auth: {uid: guestLogoActorKey(request)},
        };
      await enforceUserRateLimit({
        db: db(),
        admin,
        request: effectiveRequest,
        scope: "directory",
        limitOverride: 12,
      });

      const ownerSegment = (request && request.auth && request.auth.uid) ?
        String(request.auth.uid).replace(/[^A-Za-z0-9_-]/gu, "") || "public" :
        "public";
      const fileId = crypto.randomUUID().replace(/-/gu, "");
      const downloadToken = crypto.randomUUID();
      const objectPath =
        `business_logos/${ownerSegment}/logo_${fileId}.${validated.extension}`;

      const bucket = resolveDefaultBucket(admin);
      const bucketName = String(
          bucket.name ||
          `${process.env.GCLOUD_PROJECT || "flutter-flow-pipe"}.firebasestorage.app`,
      );
      const file = bucket.file(objectPath);

      await file.save(validated.buffer, {
        resumable: false,
        contentType: validated.contentType,
        metadata: {
          contentType: validated.contentType,
          cacheControl: "public, max-age=31536000, immutable",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
            purpose: validated.purpose,
          },
        },
      });

      const logoUrl = buildStorageDownloadUrl({
        bucketName,
        objectPath,
        downloadToken,
      });

      return {
        logoUrl,
        contentType: validated.contentType,
        sizeBytes: validated.sizeBytes,
        objectPath,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof BusinessLogoUploadError ||
          error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Business logo upload failed", error);
      throw new HttpsError(
          "internal",
          "Business logo upload could not be completed. Please try again.",
      );
    }
  };

  return {
    uploadBusinessLogo,
  };
}

module.exports = {
  ALLOWED_LOGO_PURPOSES,
  BusinessLogoUploadError,
  MAX_LOGO_BYTES,
  buildStorageDownloadUrl,
  createBusinessLogoUploadCommands,
  detectImageFormatFromMagicBytes,
  normalizeLogoUrl,
  validateBusinessLogoUpload,
};
