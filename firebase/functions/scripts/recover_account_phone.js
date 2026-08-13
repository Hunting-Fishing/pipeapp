"use strict";

const {applicationDefault, getApps, initializeApp} =
  require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

function argumentsMap(values) {
  const parsed = {};
  for (let index = 2; index < values.length; index += 1) {
    const key = values[index];
    if (!key.startsWith("--")) continue;
    const next = values[index + 1];
    if (!next || next.startsWith("--")) {
      parsed[key.slice(2)] = true;
    } else {
      parsed[key.slice(2)] = next;
      index += 1;
    }
  }
  return parsed;
}

function usage(message) {
  if (message) console.error(message);
  console.error(
      "Usage: node scripts/recover_account_phone.js " +
      "--project <project-id> (--uid <uid> | --email <email>) " +
      "[--apply --confirm-uid <uid>] " +
      "[--confirm-production-project <project-id>]",
  );
  process.exitCode = 2;
}

async function main() {
  const args = argumentsMap(process.argv);
  const projectId = String(args.project || "").trim();
  if (!projectId || Boolean(args.uid) === Boolean(args.email)) {
    usage("Project and exactly one user selector are required.");
    return;
  }
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId});
  }
  const auth = getAuth();
  const db = getFirestore();
  const user = args.uid ?
    await auth.getUser(String(args.uid)) :
    await auth.getUserByEmail(String(args.email).trim().toLowerCase());
  const userRef = db.collection("users").doc(user.uid);
  const [profile, role] = await Promise.all([
    userRef.get(),
    db.collection("administrator_roles").doc(user.uid).get(),
  ]);
  const registryKey = profile.exists ?
    String(profile.data().phoneRegistryKey || "") : "";
  const registry = registryKey ?
    await db.collection("account_phone_registry").doc(registryKey).get() : null;
  const factors = user.multiFactor && user.multiFactor.enrolledFactors || [];
  const nonPhoneFactors = factors.filter(
      (factor) => factor.factorId !== "phone",
  );
  const phoneProviders = user.providerData
      .filter((provider) => provider.providerId === "phone").length;
  const plan = {
    projectId,
    uid: user.uid,
    email: user.email || null,
    mode: args.apply === true ? "apply" : "dry-run",
    phoneAttached: Boolean(user.phoneNumber),
    phoneProviderCount: phoneProviders,
    enrolledFactorCount: factors.length,
    nonPhoneFactorCount: nonPhoneFactors.length,
    registryPresent: Boolean(registry && registry.exists),
    registryOwnedByTarget: Boolean(
        registry && registry.exists && registry.data().uid === user.uid,
    ),
    administratorRoleActive: Boolean(role.exists && role.data().active === true),
    claimsPreserved: user.customClaims || {},
  };
  console.log(JSON.stringify(plan, null, 2));
  if (args.apply !== true) {
    console.log("Dry run only. Re-run with exact UID confirmation to commit.");
    return;
  }
  if (String(args["confirm-uid"] || "") !== user.uid) {
    throw new Error("--confirm-uid must exactly match the resolved user UID.");
  }
  if (projectId === "flutter-flow-pipe" &&
      String(args["confirm-production-project"] || "") !== projectId) {
    throw new Error(
        "Production changes require " +
        "--confirm-production-project flutter-flow-pipe.",
    );
  }
  if (registry && registry.exists && registry.data().uid !== user.uid) {
    throw new Error("Phone registry ownership does not match the target UID.");
  }
  if (nonPhoneFactors.length > 0) {
    throw new Error(
        "Recovery refused because a non-phone MFA factor is enrolled.",
    );
  }

  await auth.updateUser(user.uid, {
    phoneNumber: null,
    multiFactor: {enrolledFactors: null},
  });
  await db.runTransaction(async (transaction) => {
    const freshRegistry = registryKey ?
      await transaction.get(
          db.collection("account_phone_registry").doc(registryKey),
      ) : null;
    if (freshRegistry && freshRegistry.exists &&
        freshRegistry.data().uid !== user.uid) {
      throw new Error("Phone registry ownership changed during recovery.");
    }
    transaction.set(userRef, {
      phone_number: FieldValue.delete(),
      pendingPhoneE164: FieldValue.delete(),
      verifiedPhoneE164: FieldValue.delete(),
      phoneE164: FieldValue.delete(),
      phoneRegistryKey: FieldValue.delete(),
      phoneVerifiedAt: FieldValue.delete(),
      phoneOwnershipVerified: false,
      verificationSyncedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (freshRegistry && freshRegistry.exists) {
      transaction.delete(freshRegistry.ref);
    }
    if (role.exists && role.data().active === true) {
      transaction.set(role.ref, {
        mfaEnrollmentVerified: false,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: process.env.ADMIN_CHANGE_ACTOR || "operator-script",
      }, {merge: true});
    }
    transaction.set(db.collection("account_identity_recovery_audits").doc(), {
      action: "remove_phone_and_phone_mfa",
      targetUid: user.uid,
      projectId,
      removedPrimaryPhone: Boolean(user.phoneNumber),
      removedPhoneProviders: phoneProviders,
      removedEnrolledFactors: factors.length,
      administratorRoleActive: Boolean(
          role.exists && role.data().active === true,
      ),
      actor: process.env.ADMIN_CHANGE_ACTOR || "operator-script",
      createdAt: FieldValue.serverTimestamp(),
    });
  });
  await auth.revokeRefreshTokens(user.uid);
  const recovered = await auth.getUser(user.uid);
  const recoveredFactors = recovered.multiFactor &&
    recovered.multiFactor.enrolledFactors || [];
  const claimsPreserved = JSON.stringify(recovered.customClaims || {}) ===
    JSON.stringify(user.customClaims || {});
  if (recovered.phoneNumber || recoveredFactors.length !== 0 ||
      !claimsPreserved) {
    throw new Error("Post-recovery Auth verification failed.");
  }
  console.log(JSON.stringify({
    completed: true,
    uid: user.uid,
    phoneAttached: false,
    enrolledFactorCount: 0,
    claimsPreserved,
    sessionsRevoked: true,
  }, null, 2));
}

main().catch((error) => {
  console.error(error && error.message || error);
  process.exitCode = 1;
});
