"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {wantedMatchId} = require("../wanted_matching_policy");
const {
  approvedStagingProjectId,
  canRollbackWantedMatch,
  createWantedMatchingCheckpoint,
  parseWantedMatchingBackfillArguments,
  validateWantedMatchingCheckpoint,
} = require("../wanted_matching_backfill_policy");

function entry() {
  return {
    wantedListingId: "wanted-1",
    pairs: [{
      wantedId: "wanted-1",
      supplyId: "supply-1",
      matchId: wantedMatchId("wanted-1", "supply-1"),
      score: 82,
    }],
  };
}

test("Wanted backfill checkpoints are staging-only and tamper evident", () => {
  const checkpoint = createWantedMatchingCheckpoint({
    projectId: approvedStagingProjectId,
    createdAt: "2026-07-31T00:00:00.000Z",
    entries: [entry()],
  });
  assert.equal(validateWantedMatchingCheckpoint(
      checkpoint, approvedStagingProjectId), checkpoint);
  assert.throws(() => validateWantedMatchingCheckpoint({
    ...checkpoint,
    entries: [{...entry(), wantedListingId: "changed"}],
  }, approvedStagingProjectId), /validation failed/u);
  assert.throws(() => createWantedMatchingCheckpoint({
    projectId: "production-project",
    createdAt: "2026-07-31T00:00:00.000Z",
    entries: [],
  }), /staging-only/u);
});

test("Wanted backfill mutation requires exact staging confirmation", () => {
  assert.throws(() => parseWantedMatchingBackfillArguments([
    "--project", approvedStagingProjectId,
    "--environment", "staging",
    "--apply",
    "--checkpoint", "checkpoint.json",
  ]), /exact project confirmation/u);
  const options = parseWantedMatchingBackfillArguments([
    "--project", approvedStagingProjectId,
    "--environment", "staging",
    "--confirm-project", approvedStagingProjectId,
    "--apply",
    "--checkpoint", "checkpoint.json",
    "--max-documents", "50",
  ]);
  assert.equal(options.apply, true);
  assert.equal(options.maxDocuments, 50);
});

test("dry runs are bounded and cannot impersonate resume or rollback", () => {
  const dryRun = parseWantedMatchingBackfillArguments([
    "--project", approvedStagingProjectId,
  ]);
  assert.equal(dryRun.apply, false);
  assert.equal(dryRun.maxDocuments, 25);
  assert.equal(dryRun.pageSize, 25);
  assert.throws(() => parseWantedMatchingBackfillArguments([
    "--project", approvedStagingProjectId,
    "--resume", "checkpoint.json",
  ]), /require --apply/u);
});

test("rollback refuses interacted or unrelated matches", () => {
  const safe = {
    source: "backfill",
    backfillRunId: "run",
    revision: 1,
    wantedOwnerState: "suggested",
    sellerState: "suggested",
  };
  assert.equal(canRollbackWantedMatch(safe, "run"), true);
  assert.equal(canRollbackWantedMatch({...safe, revision: 2}, "run"), false);
  assert.equal(canRollbackWantedMatch(
      {...safe, wantedOwnerState: "contacted"}, "run"), false);
  assert.equal(canRollbackWantedMatch(safe, "another-run"), false);
});
