"use strict";

const crypto = require("node:crypto");

class AccountSecurityError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AccountSecurityError";
    this.code = code;
  }
}

function verificationState(token = {}) {
  const email = String(token.email || "").trim().toLowerCase();
  const phoneNumber = String(token.phone_number || "").trim();
  return {
    email,
    emailVerified: token.email_verified === true,
    phoneNumber,
    phoneVerified: /^\+[1-9]\d{6,14}$/.test(phoneNumber),
  };
}

const USER_RESTRICTION_CODES = Object.freeze([
  "restrict_store_products",
  "restrict_marketplace_selling",
  "restrict_messaging_offers",
  "restrict_dispatch",
]);

function assertNotRestrictedFor(request, capabilityCode = "") {
  const token = request && request.auth && request.auth.token || {};
  if (token.restricted === true) {
    throw new AccountSecurityError(
        "permission-denied",
        "This account is currently restricted by a Pipe Buyer Administrator.",
    );
  }
  const code = String(capabilityCode || "").trim();
  if (code && Array.isArray(token.restrictions) && token.restrictions.includes(code)) {
    throw new AccountSecurityError(
        "permission-denied",
        "Your account has been restricted from performing this action by an Administrator.",
    );
  }
}

function requireAuthenticatedIdentity(
    request,
    {
      requireEmail = false,
      requirePhone = false,
      allowUnverified = false,
      allowRestricted = false,
      requiredCapability = "",
    } = {},
) {
  const uid = request && request.auth && request.auth.uid;
  if (!uid) {
    throw new AccountSecurityError("unauthenticated", "Sign in to continue.");
  }
  const token = request.auth.token || {};
  if (!allowRestricted) {
    assertNotRestrictedFor(request, requiredCapability);
  }
  const state = verificationState(token);
  const hasEitherVerified = state.emailVerified === true ||
    state.phoneVerified === true;
  if (!allowUnverified && !hasEitherVerified) {
    throw new AccountSecurityError(
        "failed-precondition",
        "Verify your email address before completing this action.",
    );
  }
  if (requireEmail && !state.emailVerified) {
    throw new AccountSecurityError(
        "failed-precondition",
        "Verify your email address before completing this action.",
    );
  }
  if (requirePhone && !state.phoneVerified) {
    throw new AccountSecurityError(
        "failed-precondition",
        "Verify a mobile phone number in Account > Settings before " +
        "completing this action.",
    );
  }
  return {uid, ...state};
}

function phoneRegistryKey(phoneNumber) {
  const normalized = String(phoneNumber || "").trim();
  if (!/^\+[1-9]\d{6,14}$/.test(normalized)) {
    throw new AccountSecurityError(
        "invalid-argument",
        "The verified phone number is not in a supported international format.",
    );
  }
  return crypto.createHash("sha256").update(normalized).digest("hex");
}

module.exports = {
  AccountSecurityError,
  USER_RESTRICTION_CODES,
  assertNotRestrictedFor,
  phoneRegistryKey,
  requireAuthenticatedIdentity,
  verificationState,
};
