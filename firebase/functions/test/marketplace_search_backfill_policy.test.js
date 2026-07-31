"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  approvedStagingProjectId,
  createMarketplaceSearchCheckpoint,
  parseMarketplaceSearchBackfillArguments,
  planMarketplaceSearchChange,
  planMarketplaceSearchRollback,
  validateMarketplaceSearchCheckpoint,
} = require("../marketplace_search_backfill_policy");

test("backfill planning changes only stale server-owned search fields", () => {
  const listing = {title: "CAT 320 Excavator", category: "Heavy Equipment"};
  const change = planMarketplaceSearchChange("listing-1", listing);
  assert.equal(change.listingId, "listing-1");
  assert.deepEqual(change.before, {
    searchTokensPresent: false,
    searchTokens: undefined,
    searchIndexVersionPresent: false,
    searchIndexVersion: undefined,
  });
  assert.ok(change.after.searchTokens.includes("cat 320"));
  assert.equal(
      planMarketplaceSearchChange("listing-1", {
        ...listing,
        ...change.after,
      }),
      null,
  );
});

test("checkpoint validation detects target drift and file tampering", () => {
  const entry = planMarketplaceSearchChange("listing-1", {title: "Pipe"});
  const checkpoint = createMarketplaceSearchCheckpoint({
    projectId: approvedStagingProjectId,
    createdAt: "2026-07-31T00:00:00.000Z",
    entries: [entry],
  });
  assert.equal(
      validateMarketplaceSearchCheckpoint(
          checkpoint, approvedStagingProjectId),
      checkpoint,
  );
  assert.throws(
      () => validateMarketplaceSearchCheckpoint(
          {...checkpoint, projectId: "flutter-flow-pipe"},
          approvedStagingProjectId,
      ),
      /validation failed/u,
  );
  assert.throws(
      () => validateMarketplaceSearchCheckpoint({
        ...checkpoint,
        entries: [{...entry, listingId: "changed"}],
      }, approvedStagingProjectId),
      /validation failed/u,
  );
});

test("rollback refuses changed documents and restores exact prior fields", () => {
  const change = planMarketplaceSearchChange("listing-1", {
    title: "Pipe",
    searchTokens: ["old"],
    searchIndexVersion: 0,
  });
  assert.equal(planMarketplaceSearchRollback(change, {
    searchTokens: ["newer"],
    searchIndexVersion: change.after.searchIndexVersion,
  }).safe, false);
  assert.deepEqual(planMarketplaceSearchRollback(change, change.after), {
    safe: true,
    values: {searchTokens: ["old"], searchIndexVersion: 0},
    deleteFields: [],
  });

  const missing = planMarketplaceSearchChange("listing-2", {title: "Valve"});
  assert.deepEqual(planMarketplaceSearchRollback(missing, missing.after), {
    safe: true,
    values: {},
    deleteFields: ["searchTokens", "searchIndexVersion"],
  });
});

test("mutation flags are hard-locked to confirmed isolated staging", () => {
  const base = [
    "--project", approvedStagingProjectId,
    "--environment", "staging",
    "--confirm-project", approvedStagingProjectId,
    "--apply",
    "--checkpoint", "artifacts/search-checkpoint.json",
  ];
  const options = parseMarketplaceSearchBackfillArguments(base);
  assert.equal(options.apply, true);
  assert.equal(options.pageSize, 200);
  assert.throws(
      () => parseMarketplaceSearchBackfillArguments([
        ...base.slice(0, 1), "flutter-flow-pipe", ...base.slice(2),
      ]),
      /approved staging/u,
  );
  assert.throws(
      () => parseMarketplaceSearchBackfillArguments([
        "--project", approvedStagingProjectId, "--apply",
        "--confirm-project", approvedStagingProjectId,
        "--checkpoint", "checkpoint.json",
      ]),
      /approved staging/u,
  );
});

test("dry run supports bounded canaries and clean-index validation", () => {
  const options = parseMarketplaceSearchBackfillArguments([
    "--project", approvedStagingProjectId,
    "--page-size", "25",
    "--max-documents", "100",
    "--require-clean",
  ]);
  assert.equal(options.apply, false);
  assert.equal(options.pageSize, 25);
  assert.equal(options.maxDocuments, 100);
  assert.equal(options.requireClean, true);
  assert.throws(
      () => parseMarketplaceSearchBackfillArguments([
        "--project", approvedStagingProjectId, "--page-size", "501",
      ]),
      /1 to 500/u,
  );
  assert.throws(
      () => parseMarketplaceSearchBackfillArguments([
        "--project", approvedStagingProjectId, "--unknown",
      ]),
      /Unknown argument/u,
  );
});
