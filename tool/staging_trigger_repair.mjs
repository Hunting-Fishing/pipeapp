#!/usr/bin/env node

import fs from "node:fs";
import process from "node:process";
import {pathToFileURL} from "node:url";

export const REPAIR_CONTRACTS = Object.freeze({
  protectAuctionReserve: Object.freeze({
    projectId: "pipebuyer-5c77f",
    functionId: "protectAuctionReserve",
    codebase: "marketplace",
    region: "us-central1",
  }),
  onTagRequestCreated: Object.freeze({
    projectId: "pipebuyer-5c77f",
    functionId: "onTagRequestCreated",
    codebase: "marketplace",
    region: "us-central1",
  }),
});

export const DEFAULT_REPAIR_FUNCTION_ID = "protectAuctionReserve";
export const REPAIR_CONTRACT = REPAIR_CONTRACTS[DEFAULT_REPAIR_FUNCTION_ID];

const DELETABLE_STALE_STATES = new Set(["ACTIVE", "FAILED"]);

function inventoryRows(inventory) {
  if (!inventory || !Array.isArray(inventory.result)) {
    throw new Error("Firebase function inventory must contain a result array.");
  }
  return inventory.result;
}

function repairContract(functionId) {
  const contract = REPAIR_CONTRACTS[functionId];
  if (!contract) {
    throw new Error(`Repair target ${functionId} is not allowlisted.`);
  }
  return contract;
}

function classifyTrigger(fn) {
  if (fn.eventTrigger) return "background";
  if (fn.callableTrigger) return "callable";
  if (fn.httpsTrigger) return "https";
  if (fn?.environmentVariables?.FUNCTION_SIGNATURE_TYPE === "http") return "https";
  return "unknown";
}

function namedRows(inventory, contract) {
  return inventoryRows(inventory).filter((fn) => fn?.id === contract.functionId);
}

function matchingRows(inventory, contract) {
  return namedRows(inventory, contract).filter((fn) =>
    fn?.project === contract.projectId &&
    fn?.region === contract.region &&
    fn?.codebase === contract.codebase,
  );
}

export function assessStaleHttpsRepair(inventory, functionId = DEFAULT_REPAIR_FUNCTION_ID) {
  const contract = repairContract(functionId);
  const named = namedRows(inventory, contract);
  const rows = matchingRows(inventory, contract);
  if (named.length !== 1 || rows.length !== 1) {
    throw new Error(
      `Expected exactly one ${contract.codebase}:${contract.functionId} ` +
      `in ${contract.projectId}/${contract.region}; ` +
      `found ${named.length} named target(s) and ${rows.length} exact match(es).`,
    );
  }

  const target = rows[0];
  const trigger = classifyTrigger(target);
  if (trigger !== "https") {
    throw new Error(
      `Refusing repair because ${contract.functionId} is ${trigger}, not stale HTTPS.`,
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
    ...contract,
  };
}

export function assertRepairAbsent(inventory, functionId = DEFAULT_REPAIR_FUNCTION_ID) {
  const contract = repairContract(functionId);
  const rows = namedRows(inventory, contract);
  if (rows.length !== 0) {
    throw new Error(
      `Expected ${contract.functionId} to be absent from staging after deletion; ` +
      `found ${rows.length}.`,
    );
  }
  return {absent: true, ...contract};
}

function usage() {
  return "Usage: node tool/staging_trigger_repair.mjs <assess|assert-absent> [allowlisted-function-id] <inventory.json>";
}

function main(argv) {
  const [mode, ...args] = argv;
  if (!mode || !["assess", "assert-absent"].includes(mode) || ![1, 2].includes(args.length)) {
    throw new Error(usage());
  }

  const functionId = args.length === 2 ? args[0] : DEFAULT_REPAIR_FUNCTION_ID;
  const inventoryPath = args.length === 2 ? args[1] : args[0];
  const inventory = JSON.parse(fs.readFileSync(inventoryPath, "utf8"));
  const result = mode === "assess"
    ? assessStaleHttpsRepair(inventory, functionId)
    : assertRepairAbsent(inventory, functionId);
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
