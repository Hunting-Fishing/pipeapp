"use strict";

const {applicationDefault, getApps, initializeApp} =
  require("firebase-admin/app");
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
      "Usage: node scripts/activate_pending_dispatch_providers.js " +
      "--project <project-id> [--apply] " +
      "[--confirm-production-project <project-id>]",
  );
  process.exitCode = 2;
}

async function activateProvider(db, snapshot) {
  return db.runTransaction(async (transaction) => {
    const current = await transaction.get(snapshot.ref);
    if (!current.exists || current.data().status !== "pending_review") {
      return false;
    }
    const providerUid = current.id;
    const revision = Number(current.data().reviewRevision || 1);
    transaction.update(current.ref, {
      status: "active",
      availableForHire: true,
      providerReviewVersion: 1,
      activationMode: "automatic_migration",
      activatedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      reviewedAt: FieldValue.delete(),
      reviewedByUid: FieldValue.delete(),
      reviewReason: FieldValue.delete(),
    });
    transaction.set(
        db.collection("dispatch_provider_review_events")
            .doc(`${providerUid}-${revision}-automatic-migration`),
        {
          providerUid,
          revision,
          event: "automatically_activated",
          status: "active",
          activationMode: "automatic_migration",
          actorUid: "operator-script",
          createdAt: FieldValue.serverTimestamp(),
        },
    );
    transaction.set(
        db.collection("users").doc(providerUid).collection("notifications")
            .doc(`dispatch-provider-automatic-activation-${revision}`),
        {
          recipientUid: providerUid,
          type: "dispatch_provider_activated",
          title: "Your Dispatch account is active",
          message: "Your carrier and pilot-truck profile can accept work now.",
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        },
    );
    return true;
  });
}

async function main() {
  const args = argumentsMap(process.argv);
  const projectId = String(args.project || "").trim();
  if (!projectId) {
    usage("Project is required.");
    return;
  }
  if (args.apply === true && projectId === "flutter-flow-pipe" &&
      String(args["confirm-production-project"] || "") !== projectId) {
    throw new Error(
        "Production changes require " +
        "--confirm-production-project flutter-flow-pipe.",
    );
  }
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId});
  }
  const db = getFirestore();
  const pending = await db.collection("dispatch_carriers")
      .where("status", "==", "pending_review")
      .get();
  const result = {
    projectId,
    mode: args.apply === true ? "apply" : "dry-run",
    pending: pending.size,
    activated: 0,
    skipped: 0,
  };
  if (args.apply === true) {
    for (const provider of pending.docs) {
      if (await activateProvider(db, provider)) result.activated += 1;
      else result.skipped += 1;
    }
  }
  console.log(JSON.stringify(result, null, 2));
  if (args.apply !== true) {
    console.log(
        "Dry run only. Re-run with --apply and production confirmation " +
        "to activate these accounts.",
    );
  }
}

main().catch((error) => {
  console.error(error && error.message || error);
  process.exitCode = 1;
});
