import assert from "node:assert/strict";
import test from "node:test";

import {compareFunctionInventory} from "./function_parity.mjs";

const manifest = {
  firebase: {
    projectId: "pipe-staging",
    expectedFunctions: ["createOffer", "acceptOffer"],
  },
};

test("matching active marketplace functions pass parity", () => {
  const result = compareFunctionInventory({
    manifest,
    projectId: "pipe-staging",
    inventory: {
      result: [
        {id: "acceptOffer", codebase: "marketplace", state: "ACTIVE"},
        {id: "unrelated", codebase: "functions", state: "ACTIVE"},
        {id: "createOffer", codebase: "marketplace", state: "ACTIVE"},
      ],
    },
  });
  assert.equal(result.passed, true);
  assert.deepEqual(result.deployed, ["acceptOffer", "createOffer"]);
  assert.deepEqual(result.missing, []);
  assert.deepEqual(result.unexpected, []);
});

test("missing, unexpected, and inactive functions fail parity", () => {
  const result = compareFunctionInventory({
    manifest,
    projectId: "pipe-staging",
    inventory: {
      result: [
        {id: "createOffer", codebase: "marketplace", state: "FAILED"},
        {id: "legacyOffer", codebase: "marketplace", state: "ACTIVE"},
      ],
    },
  });
  assert.equal(result.passed, false);
  assert.deepEqual(result.missing, ["acceptOffer"]);
  assert.deepEqual(result.unexpected, ["legacyOffer"]);
  assert.deepEqual(result.inactive, ["createOffer"]);
});

test("project mismatch and malformed inventories fail closed", () => {
  assert.throws(
      () => compareFunctionInventory({
        manifest,
        projectId: "pipe-production",
        inventory: {result: []},
      }),
      /does not match/u,
  );
  assert.throws(
      () => compareFunctionInventory({
        manifest,
        projectId: "pipe-staging",
        inventory: {},
      }),
      /result array/u,
  );
});
