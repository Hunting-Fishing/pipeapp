#!/usr/bin/env node

import fs from "node:fs";
import process from "node:process";
import {pathToFileURL} from "node:url";

export const REPAIR_CONTRACT = Object.freeze({
  projectId: "pipebuyer-5c77f",
  functionId: "protectAuctionReserve",
  codebase: "marketplace",
  region: "us-central1",
});

const DELETABLE_STALE_STATES = new Set(["ACTIVE", "FAILED"]);

function inventoryRows(inventory) {
  if (!inventory || !Array.isArray(inventory.result)) {
    throw new Error("Firebase function inventory must contain a result array.");
  }
  return inventory.result;
}

function classifyTrigger(fn) {
  if (fn.eventTrigger) return "background";
  if (fn.callableTrigger) return "callable";
  if (fn.httpsTrigger) return "https";
  if (fn?.environmentVariables?.FUNCTION_SIGNATURE_TYPE === "http") return "https";
  return "unknown";
}

function namedRows(inventory) {
  return inventoryRows(inventory).filter((fn) => fn?.id === REPAIR_CONTRACT.functionId);
}

function matchingRows(inventory) {
  return namedRows(inventory).filter((fn) =>
    fn?.project === REPAIR_CONTRACT.projectId &&
    fn?.region === REPAIR_CONTRACT.region &&
    fn?.codebase === REPAIR_CONTRACT.codebase,
  );
}

export function assessStaleHttpsRepair(inventory) {
  const named = namedRows(inventory);
  const rows = matchingRows(inventory);
  if (named.length !== 1 || rows.length !== 1) {
    throw new Error(
      `Expected exactly one ${REPAIR_CONTRACT.codebase}:${REPAIR_CONTRACT.functionId} ` +
      `in ${REPAIR_CONTRACT.projectId}/${REPAIR_CONTRACT.region}; ` +
      `found ${named.length} named target(s) and ${rows.length} exact match(es).`,
    );
  }

  const target = rows[0];
  const trigger = classifyTrigger(target);
  if (trigger !== "https") {
    throw new Error(
      `Refusing repair because ${REPAIR_CONTRACT.functionId} is ${trigger}, not stale HTTPS.`,
    );
  }

  if (target.state && !DELETABLE_STALE_STATES.has(target.state)) {
    throw new Error(`Refusing repair because deployed function state is ${target.state}.`);
  }

  return {
    safeToDelete: true,
    trigger,
    state: target.state ?? null,
    platform: target.platform ?? null,
    ...REPAIR_CONTRACT,
  };
}

export function assertRepairAbsent(inventory) {
  const rows = namedRows(inventory);
  if (rows.length !== 0) {
    throw new Error(
      `Expected ${REPAIR_CONTRACT.functionId} to be absent from staging after deletion; ` +
      `found ${rows.length}.`,
    );
  }
  return {absent: true, ...REPAIR_CONTRACT};
}

function usage() {
  return "Usage: node tool/staging_trigger_repair.mjs <assess|assert-absent> <inventory.json>";
}

function main(argv) {
  const [mode, inventoryPath, ...extra] = argv;
  if (!mode || !inventoryPath || extra.length > 0 || !["assess", "assert-absent"].includes(mode)) {
    throw new Error(usage());
  }

  const inventory = JSON.parse(fs.readFileSync(inventoryPath, "utf8"));
  const result = mode === "assess"
    ? assessStaleHttpsRepair(inventory)
    : assertRepairAbsent(inventory);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    main(process.argv.slice(2));
  } catch (error) {
    console.error(`staging trigger repair guard: ${error.message}`);
    process.exitCode = 1;
  }
}
