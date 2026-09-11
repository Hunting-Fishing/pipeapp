import assert from "node:assert/strict";
import test from "node:test";

import {
  REPAIR_CONTRACT,
  assessStaleHttpsRepair,
  assertRepairAbsent,
} from "./staging_trigger_repair.mjs";

function staleHttps(overrides = {}) {
  return {
    platform: "gcfv2",
    id: REPAIR_CONTRACT.functionId,
    project: REPAIR_CONTRACT.projectId,
    region: REPAIR_CONTRACT.region,
    codebase: REPAIR_CONTRACT.codebase,
    state: "ACTIVE",
    httpsTrigger: {},
    environmentVariables: {FUNCTION_SIGNATURE_TYPE: "http"},
    ...overrides,
  };
}

test("permits only the proven stale staging HTTPS function", () => {
  const result = assessStaleHttpsRepair({result: [staleHttps()]});
  assert.equal(result.safeToDelete, true);
  assert.equal(result.trigger, "https");
  assert.equal(result.state, "ACTIVE");
  assert.equal(result.projectId, "pipebuyer-5c77f");
});

test("permits the same proven stale HTTPS identity when Firebase reports FAILED", () => {
  const result = assessStaleHttpsRepair({result: [staleHttps({state: "FAILED"})]});
  assert.equal(result.safeToDelete, true);
  assert.equal(result.trigger, "https");
  assert.equal(result.state, "FAILED");
  assert.equal(result.functionId, "protectAuctionReserve");
});

test("rejects the desired Firestore background trigger", () => {
  assert.throws(
    () => assessStaleHttpsRepair({
      result: [staleHttps({httpsTrigger: undefined, eventTrigger: {eventType: "written"}})],
    }),
    /background, not stale HTTPS/u,
  );
});

test("rejects production even when the function name matches", () => {
  assert.throws(
    () => assessStaleHttpsRepair({
      result: [staleHttps({project: "flutter-flow-pipe"})],
    }),
    /0 exact match/u,
  );
});

test("rejects wrong region or codebase", () => {
  assert.throws(
    () => assessStaleHttpsRepair({result: [staleHttps({region: "europe-west1"})]}),
    /0 exact match/u,
  );
  assert.throws(
    () => assessStaleHttpsRepair({result: [staleHttps({codebase: "functions"})]}),
    /0 exact match/u,
  );
});

test("rejects ambiguous duplicate targets and unexpected lifecycle states", () => {
  assert.throws(
    () => assessStaleHttpsRepair({result: [staleHttps(), staleHttps()]}),
    /2 named target/u,
  );
  assert.throws(
    () => assessStaleHttpsRepair({result: [staleHttps({state: "DEPLOYING"})]}),
    /state is DEPLOYING/u,
  );
});

test("post-delete contract requires the exact staging target to be absent", () => {
  assert.deepEqual(
    assertRepairAbsent({result: []}),
    {absent: true, ...REPAIR_CONTRACT},
  );
  assert.throws(
    () => assertRepairAbsent({result: [staleHttps()]}),
    /to be absent from staging after deletion/u,
  );
  assert.throws(
    () => assertRepairAbsent({result: [staleHttps({region: "europe-west1"})]}),
    /to be absent from staging after deletion/u,
  );
});

test("malformed inventories fail closed", () => {
  assert.throws(() => assessStaleHttpsRepair({}), /result array/u);
  assert.throws(() => assertRepairAbsent(null), /result array/u);
});
