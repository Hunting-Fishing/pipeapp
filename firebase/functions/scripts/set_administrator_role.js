"use strict";

const {applicationDefault, getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");
const {
  administratorClaimUpdate,
  enrolledFactorCount,
  validateAdministratorCandidate,
} = require("../administrator_authorization");

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
      "Usage: node scripts/set_administrator_role.js " +
      "--project <project-id> (--uid <uid> | --email <email>) " +
      "(--grant | --revoke) [--apply --confirm-uid <uid>] " +
      "[--confirm-production-project <project-id>]",
  );
  process.exitCode = 2;
}

async function main() {
  const args = argumentsMap(process.argv);
  const projectId = String(args.project || "").trim();
  const grant = args.grant === true;
  const revoke = args.revoke === true;
  if (!projectId || (!args.uid && !args.email) || grant === revoke) {
    usage("Project, one user selector, and exactly one action are required.");
    return;
  }
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId});
  }
  const auth = getAuth();
  const firestore = getFirestore();
  const user = args.uid ?
    await auth.getUser(String(args.uid)) :
    await auth.getUserByEmail(String(args.email).trim().toLowerCase());

  if (grant) validateAdministratorCandidate(user);
  const enabled = grant;
  const nextClaims = administratorClaimUpdate(user.customClaims || {}, enabled);
  const action = enabled ? "grant" : "revoke";
  const plan = {
    action,
    projectId,
    uid: user.uid,
    email: user.email || null,
    emailVerified: user.emailVerified,
    enrolledFactorCount: enrolledFactorCount(user),
    resultingClaims: nextClaims,
    mode: args.apply === true ? "apply" : "dry-run",
  };
  console.log(JSON.stringify(plan, null, 2));
  if (args.apply !== true) {
    console.log("Dry run only. Re-run with --apply and --confirm-uid to commit.");
    return;
  }
  if (String(args["confirm-uid"] || "") !== user.uid) {
    throw new Error("--confirm-uid must exactly match the resolved user UID.");
  }
  if (projectId === "flutter-flow-pipe" &&
      String(args["confirm-production-project"] || "") !== projectId) {
    throw new Error(
        "Production changes require --confirm-production-project flutter-flow-pipe.",
    );
  }

  await auth.setCustomUserClaims(user.uid, nextClaims);
  const batch = firestore.batch();
  const role = firestore.collection("administrator_roles").doc(user.uid);
  const audit = firestore.collection("administrator_role_audits").doc();
  batch.set(role, {
    active: enabled,
    role: "administrator",
    mfaRequired: true,
    mfaEnrollmentVerified: enabled,
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: process.env.ADMIN_CHANGE_ACTOR || "operator-script",
  }, {merge: true});
  batch.set(audit, {
    action,
    targetUid: user.uid,
    projectId,
    emailVerified: user.emailVerified,
    enrolledFactorCount: enrolledFactorCount(user),
    actor: process.env.ADMIN_CHANGE_ACTOR || "operator-script",
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  await auth.revokeRefreshTokens(user.uid);
  console.log(
      `Administrator role ${action} completed. Existing sessions were revoked.`,
  );
}

main().catch((error) => {
  console.error(error && error.message || error);
  process.exitCode = 1;
});
