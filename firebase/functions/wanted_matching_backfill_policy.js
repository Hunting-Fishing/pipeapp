"use strict";

const crypto = require("node:crypto");
const {wantedMatchId} = require("./wanted_matching_policy");

const approvedStagingProjectId = "pipebuyer-5c77f";
const checkpointSchemaVersion = 1;

function checkpointDigest(payload) {
  return crypto.createHash("sha256")
      .update(JSON.stringify(payload))
      .digest("hex");
}

function createWantedMatchingCheckpoint({projectId, createdAt, entries}) {
  if (projectId !== approvedStagingProjectId) {
    throw new Error("Wanted matching checkpoints are staging-only.");
  }
  const payload = {
    schemaVersion: checkpointSchemaVersion,
    operation: "wanted-matching-backfill",
    environment: "staging",
    projectId,
    createdAt,
    entries,
  };
  return {...payload, sha256: checkpointDigest(payload)};
}

function validatePair(pair) {
  return pair &&
    typeof pair.wantedId === "string" && pair.wantedId.length > 0 &&
    !pair.wantedId.includes("/") &&
    typeof pair.supplyId === "string" && pair.supplyId.length > 0 &&
    !pair.supplyId.includes("/") &&
    pair.matchId === wantedMatchId(pair.wantedId, pair.supplyId) &&
    Number.isInteger(pair.score) && pair.score >= 0 && pair.score <= 100;
}

function validateWantedMatchingCheckpoint(value, expectedProjectId) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Wanted matching checkpoint must be a JSON object.");
  }
  const {sha256, ...payload} = value;
  if (payload.schemaVersion !== checkpointSchemaVersion ||
      payload.operation !== "wanted-matching-backfill" ||
      payload.environment !== "staging" ||
      payload.projectId !== expectedProjectId ||
      payload.projectId !== approvedStagingProjectId ||
      !Array.isArray(payload.entries) ||
      typeof sha256 !== "string" ||
      sha256 !== checkpointDigest(payload)) {
    throw new Error("Wanted matching checkpoint validation failed.");
  }
  for (const entry of payload.entries) {
    if (!entry || typeof entry.wantedListingId !== "string" ||
        entry.wantedListingId.length === 0 ||
        entry.wantedListingId.includes("/") ||
        !Array.isArray(entry.pairs) || entry.pairs.length > 20 ||
        entry.pairs.some((pair) => !validatePair(pair) ||
          pair.wantedId !== entry.wantedListingId)) {
      throw new Error("Wanted matching checkpoint contains invalid entries.");
    }
  }
  return value;
}

function parsePositiveInteger(value, name, maximum) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > maximum) {
    throw new Error(`${name} must be an integer from 1 to ${maximum}.`);
  }
  return parsed;
}

function parseWantedMatchingBackfillArguments(argv) {
  const values = new Map();
  const switches = new Set();
  const valued = new Set([
    "--project",
    "--environment",
    "--confirm-project",
    "--checkpoint",
    "--resume",
    "--rollback",
    "--page-size",
    "--max-documents",
  ]);
  const boolean = new Set(["--apply", "--require-clean"]);
  for (let index = 0; index < argv.length; index++) {
    const flag = argv[index];
    if (boolean.has(flag)) {
      switches.add(flag);
      continue;
    }
    if (!valued.has(flag)) throw new Error(`Unknown argument: ${flag}`);
    const value = String(argv[++index] || "").trim();
    if (!value || value.startsWith("--")) {
      throw new Error(`${flag} requires a value.`);
    }
    values.set(flag, value);
  }
  const projectId = values.get("--project") || "";
  const environment = values.get("--environment") || "";
  const apply = switches.has("--apply");
  const checkpointPath = values.get("--checkpoint") || "";
  const resumePath = values.get("--resume") || "";
  const rollbackPath = values.get("--rollback") || "";
  if (!/^[a-z][a-z0-9-]{4,29}$/u.test(projectId)) {
    throw new Error("--project must be an explicit Firebase project ID.");
  }
  if ([checkpointPath, resumePath, rollbackPath].filter(Boolean).length > 1) {
    throw new Error("Use only one of --checkpoint, --resume, or --rollback.");
  }
  if ((resumePath || rollbackPath) && !apply) {
    throw new Error("Resume and rollback require --apply.");
  }
  if (apply && (environment !== "staging" ||
      projectId !== approvedStagingProjectId ||
      values.get("--confirm-project") !== projectId)) {
    throw new Error(
        "Mutation requires approved staging and exact project confirmation.",
    );
  }
  if (apply && !checkpointPath && !resumePath && !rollbackPath) {
    throw new Error("Apply requires --checkpoint, --resume, or --rollback.");
  }
  return {
    projectId,
    environment,
    apply,
    requireClean: switches.has("--require-clean"),
    checkpointPath,
    resumePath,
    rollbackPath,
    pageSize: parsePositiveInteger(
        values.get("--page-size") || "25", "--page-size", 100),
    maxDocuments: parsePositiveInteger(
        values.get("--max-documents") || "25", "--max-documents", 5000),
  };
}

function canRollbackWantedMatch(match, checkpointSha) {
  return Boolean(match &&
    match.source === "backfill" &&
    match.backfillRunId === checkpointSha &&
    Number(match.revision || 1) === 1 &&
    String(match.wantedOwnerState || "suggested") === "suggested" &&
    String(match.sellerState || "suggested") === "suggested" &&
    match.contactRecorded !== true);
}

module.exports = {
  approvedStagingProjectId,
  canRollbackWantedMatch,
  checkpointSchemaVersion,
  createWantedMatchingCheckpoint,
  parseWantedMatchingBackfillArguments,
  validateWantedMatchingCheckpoint,
};
