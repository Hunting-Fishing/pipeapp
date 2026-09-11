import assert from "node:assert/strict";
import test from "node:test";

import {
  REPAIR_CONTRACT,
  REPAIR_CONTRACTS,
  assessStaleHttpsRepair,
  assertRepairAbsent,
} from "./staging_trigger_repair.mjs";

function staleHttps(functionId = REPAIR_CONTRACT.functionId, overrides = {}) {
  const contract = REPAIR_CONTRACTS[functionId];
  return {
    platform: "gcfv2",
    id: contract.functionId,
    project: contract.projectId,
    region: contract.region,
    codebase: contract.codebase,
    state: "ACTIVE",
    httpsTrigger: {},
    environmentVariables: {FUNCTION_SIGNATURE_TYPE: "http"},
    ...overrides,
  };
}

test("preserves the original protectAuctionReserve repair contract", () => {
  const result = assessStaleHttpsRepair({result: [staleHttps()]});
  assert.equal(result.safeToDelete, true);
  assert.equal(result.trigger, "https");
  assert.equal(result.functionId, "protectAuctionReserve");
});

test("permits the proven onTagRequestCreated stale HTTPS identity", () => {
  const result = assessStaleHttpsRepair(
    {result: [staleHttps("onTagRequestCreated", {state: "FAILED"})]},
    "onTagRequestCreated",
  );
  assert.equal(result.safeToDelete, true);
  assert.equal(result.trigger, "https");
  assert.equal(result.state, "FAILED");
  assert.equal(result.functionId, "onTagRequestCreated");
  assert.equal(result.projectId, "pipebuyer-5c77f");
});

test("rejects the desired Firestore background trigger", () => {
  assert.throws(
    () => assessStaleHttpsRepair({
      result: [staleHttps("onTagRequestCreated", {
        httpsTrigger: undefined,
        eventTrigger: {eventType: "google.cloud.firestore.document.v1.created"},
      })],
    }, "onTagRequestCreated"),
    /background, not stale HTTPS/u,
  );
});

test("rejects production even when the function name matches", () => {
  assert.throws(
    () => assessStaleHttpsRepair({
      result: [staleHttps("onTagRequestCreated", {project: "flutter-flow-pipe"})],
    }, "onTagRequestCreated"),
    /0 exact match/u,
  );
});

test("rejects wrong region or codebase", () => {
  assert.throws(
    () => assessStaleHttpsRepair(
      {result: [staleHttps("onTagRequestCreated", {region: "europe-west1"})]},
      "onTagRequestCreated",
    ),
    /0 exact match/u,
  );
  assert.throws(
    () => assessStaleHttpsRepair(
      {result: [staleHttps("onTagRequestCreated", {codebase: "functions"})]},
      "onTagRequestCreated",
    ),
    /0 exact match/u,
  );
});

test("rejects ambiguous duplicate targets and unexpected lifecycle states", () => {
  assert.throws(
    () => assessStaleHttpsRepair({
      result: [staleHttps("onTagRequestCreated"), staleHttps("onTagRequestCreated")],
    }, "onTagRequestCreated"),
    /2 named target/u,
  );
  assert.throws(
    () => assessStaleHttpsRepair(
      {result: [staleHttps("onTagRequestCreated", {state: "DEPLOYING"})]},
      "onTagRequestCreated",
    ),
    /state is DEPLOYING/u,
  );
});

test("rejects any function id outside the explicit repair allowlist", () => {
  assert.throws(
    () => assessStaleHttpsRepair({result: []}, "stripeMarketplaceWebhook"),
    /not allowlisted/u,
  );
  assert.throws(
    () => assertRepairAbsent({result: []}, "acceptMarketplaceDispute"),
    /not allowlisted/u,
  );
});

test("post-delete contract requires the selected staging target to be absent", () => {
  assert.deepEqual(
    assertRepairAbsent({result: []}, "onTagRequestCreated"),
    {absent: true, ...REPAIR_CONTRACTS.onTagRequestCreated},
  );
  assert.throws(
    () => assertRepairAbsent(
      {result: [staleHttps("onTagRequestCreated")]},
      "onTagRequestCreated",
    ),
    /to be absent from staging after deletion/u,
  );
});

test("malformed inventories fail closed", () => {
  assert.throws(
    () => assessStaleHttpsRepair({}, "onTagRequestCreated"),
    /result array/u,
  );
  assert.throws(
    () => assertRepairAbsent(null, "onTagRequestCreated"),
    /result array/u,
  );
});
