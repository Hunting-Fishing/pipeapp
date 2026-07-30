"use strict";

const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {FieldPath, getFirestore} = require("firebase-admin/firestore");
const {
  buildMarketplaceSearchTokens,
  searchIndexVersion,
} = require("../marketplace_listing_policy");

function argument(name) {
  const index = process.argv.indexOf(name);
  return index >= 0 ? String(process.argv[index + 1] || "").trim() : "";
}

const projectId = argument("--project");
const confirmation = argument("--confirm-project");
const apply = process.argv.includes("--apply");
if (!projectId) {
  throw new Error("Usage: --project <id> [--apply --confirm-project <id>]");
}
if (apply && confirmation !== projectId) {
  throw new Error("Apply mode requires --confirm-project to match --project.");
}

initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();

async function run() {
  let cursor = null;
  let inspected = 0;
  let changed = 0;
  do {
    let query = db.collection("public_listings")
        .orderBy(FieldPath.documentId())
        .limit(200);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    const writer = apply ? db.bulkWriter() : null;
    for (const document of page.docs) {
      inspected++;
      const data = document.data();
      const searchTokens = buildMarketplaceSearchTokens(data);
      const current = Array.isArray(data.searchTokens) ? data.searchTokens : [];
      const unchanged = data.searchIndexVersion === searchIndexVersion &&
        JSON.stringify(current) === JSON.stringify(searchTokens);
      if (unchanged) continue;
      changed++;
      if (writer) {
        writer.update(document.ref, {searchTokens, searchIndexVersion});
      }
    }
    if (writer) await writer.close();
    cursor = page.docs.at(-1);
    if (page.size < 200) break;
  } while (cursor);
  console.log(JSON.stringify({
    projectId,
    mode: apply ? "applied" : "dry-run",
    inspected,
    changed,
    searchIndexVersion,
  }));
}

run().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
