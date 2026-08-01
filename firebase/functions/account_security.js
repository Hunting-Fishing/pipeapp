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
    phoneVerified: /^\+[1-9]\d{7,14}$/.test(phoneNumber),
  };
}

function requireAuthenticatedIdentity(
    request,
    {requireEmail = false, requirePhone = false} = {},
) {
  const uid = request && request.auth && request.auth.uid;
  if (!uid) {
    throw new AccountSecurityError("unauthenticated", "Sign in to continue.");
  }
  const state = verificationState(request.auth.token || {});
  const hasEitherVerified = state.emailVerified === true || state.phoneVerified === true;
  if (!hasEitherVerified) {
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
  if (!/^\+[1-9]\d{7,14}$/.test(normalized)) {
    throw new AccountSecurityError(
        "invalid-argument",
        "The verified phone number is not in a supported international format.",
    );
  }
  return crypto.createHash("sha256").update(normalized).digest("hex");
}

module.exports = {
  AccountSecurityError,
  phoneRegistryKey,
  requireAuthenticatedIdentity,
  verificationState,
};
