"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {applicationDefault, getApps, initializeApp} =
  require("firebase-admin/app");
const {FieldPath, getFirestore} = require("firebase-admin/firestore");
const {createAdminRuntime} = require("../admin_runtime");
const {createWantedMatching} = require("../wanted_matching");
const {wantedMatchId} = require("../wanted_matching_policy");
const {
  canRollbackWantedMatch,
  createWantedMatchingCheckpoint,
  parseWantedMatchingBackfillArguments,
  validateWantedMatchingCheckpoint,
} = require("../wanted_matching_backfill_policy");

function readCheckpoint(checkpointPath, projectId) {
  return validateWantedMatchingCheckpoint(
      JSON.parse(fs.readFileSync(path.resolve(checkpointPath), "utf8")),
      projectId,
  );
}

function writeCheckpoint(checkpointPath, checkpoint) {
  const resolved = path.resolve(checkpointPath);
  if (fs.existsSync(resolved)) {
    throw new Error("Checkpoint path already exists; choose a new file.");
  }
  fs.mkdirSync(path.dirname(resolved), {recursive: true});
  fs.writeFileSync(resolved, `${JSON.stringify(checkpoint, null, 2)}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  return resolved;
}

async function scanWantedListings(db, matching, options) {
  let cursor = null;
  let inspected = 0;
  let candidates = 0;
  const entries = [];
  do {
    const remaining = Math.min(
        options.pageSize,
        options.maxDocuments - inspected,
    );
    if (remaining <= 0) break;
    let query = db.collection("public_listings")
        .where("transactionType", "==", "Wanted / Seeking")
        .where("status", "==", "active")
        .orderBy("createdAt", "desc")
        .orderBy(FieldPath.documentId(), "desc")
        .limit(remaining);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const document of page.docs) {
      inspected++;
      if (String(document.data().wantedStatus || "open") !== "open") continue;
      const plan = await matching.planListingMatches(
          document.id,
          document.data(),
      );
      candidates += plan.candidates;
      const pairs = plan.planned.map((pair) => ({
        wantedId: pair.wantedId,
        supplyId: pair.supplyId,
        matchId: wantedMatchId(pair.wantedId, pair.supplyId),
        score: pair.score,
      }));
      const existing = pairs.length === 0 ? [] : await db.getAll(
          ...pairs.map((pair) =>
            db.collection("wanted_matches").doc(pair.matchId)),
      );
      const missingPairs = pairs.filter((_pair, index) =>
        !existing[index].exists,
      );
      if (missingPairs.length > 0) {
        entries.push({
          wantedListingId: document.id,
          pairs: missingPairs,
        });
      }
    }
    cursor = page.docs.at(-1);
    if (page.size < remaining) break;
  } while (cursor && inspected < options.maxDocuments);
  return {inspected, candidates, entries};
}

async function applyCheckpoint(matching, checkpoint) {
  let created = 0;
  let unchanged = 0;
  for (const entry of checkpoint.entries) {
    for (const pair of entry.pairs) {
      const changed = await matching.persistMatch({
        wantedId: pair.wantedId,
        supplyId: pair.supplyId,
        source: "backfill",
        backfillRunId: checkpoint.sha256,
      });
      if (changed) created++;
      else unchanged++;
    }
  }
  return {created, unchanged};
}

async function rollbackPair(db, checkpoint, pair) {
  const matchRef = db.collection("wanted_matches").doc(pair.matchId);
  return db.runTransaction(async (transaction) => {
    const matchSnapshot = await transaction.get(matchRef);
    if (!matchSnapshot.exists) return "missing";
    const match = matchSnapshot.data();
    if (!canRollbackWantedMatch(match, checkpoint.sha256)) return "conflict";
    const wantedRef = db.collection("public_listings").doc(pair.wantedId);
    const wantedSnapshot = await transaction.get(wantedRef);
    if (!wantedSnapshot.exists) return "conflict";
    const matchCount = Math.max(
        0,
        Number(wantedSnapshot.data().matchCount || 0) - 1,
    );
    transaction.delete(matchRef);
    transaction.delete(matchRef.collection("events").doc("1"));
    transaction.delete(
        db.collection("users").doc(match.wantedOwnerUid)
            .collection("notifications").doc(`wanted-${pair.matchId}`),
    );
    transaction.delete(
        db.collection("users").doc(match.sellerUid)
            .collection("notifications")
            .doc(`wanted-interest-${pair.matchId}`),
    );
    transaction.update(wantedRef, {matchCount});
    return "restored";
  });
}

async function rollbackCheckpoint(db, checkpoint) {
  const totals = {restored: 0, missing: 0, conflicts: 0};
  for (const entry of checkpoint.entries) {
    for (const pair of entry.pairs) {
      const result = await rollbackPair(db, checkpoint, pair);
      totals[result === "conflict" ? "conflicts" : result]++;
    }
  }
  return totals;
}

async function run(argv = process.argv.slice(2)) {
  const options = parseWantedMatchingBackfillArguments(argv);
  if (getApps().length === 0) {
    const credential = applicationDefault();
    try {
      await credential.getAccessToken();
    } catch (_error) {
      throw new Error(
          "Application Default Credentials are unavailable. Run " +
          "'gcloud auth application-default login' with the approved staging " +
          "operator account, then repeat the dry run.",
      );
    }
    initializeApp({
      credential,
      projectId: options.projectId,
    });
  }
  const db = getFirestore();
  const matching = createWantedMatching(createAdminRuntime());
  const suppliedCheckpointPath = options.resumePath || options.rollbackPath;
  if (suppliedCheckpointPath) {
    const checkpoint = readCheckpoint(
        suppliedCheckpointPath,
        options.projectId,
    );
    if (options.rollbackPath) {
      const result = await rollbackCheckpoint(db, checkpoint);
      console.log(JSON.stringify({
        projectId: options.projectId,
        mode: "rollback",
        checkpoint: path.resolve(options.rollbackPath),
        ...result,
      }));
      if (result.conflicts > 0) process.exitCode = 2;
      return;
    }
    const result = await applyCheckpoint(matching, checkpoint);
    console.log(JSON.stringify({
      projectId: options.projectId,
      mode: "resume",
      checkpoint: path.resolve(options.resumePath),
      ...result,
    }));
    return;
  }

  const scan = await scanWantedListings(db, matching, options);
  const plannedMatches = scan.entries.reduce(
      (total, entry) => total + entry.pairs.length,
      0,
  );
  let applied = {created: 0, unchanged: 0};
  let checkpointPath = null;
  if (options.apply) {
    const checkpoint = createWantedMatchingCheckpoint({
      projectId: options.projectId,
      createdAt: new Date().toISOString(),
      entries: scan.entries,
    });
    checkpointPath = writeCheckpoint(options.checkpointPath, checkpoint);
    applied = await applyCheckpoint(matching, checkpoint);
  }
  console.log(JSON.stringify({
    projectId: options.projectId,
    mode: options.apply ? "applied" : "dry-run",
    inspected: scan.inspected,
    candidates: scan.candidates,
    wantedAdsWithMatches: scan.entries.length,
    plannedMatches,
    checkpoint: checkpointPath,
    ...applied,
  }));
  if (options.requireClean && plannedMatches > 0) process.exitCode = 2;
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}

module.exports = {
  applyCheckpoint,
  rollbackCheckpoint,
  rollbackPair,
  run,
  scanWantedListings,
};
