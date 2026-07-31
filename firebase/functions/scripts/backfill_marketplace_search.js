"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {applicationDefault, initializeApp} = require("firebase-admin/app");
const {
  FieldPath,
  FieldValue,
  getFirestore,
} = require("firebase-admin/firestore");
const {
  createMarketplaceSearchCheckpoint,
  parseMarketplaceSearchBackfillArguments,
  planMarketplaceSearchChange,
  planMarketplaceSearchRollback,
  validateMarketplaceSearchCheckpoint,
} = require("../marketplace_search_backfill_policy");

async function scanListings(db, options) {
  let cursor = null;
  let inspected = 0;
  const planned = [];
  do {
    const remaining = options.maxDocuments === null ? options.pageSize :
      Math.min(options.pageSize, options.maxDocuments - inspected);
    if (remaining <= 0) break;
    let query = db.collection("public_listings")
        .orderBy(FieldPath.documentId())
        .limit(remaining);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const document of page.docs) {
      inspected++;
      const entry = planMarketplaceSearchChange(document.id, document.data());
      if (entry) planned.push({...entry, updateTime: document.updateTime});
    }
    cursor = page.docs.at(-1);
    if (page.size < remaining) break;
  } while (cursor);
  return {inspected, planned};
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

async function applyBackfill(db, planned) {
  const writer = db.bulkWriter();
  let applied = 0;
  writer.onWriteResult(() => applied++);
  for (const entry of planned) {
    writer.update(
        db.collection("public_listings").doc(entry.listingId),
        entry.after,
        {lastUpdateTime: entry.updateTime},
    );
  }
  await writer.close();
  return applied;
}

async function applyRollback(db, checkpoint) {
  const writer = db.bulkWriter();
  let restored = 0;
  let conflicts = 0;
  writer.onWriteResult(() => restored++);
  for (const entry of checkpoint.entries) {
    const reference = db.collection("public_listings").doc(entry.listingId);
    const snapshot = await reference.get();
    if (!snapshot.exists) {
      conflicts++;
      continue;
    }
    const rollback = planMarketplaceSearchRollback(entry, snapshot.data());
    if (!rollback.safe) {
      conflicts++;
      continue;
    }
    const update = {...rollback.values};
    for (const field of rollback.deleteFields) update[field] = FieldValue.delete();
    writer.update(reference, update, {lastUpdateTime: snapshot.updateTime});
  }
  await writer.close();
  return {restored, conflicts};
}

async function run(argv = process.argv.slice(2)) {
  const options = parseMarketplaceSearchBackfillArguments(argv);
  initializeApp({
    credential: applicationDefault(),
    projectId: options.projectId,
  });
  const db = getFirestore();
  if (options.rollbackPath) {
    const checkpoint = validateMarketplaceSearchCheckpoint(
        JSON.parse(fs.readFileSync(path.resolve(options.rollbackPath), "utf8")),
        options.projectId,
    );
    const result = await applyRollback(db, checkpoint);
    console.log(JSON.stringify({
      projectId: options.projectId,
      mode: "rollback",
      checkpoint: path.resolve(options.rollbackPath),
      ...result,
    }));
    if (result.conflicts > 0) process.exitCode = 2;
    return;
  }

  const scan = await scanListings(db, options);
  let applied = 0;
  let checkpoint = null;
  if (options.apply && scan.planned.length > 0) {
    const serializableEntries = scan.planned.map(
        ({updateTime: _updateTime, ...entry}) => entry,
    );
    checkpoint = writeCheckpoint(
        options.checkpointPath,
        createMarketplaceSearchCheckpoint({
          projectId: options.projectId,
          createdAt: new Date().toISOString(),
          entries: serializableEntries,
        }),
    );
    applied = await applyBackfill(db, scan.planned);
  }
  console.log(JSON.stringify({
    projectId: options.projectId,
    mode: options.apply ? "applied" : "dry-run",
    inspected: scan.inspected,
    changed: scan.planned.length,
    applied,
    checkpoint,
    searchIndexValid: scan.planned.length === 0,
  }));
  if (options.requireClean && scan.planned.length > 0) process.exitCode = 2;
}

if (require.main === module) {
  run().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}

module.exports = {applyBackfill, applyRollback, run, scanListings};
