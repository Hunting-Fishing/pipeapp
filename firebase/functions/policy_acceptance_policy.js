"use strict";

const crypto = require("node:crypto");

const REQUIRED_POLICY_IDS = Object.freeze([
  "terms_of_service",
  "privacy_notice",
  "prohibited_items",
  "mapping_location",
  "communications",
]);

const POLICY_TITLES = Object.freeze({
  terms_of_service: "Terms of Service",
  privacy_notice: "Privacy Notice",
  prohibited_items: "Prohibited Items Policy",
  mapping_location: "Mapping and Location Policy",
  communications: "Communications Policy",
});

class PolicyAcceptanceError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PolicyAcceptanceError";
    this.code = code;
  }
}

function boundedText(value, field, minimum, maximum) {
  const normalized = String(value || "").trim();
  if (normalized.length < minimum || normalized.length > maximum) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        `${field} must contain ${minimum}-${maximum} characters.`,
    );
  }
  return normalized;
}

function policyId(value) {
  const normalized = String(value || "").trim();
  if (!REQUIRED_POLICY_IDS.includes(normalized)) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "Select a supported Phase 1 policy.",
    );
  }
  return normalized;
}

function secureDocumentUrl(value) {
  const normalized = boundedText(value, "documentUrl", 12, 1000);
  let parsed;
  try {
    parsed = new URL(normalized);
  } catch (_) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "The policy document URL is invalid.",
    );
  }
  if (parsed.protocol !== "https:") {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "Policy documents must use HTTPS.",
    );
  }
  return parsed.toString();
}

function validatePolicyPublication(data = {}) {
  const id = policyId(data.policyId);
  const version = boundedText(data.version, "version", 3, 40);
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]+$/.test(version)) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "The policy version contains unsupported characters.",
    );
  }
  const contentSha256 = String(data.contentSha256 || "")
      .trim().toLowerCase();
  if (!/^[a-f0-9]{64}$/.test(contentSha256)) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "Provide the reviewed policy document SHA-256 hash.",
    );
  }
  const effectiveAtMillis = Number(data.effectiveAtMillis);
  if (!Number.isSafeInteger(effectiveAtMillis) || effectiveAtMillis <= 0) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "Provide a valid policy effective date.",
    );
  }
  return {
    policyId: id,
    title: POLICY_TITLES[id],
    version,
    summary: boundedText(data.summary, "summary", 20, 500),
    documentUrl: secureDocumentUrl(data.documentUrl),
    contentSha256,
    effectiveAtMillis,
    approvalNote: boundedText(data.approvalNote, "approvalNote", 20, 1000),
  };
}

function validateAcceptanceItems(value) {
  if (!Array.isArray(value) || value.length !== REQUIRED_POLICY_IDS.length) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "Review and accept every current required policy.",
    );
  }
  const accepted = {};
  for (const item of value) {
    if (!item || typeof item !== "object" || Array.isArray(item)) {
      throw new PolicyAcceptanceError(
          "invalid-argument",
          "The policy acceptance payload is invalid.",
      );
    }
    const id = policyId(item.policyId);
    if (accepted[id]) {
      throw new PolicyAcceptanceError(
          "invalid-argument",
          "Each policy may be accepted only once per request.",
      );
    }
    accepted[id] = {
      version: boundedText(item.version, "version", 3, 40),
      contentSha256: String(item.contentSha256 || "").trim().toLowerCase(),
    };
    if (!/^[a-f0-9]{64}$/.test(accepted[id].contentSha256)) {
      throw new PolicyAcceptanceError(
          "invalid-argument",
          "A policy content hash is missing or invalid.",
      );
    }
  }
  if (REQUIRED_POLICY_IDS.some((id) => !accepted[id])) {
    throw new PolicyAcceptanceError(
        "invalid-argument",
        "Review and accept every current required policy.",
    );
  }
  return accepted;
}

function acceptanceFingerprint(items) {
  const normalized = REQUIRED_POLICY_IDS.map((id) =>
    `${id}:${items[id].version}:${items[id].contentSha256}`).join("|");
  return crypto.createHash("sha256").update(normalized).digest("hex");
}

function assertCurrentPolicies(policyDocuments, accepted) {
  const current = {};
  for (const id of REQUIRED_POLICY_IDS) {
    const document = policyDocuments[id];
    if (!document || document.status !== "published" ||
        typeof document.version !== "string" ||
        typeof document.contentSha256 !== "string") {
      throw new PolicyAcceptanceError(
          "failed-precondition",
          "Required policies are not yet published. Try again later.",
      );
    }
    if (accepted[id].version !== document.version ||
        accepted[id].contentSha256 !== document.contentSha256) {
      throw new PolicyAcceptanceError(
          "failed-precondition",
          "A policy changed while you were reviewing it. Reload and review the current version.",
      );
    }
    current[id] = {
      version: document.version,
      contentSha256: document.contentSha256,
    };
  }
  return current;
}

module.exports = {
  POLICY_TITLES,
  REQUIRED_POLICY_IDS,
  PolicyAcceptanceError,
  acceptanceFingerprint,
  assertCurrentPolicies,
  validateAcceptanceItems,
  validatePolicyPublication,
};
