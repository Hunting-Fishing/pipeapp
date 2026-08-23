"use strict";

/**
 * Operator tooling for publishing reviewed policy documents and controlling
 * policy enforcement.
 *
 * This writes the same documents, publication events, and receipts that the
 * `publishPolicyDocument` callable writes, so the immutable audit trail is
 * preserved. It exists because publishing requires an interactive administrator
 * MFA session that an operator credential cannot produce.
 *
 * The document hash is always computed from the live published URL rather than
 * accepted as an argument. That is the independent verification the policy
 * runbook requires, so it cannot be skipped or mistyped.
 *
 * Every command is a dry run unless --apply is passed. Production requires an
 * explicit --confirm-production-project match.
 *
 * Usage:
 *   node scripts/policy_ops.js status --project <id>
 *
 *   node scripts/policy_ops.js hash --url <https url>
 *
 *   node scripts/policy_ops.js publish --project <id> \
 *     --policy-id privacy_notice --version 1.0.0 \
 *     --url https://www.pipebuyer.com/privacy \
 *     --effective 2026-09-01 \
 *     --summary "<20-500 characters>" \
 *     --approval-note "<20-1000 characters>" \
 *     --actor-uid <approving administrator uid> \
 *     [--apply] [--confirm-production-project <id>]
 *
 *   node scripts/policy_ops.js set-enforcement --project <id> \
 *     --enabled true --actor-uid <uid> [--apply] \
 *     [--confirm-production-project <id>]
 */

const crypto = require("node:crypto");
const {applicationDefault, getApps, initializeApp} =
  require("firebase-admin/app");
const {FieldValue, Timestamp, getFirestore} =
  require("firebase-admin/firestore");
const {
  REQUIRED_POLICY_IDS,
  validatePolicyPublication,
} = require("../policy_acceptance_policy");

const PRODUCTION_PROJECT_ID = "flutter-flow-pipe";

function argumentsMap(values) {
  const parsed = {};
  for (let index = 3; index < values.length; index += 1) {
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

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exitCode = 2;
}

function assertActorUid(value) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    fail(
        "--actor-uid is required. Record the Firebase Auth UID of the " +
        "administrator who approved this action.",
    );
    return false;
  }
  if (normalized.length > 128) {
    fail("--actor-uid is longer than Firebase Auth permits.");
    return false;
  }
  if (normalized.includes("@")) {
    fail(
        "--actor-uid must be a Firebase Auth UID, not an email address.",
    );
    return false;
  }
  if (/^(paste|replace|your|example|todo)[-_ ]/i.test(normalized) ||
      /firebase.*admin.*uid.*here/i.test(normalized) ||
      normalized === "PASTE_FIREBASE_ADMIN_UID_HERE") {
    fail(
        "--actor-uid is still a placeholder. Copy the approving " +
        "administrator's real User UID from Firebase Authentication first.",
    );
    return false;
  }
  return true;
}

function assertProjectGuard(projectId, args, apply) {
  if (!apply) return true;
  if (projectId !== PRODUCTION_PROJECT_ID) return true;
  if (args["confirm-production-project"] === PRODUCTION_PROJECT_ID) return true;
  fail(
      `Refusing to mutate production. Re-run with ` +
      `--confirm-production-project ${PRODUCTION_PROJECT_ID}`,
  );
  return false;
}

function connect(projectId) {
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId});
  }
  return getFirestore();
}

/** Fetches the document and returns its SHA-256 plus fetch metadata. */
async function hashPublishedDocument(url) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    throw new Error(`Not a valid URL: ${url}`);
  }
  if (parsed.protocol !== "https:") {
    throw new Error("The published policy URL must use HTTPS.");
  }
  const response = await fetch(parsed.toString(), {redirect: "follow"});
  if (!response.ok) {
    throw new Error(
        `The policy URL returned HTTP ${response.status}. ` +
        `Publish the document before recording its hash.`,
    );
  }
  const buffer = Buffer.from(await response.arrayBuffer());
  if (buffer.length === 0) {
    throw new Error("The policy URL returned an empty document.");
  }
  return {
    contentSha256: crypto.createHash("sha256").update(buffer).digest("hex"),
    byteLength: buffer.length,
    contentType: response.headers.get("content-type") || "unknown",
    finalUrl: response.url,
  };
}

async function commandHash(args) {
  const url = String(args.url || "").trim();
  if (!url) return fail("--url is required.");
  const result = await hashPublishedDocument(url);
  console.log(`URL          ${result.finalUrl}`);
  console.log(`Content-Type ${result.contentType}`);
  console.log(`Bytes        ${result.byteLength}`);
  console.log(`SHA-256      ${result.contentSha256}`);
}

async function commandStatus(args) {
  const projectId = String(args.project || "").trim();
  if (!projectId) return fail("--project is required.");
  const db = connect(projectId);

  const enforcement = await db.collection("platform_configuration")
      .doc("policy_enforcement").get();
  const enabled = enforcement.exists && enforcement.data().enabled === true;
  console.log(`Project              ${projectId}`);
  console.log(`Policy enforcement   ${enabled ? "ENABLED" : "disabled"}`);
  if (!enabled) {
    console.log(
        "                     (marketplace commands are NOT gated on policy " +
        "acceptance)",
    );
  }
  console.log("");

  const snapshots = await db.getAll(
      ...REQUIRED_POLICY_IDS.map(
          (id) => db.collection("platform_policies").doc(id),
      ),
  );
  for (const snapshot of snapshots) {
    if (!snapshot.exists) {
      console.log(`  [ MISSING   ] ${snapshot.id}`);
      continue;
    }
    const data = snapshot.data();
    if (data.status !== "published") {
      console.log(`  [ ${String(data.status).toUpperCase()} ] ${snapshot.id}`);
      continue;
    }
    console.log(
        `  [ published ] ${snapshot.id}  v${data.version}  ` +
        `rev ${data.revision}  ${data.documentUrl}`,
    );
  }
}

