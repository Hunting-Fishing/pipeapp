"use strict";

// One-time / repair backfill for the server-owned public trust projection.
//
// Dry run is the default. Nothing is written unless --apply is passed.
//   node scripts/backfill_public_trust_projection.js --project <projectId>
//   node scripts/backfill_public_trust_projection.js --project <projectId> --apply
//
// Run it right after deploying the firestore.rules guard so any trust fields a
// client wrote earlier (fake VIP tier, reputation, reviews) are removed.

const {applicationDefault, getApps, initializeApp} =
  require("firebase-admin/app");
const {FieldPath, getFirestore} = require("firebase-admin/firestore");
const {createAdminRuntime} = require("../admin_runtime");
const {
  PUBLIC_PROFILE_COLLECTIONS,
  createPublicTrustProjection,
} = require("../public_trust_projection");

function parseArguments(argv) {
  const options = {apply: false, project: "", pageSize: 200};
  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index];
    if (argument === "--apply") options.apply = true;
    else if (argument === "--project") options.project = String(argv[++index] || "");
    else if (argument === "--page-size") options.pageSize = Number(argv[++index]);
    else throw new Error(`Unknown argument: ${argument}`);
  }
  if (!options.project) throw new Error("--project <projectId> is required.");
  if (!Number.isInteger(options.pageSize) ||
      options.pageSize < 1 || options.pageSize > 500) {
    throw new Error("--page-size must be an integer from 1 to 500.");
  }
  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault(), projectId: options.project});
  }
  const db = getFirestore();
  const projection = createPublicTrustProjection(createAdminRuntime());
  const seen = new Set();
  let inspected = 0;
  let changed = 0;

  for (const collection of PUBLIC_PROFILE_COLLECTIONS) {
    let cursor = null;
    for (;;) {
      let query = db.collection(collection)
          .orderBy(FieldPath.documentId())
          .limit(options.pageSize);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      if (page.empty) break;
      for (const document of page.docs) {
        inspected++;
        if (seen.has(document.id)) continue;
        seen.add(document.id);
        const result = await projection.syncUser(document.id, {
          dryRun: !options.apply,
        });
        changed += result.updated.length;
      }
      cursor = page.docs[page.docs.length - 1];
    }
  }
  console.log(JSON.stringify({
    project: options.project,
    mode: options.apply ? "apply" : "dry-run",
    profileDocumentsInspected: inspected,
    profileDocumentsChanged: changed,
  }, null, 2));
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
