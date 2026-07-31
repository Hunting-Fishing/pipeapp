"use strict";

const crypto = require("node:crypto");
const {
  buildMarketplaceSearchTokens,
  searchIndexVersion,
} = require("./marketplace_listing_policy");

const checkpointSchemaVersion = 1;
const approvedStagingProjectId = "pipebuyer-5c77f";

function sameJson(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function beforeState(data) {
  return {
    searchTokensPresent: Object.hasOwn(data, "searchTokens"),
    searchTokens: data.searchTokens,
    searchIndexVersionPresent: Object.hasOwn(data, "searchIndexVersion"),
    searchIndexVersion: data.searchIndexVersion,
  };
}

function planMarketplaceSearchChange(listingId, data) {
  const searchTokens = buildMarketplaceSearchTokens(data);
  if (data.searchIndexVersion === searchIndexVersion &&
      sameJson(data.searchTokens, searchTokens)) {
    return null;
  }
  return {
    listingId,
    before: beforeState(data),
    after: {searchTokens, searchIndexVersion},
  };
}

function checkpointPayload({projectId, createdAt, entries}) {
  return {
    schemaVersion: checkpointSchemaVersion,
    operation: "marketplace-search-index-backfill",
    projectId,
    environment: "staging",
    createdAt,
    searchIndexVersion,
    entries,
  };
}

function checkpointDigest(payload) {
  return crypto.createHash("sha256")
      .update(JSON.stringify(payload))
      .digest("hex");
}

function createMarketplaceSearchCheckpoint({projectId, createdAt, entries}) {
  if (projectId !== approvedStagingProjectId) {
    throw new Error("Checkpoints may be created only for approved staging.");
  }
  const payload = checkpointPayload({projectId, createdAt, entries});
  return {...payload, sha256: checkpointDigest(payload)};
}

function validateMarketplaceSearchCheckpoint(value, expectedProjectId) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Checkpoint must be a JSON object.");
  }
  const {sha256, ...payload} = value;
  if (payload.schemaVersion !== checkpointSchemaVersion ||
      payload.operation !== "marketplace-search-index-backfill" ||
      payload.environment !== "staging" ||
      payload.projectId !== expectedProjectId ||
      payload.projectId !== approvedStagingProjectId ||
      payload.searchIndexVersion !== searchIndexVersion ||
      !Array.isArray(payload.entries) ||
      typeof sha256 !== "string" ||
      sha256 !== checkpointDigest(payload)) {
    throw new Error("Checkpoint validation failed.");
  }
  for (const entry of payload.entries) {
    if (!entry || typeof entry.listingId !== "string" ||
        entry.listingId.length === 0 || entry.listingId.includes("/") ||
        !entry.before || !entry.after ||
        typeof entry.before.searchTokensPresent !== "boolean" ||
        typeof entry.before.searchIndexVersionPresent !== "boolean" ||
        !Array.isArray(entry.after.searchTokens) ||
        entry.after.searchIndexVersion !== searchIndexVersion) {
      throw new Error("Checkpoint contains an invalid listing entry.");
    }
  }
  return value;
}

function planMarketplaceSearchRollback(entry, current) {
  if (current.searchIndexVersion !== entry.after.searchIndexVersion ||
      !sameJson(current.searchTokens, entry.after.searchTokens)) {
    return {safe: false, values: {}, deleteFields: []};
  }
  const values = {};
  const deleteFields = [];
  if (entry.before.searchTokensPresent) {
    values.searchTokens = entry.before.searchTokens;
  } else {
    deleteFields.push("searchTokens");
  }
  if (entry.before.searchIndexVersionPresent) {
    values.searchIndexVersion = entry.before.searchIndexVersion;
  } else {
    deleteFields.push("searchIndexVersion");
  }
  return {safe: true, values, deleteFields};
}

function parsePositiveInteger(value, name, maximum) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > maximum) {
    throw new Error(`${name} must be an integer from 1 to ${maximum}.`);
  }
  return parsed;
}

function parseMarketplaceSearchBackfillArguments(argv) {
  const values = new Map();
  const switches = new Set();
  const valued = new Set([
    "--project",
    "--environment",
    "--confirm-project",
    "--checkpoint",
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
  const apply = switches.has("--apply");
  const rollbackPath = values.get("--rollback") || "";
  const checkpointPath = values.get("--checkpoint") || "";
  const environment = values.get("--environment") || "";
  if (!/^[a-z][a-z0-9-]{4,29}$/u.test(projectId)) {
    throw new Error("--project must be an explicit Firebase project ID.");
  }
  if (rollbackPath && !apply) {
    throw new Error("Rollback requires --apply.");
  }
  if (apply && (environment !== "staging" ||
      projectId !== approvedStagingProjectId ||
      values.get("--confirm-project") !== projectId)) {
    throw new Error(
        "Mutation requires approved staging, --environment staging, and exact project confirmation.",
    );
  }
  if (apply && !rollbackPath && !checkpointPath) {
    throw new Error("Backfill apply requires a new --checkpoint path.");
  }
  if (rollbackPath && checkpointPath) {
    throw new Error("Use --rollback or --checkpoint, not both.");
  }
  return {
    projectId,
    environment,
    apply,
    requireClean: switches.has("--require-clean"),
    checkpointPath,
    rollbackPath,
    pageSize: parsePositiveInteger(
        values.get("--page-size") || "200", "--page-size", 500),
    maxDocuments: values.has("--max-documents") ?
      parsePositiveInteger(
          values.get("--max-documents"), "--max-documents", 1000000) : null,
  };
}

module.exports = {
  approvedStagingProjectId,
  checkpointSchemaVersion,
  createMarketplaceSearchCheckpoint,
  parseMarketplaceSearchBackfillArguments,
  planMarketplaceSearchChange,
  planMarketplaceSearchRollback,
  validateMarketplaceSearchCheckpoint,
};