async function commandPublish(args) {
  const projectId = String(args.project || "").trim();
  const apply = args.apply === true;
  const actorUid = String(args["actor-uid"] || "").trim();
  const url = String(args.url || "").trim();
  const effective = String(args.effective || "").trim();

  if (!projectId) return fail("--project is required.");
  if (!assertActorUid(actorUid)) return;
  if (!url) return fail("--url is required.");
  if (!effective) return fail("--effective YYYY-MM-DD is required.");

  const effectiveAtMillis = Date.parse(`${effective}T00:00:00Z`);
  if (!Number.isSafeInteger(effectiveAtMillis)) {
    return fail(`--effective must be YYYY-MM-DD, received "${effective}".`);
  }
  if (!assertProjectGuard(projectId, args, apply)) return;

  console.log(`Fetching ${url} to compute its hash…`);
  const fetched = await hashPublishedDocument(url);
  console.log(`  SHA-256 ${fetched.contentSha256} (${fetched.byteLength} bytes)`);
  console.log("");

  // Reuse the exact validator the callable uses so the operator path can never
  // write a document the callable would have rejected.
  const publication = validatePolicyPublication({
    policyId: args["policy-id"],
    version: args.version,
    summary: args.summary,
    documentUrl: url,
    contentSha256: fetched.contentSha256,
    effectiveAtMillis,
    approvalNote: args["approval-note"],
  });

  const db = connect(projectId);
  const policyRef = db.collection("platform_policies").doc(publication.policyId);
  const current = await policyRef.get();
  const revision = Number(current.data()?.revision || 0) + 1;

  console.log(`Project        ${projectId}`);
  console.log(`Policy         ${publication.policyId} (${publication.title})`);
  console.log(`Version        ${publication.version}`);
  console.log(`Revision       ${revision}`);
  console.log(`Effective      ${new Date(effectiveAtMillis).toISOString()}`);
  console.log(`Approved by    ${actorUid}`);
  console.log(`Summary        ${publication.summary}`);
  console.log("");

  if (!apply) {
    console.log("DRY RUN — nothing was written. Re-run with --apply.");
    return;
  }

  const eventId = `${publication.policyId}-operator-rev${revision}`;
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(
        db.collection("policy_publication_events").doc(eventId),
    );
    if (existing.exists) {
      throw new Error(
          `Revision ${revision} of ${publication.policyId} was already ` +
          `published by this path. Nothing was changed.`,
      );
    }
    transaction.set(policyRef, {
      policyId: publication.policyId,
      title: publication.title,
      version: publication.version,
      summary: publication.summary,
      documentUrl: publication.documentUrl,
      contentSha256: publication.contentSha256,
      effectiveAt: Timestamp.fromMillis(publication.effectiveAtMillis),
      status: "published",
      required: true,
      revision,
      publishedByUid: actorUid,
      publishedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: false});
    transaction.create(
        db.collection("policy_publication_events").doc(eventId),
        {
          policyId: publication.policyId,
          version: publication.version,
          contentSha256: publication.contentSha256,
          documentUrl: publication.documentUrl,
          effectiveAt: Timestamp.fromMillis(publication.effectiveAtMillis),
          approvalNote: publication.approvalNote,
          revision,
          actorUid,
          event: "published",
          createdAt: FieldValue.serverTimestamp(),
        },
    );
  });

  console.log(`Published ${publication.policyId} revision ${revision}.`);
}

async function commandSetEnforcement(args) {
  const projectId = String(args.project || "").trim();
  const apply = args.apply === true;
  const actorUid = String(args["actor-uid"] || "").trim();
  const enabled = String(args.enabled || "").trim().toLowerCase() === "true";

  if (!projectId) return fail("--project is required.");
  if (!assertActorUid(actorUid)) return;
  if (!assertProjectGuard(projectId, args, apply)) return;

  const db = connect(projectId);

  if (enabled) {
    const snapshots = await db.getAll(
        ...REQUIRED_POLICY_IDS.map(
            (id) => db.collection("platform_policies").doc(id),
        ),
    );
    const missing = snapshots
        .filter((s) => !s.exists || s.data().status !== "published")
        .map((s) => s.id);
    if (missing.length > 0) {
      return fail(
          `Refusing to enable enforcement. These required policies are not ` +
          `published: ${missing.join(", ")}. Enabling now would lock every ` +
          `user out of the marketplace.`,
      );
    }
  }

  console.log(`Project      ${projectId}`);
  console.log(`Enforcement  ${enabled ? "ENABLE" : "DISABLE"}`);
  console.log(`Actor        ${actorUid}`);

  if (!apply) {
    console.log("");
    console.log("DRY RUN — nothing was written. Re-run with --apply.");
    return;
  }

  await db.collection("platform_configuration").doc("policy_enforcement").set({
    enabled,
    updatedByUid: actorUid,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  console.log(`Enforcement ${enabled ? "enabled" : "disabled"}.`);
}

async function main() {
  const subcommand = process.argv[2];
  const args = argumentsMap(process.argv);
  switch (subcommand) {
    case "hash": return commandHash(args);
    case "status": return commandStatus(args);
    case "publish": return commandPublish(args);
    case "set-enforcement": return commandSetEnforcement(args);
    default:
      console.error(
          "Usage: node scripts/policy_ops.js " +
          "<status|hash|publish|set-enforcement> [options]",
      );
      console.error("See the header of this file for full examples.");
      process.exitCode = 2;
  }
}

main().catch((error) => {
  console.error(`ERROR: ${error.message}`);
  process.exitCode = 1;
});
