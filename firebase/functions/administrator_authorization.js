"use strict";

class AdministratorAuthorizationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "AdministratorAuthorizationError";
    this.code = code;
  }
}

function administratorClaims(token = {}) {
  const firebase = token.firebase || {};
  return token.admin === true &&
    token.role === "administrator" &&
    typeof firebase.sign_in_second_factor === "string" &&
    firebase.sign_in_second_factor.trim().length > 0;
}

function isAdministrator(request) {
  return administratorClaims(request && request.auth && request.auth.token);
}

function requireAdministrator(request) {
  if (!request || !request.auth) {
    throw new AdministratorAuthorizationError(
        "unauthenticated",
        "Sign in before using administrator tools.",
    );
  }
  if (!isAdministrator(request)) {
    throw new AdministratorAuthorizationError(
        "permission-denied",
        "Administrator access requires an approved role and multi-factor authentication.",
    );
  }
  return request.auth.uid;
}

function enrolledFactorCount(userRecord) {
  const factors = userRecord && userRecord.multiFactor &&
    userRecord.multiFactor.enrolledFactors;
  return Array.isArray(factors) ? factors.length : 0;
}

function validateAdministratorCandidate(userRecord) {
  if (!userRecord || !userRecord.uid) {
    throw new AdministratorAuthorizationError(
        "not-found",
        "The administrator account was not found.",
    );
  }
  if (userRecord.disabled) {
    throw new AdministratorAuthorizationError(
        "failed-precondition",
        "A disabled account cannot receive administrator access.",
    );
  }
  if (userRecord.emailVerified !== true) {
    throw new AdministratorAuthorizationError(
        "failed-precondition",
        "Verify the account email before granting administrator access.",
    );
  }
  if (enrolledFactorCount(userRecord) < 1) {
    throw new AdministratorAuthorizationError(
        "failed-precondition",
        "Enroll a supported Firebase multi-factor method before granting administrator access.",
    );
  }
  return userRecord.uid;
}

function administratorClaimUpdate(existingClaims = {}, enabled) {
  const claims = {...existingClaims};
  if (enabled) {
    claims.admin = true;
    claims.role = "administrator";
  } else {
    delete claims.admin;
    if (claims.role === "administrator") delete claims.role;
  }
  return claims;
}

module.exports = {
  AdministratorAuthorizationError,
  administratorClaimUpdate,
  administratorClaims,
  enrolledFactorCount,
  isAdministrator,
  requireAdministrator,
  validateAdministratorCandidate,
};
