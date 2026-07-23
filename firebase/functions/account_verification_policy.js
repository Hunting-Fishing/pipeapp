"use strict";

class AccountVerificationPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AccountVerificationPolicyError";
    this.code = code;
  }
}

function text(value) {
  return String(value || "").trim();
}

function stringList(value) {
  return Array.isArray(value) ? value.map(text).filter(Boolean) : [];
}

function approvedAccountVerification(user = {}) {
  return user.accountVerified === true &&
    Number(user.accountVerificationReviewVersion || 0) >= 1;
}

function verificationReadiness({
  identity = {},
  user = {},
  sellerProfile = {},
  businessProfile = {},
}) {
  const accountType = user.accountType === "business" ?
    "business" : "personal";
  const displayName = text(
      businessProfile.publicName || sellerProfile.publicName ||
      sellerProfile.displayName || user.displayName,
  );
  const checks = [
    {
      code: "email_ownership",
      label: "Verified email ownership",
      complete: identity.emailVerified === true,
    },
    {
      code: "phone_ownership",
      label: "Verified mobile ownership",
      complete: identity.phoneVerified === true,
    },
    {
      code: "profile_completion",
      label: "Complete profile details",
      complete: Number(user.profileCompletion || 0) >= 100,
    },
    {
      code: "public_identity",
      label: "Public display identity",
      complete: displayName.length >= 2,
    },
    {
      code: "profile_photo",
      label: "Profile photo",
      complete: /^https:\/\//u.test(text(sellerProfile.photoUrl)),
    },
    {
      code: "marketplace_specialties",
      label: "Marketplace specialties",
      complete: stringList(sellerProfile.approvedTagIds).length > 0,
    },
  ];
  if (accountType === "business") {
    checks.push(
        {
          code: "business_description",
          label: "Public business description",
          complete: text(businessProfile.description).length >= 10,
        },
        {
          code: "business_contact",
          label: "Public business contact",
          complete: text(businessProfile.publicEmail).length > 3 &&
            text(businessProfile.publicPhone).length >= 8,
        },
        {
          code: "business_service_area",
          label: "Business service area",
          complete: text(businessProfile.serviceAreaLabel).length >= 2,
        },
    );
  }
  return {
    ready: checks.every((check) => check.complete),
    accountType,
    displayName,
    checks,
  };
}

function requireVerificationReadiness(input) {
  const readiness = verificationReadiness(input);
  if (!readiness.ready) {
    const missing = readiness.checks
        .filter((check) => !check.complete)
        .map((check) => check.label)
        .join(", ");
    throw new AccountVerificationPolicyError(
        "failed-precondition",
        `Complete these verification requirements first: ${missing}.`,
    );
  }
  return readiness;
}

function validateVerificationDecision(data = {}) {
  const decision = text(data.decision).toLowerCase();
  if (!["approved", "changes_requested", "rejected"].includes(decision)) {
    throw new AccountVerificationPolicyError(
        "invalid-argument",
        "Choose approve, request changes, or reject.",
    );
  }
  const reason = text(data.reason);
  if (reason.length < 10 || reason.length > 1000) {
    throw new AccountVerificationPolicyError(
        "invalid-argument",
        "Add a clear review note between 10 and 1,000 characters.",
    );
  }
  return {decision, reason};
}

module.exports = {
  AccountVerificationPolicyError,
  approvedAccountVerification,
  requireVerificationReadiness,
  validateVerificationDecision,
  verificationReadiness,
};
