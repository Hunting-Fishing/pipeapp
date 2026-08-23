"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  administratorClaimUpdate,
  enrolledFactorCount,
  requireAdministrator,
  validateAdministratorCandidate,
} = require("./administrator_authorization");

const PRIMARY_ADMIN_MANAGER_EMAIL = "jordilwbailey@gmail.com";

function normalizedEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function requireAdministratorManager(request) {
  const uid = requireAdministrator(request);
  const token = request && request.auth && request.auth.token || {};
  const email = normalizedEmail(token.email);
  if (token.email_verified !== true || email !== PRIMARY_ADMIN_MANAGER_EMAIL) {
    throw new AdministratorAuthorizationError(
        "permission-denied",
        "Only the primary Pipe Buyer administrator can change administrator access.",
    );
  }
  return {uid, email};
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      if (error && error.code === "auth/user-not-found") {
        throw new HttpsError(
            "not-found",
            "No Pipe Buyer account was found for that email address.",
        );
      }
      console.error("Administrator role command failed", error);
      throw new HttpsError(
          "internal",
          "Administrator access could not be updated.",
      );
    }
  };
}

function requestedEmail(data) {
  const email = normalizedEmail(data && data.email);
  if (!email || email.length > 320 || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "Enter a valid account email address.");
  }
  return email;
}

function requestedEnabled(data) {
  if (!data || typeof data.enabled !== "boolean") {
    throw new HttpsError(
        "invalid-argument",
        "Administrator access must be explicitly granted or revoked.",
    );
  }
  return data.enabled;
}

function createAdministratorRoleCommands(admin) {
  const auth = admin.auth();
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const listAdministratorRoles = command(async (request) => {
    requireAdministratorManager(request);
    const snapshot = await db.collection("administrator_roles")
        .where("active", "==", true)
        .get();
    const administrators = [];
    for (const role of snapshot.docs) {
      try {
        const user = await auth.getUser(role.id);
        administrators.push({
          uid: user.uid,
          email: normalizedEmail(user.email),
          emailVerified: user.emailVerified === true,
          enrolledFactorCount: enrolledFactorCount(user),
          primaryManager: normalizedEmail(user.email) === PRIMARY_ADMIN_MANAGER_EMAIL,
        });
      } catch (error) {
        if (error && error.code === "auth/user-not-found") {
          administrators.push({
            uid: role.id,
            email: "",
            emailVerified: false,
            enrolledFactorCount: 0,
            primaryManager: false,
            missingAuthAccount: true,
          });
          continue;
        }
        throw error;
      }
    }
    administrators.sort((left, right) => {
      if (left.primaryManager !== right.primaryManager) {
        return left.primaryManager ? -1 : 1;
      }
      return left.email.localeCompare(right.email);
    });
    return {
      primaryManagerEmail: PRIMARY_ADMIN_MANAGER_EMAIL,
      administrators,
    };
  });

  const manageAdministratorRole = command(async (request) => {
    const actor = requireAdministratorManager(request);
    const email = requestedEmail(request.data);
    const enabled = requestedEnabled(request.data);
    const user = await auth.getUserByEmail(email);

    if (!enabled && email === PRIMARY_ADMIN_MANAGER_EMAIL) {
      throw new HttpsError(
          "failed-precondition",
          "The primary administrator cannot remove their own administrator access from the app.",
      );
    }
    if (enabled) validateAdministratorCandidate(user);

    const nextClaims = administratorClaimUpdate(user.customClaims || {}, enabled);
    const action = enabled ? "grant" : "revoke";
    await auth.setCustomUserClaims(user.uid, nextClaims);

    const batch = db.batch();
    const roleReference = db.collection("administrator_roles").doc(user.uid);
    const auditReference = db.collection("administrator_role_audits").doc();
    batch.set(roleReference, {
      active: enabled,
      role: "administrator",
      mfaRequired: true,
      mfaEnrollmentVerified: enabled,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: actor.uid,
    }, {merge: true});
    batch.set(auditReference, {
      action,
      targetUid: user.uid,
      targetEmail: email,
      actorUid: actor.uid,
      actorEmail: actor.email,
      emailVerified: user.emailVerified === true,
      enrolledFactorCount: enrolledFactorCount(user),
      source: "administrator_roster_ui",
      createdAt: FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await auth.revokeRefreshTokens(user.uid);

    return {
      action,
      uid: user.uid,
      email,
      active: enabled,
      signInAgainRequired: true,
    };
  });

  return {
    listAdministratorRoles,
    manageAdministratorRole,
  };
}

module.exports = {
  PRIMARY_ADMIN_MANAGER_EMAIL,
  createAdministratorRoleCommands,
  normalizedEmail,
  requireAdministratorManager,
};
