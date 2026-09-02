"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function source(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

test("production entrypoint exports protected dispatch request cancellation", () => {
  const production = source("production_bootstrap.js");
  assert.match(
      production,
      /createDispatchRequestLifecycleCommands/,
  );
  assert.match(
      production,
      /exports\.cancelDispatchJob\s*=\s*onCall\(/,
  );
  assert.match(
      production,
      /policyAcceptanceCommands\.requireCurrentPolicies\([\s\S]*dispatchRequestLifecycleCommands\.cancelDispatchJob/,
  );
});

test("cancellation command preserves private reason and public lifecycle event", () => {
  const lifecycle = source("dispatch_request_lifecycle_commands.js");
  assert.match(lifecycle, /cancellationReason: cancellation\.reason/);
  assert.match(lifecycle, /event: "request_cancelled"/);
  assert.match(lifecycle, /status: "request_cancelled"/);
  assert.match(lifecycle, /validityStatus: "inactive"/);
  assert.doesNotMatch(
      lifecycle,
      /publicChanges\s*=\s*\{[\s\S]*cancellationReason:/,
  );
});

test("Functions check command includes R4 cancellation modules", () => {
  const packageJson = JSON.parse(source("package.json"));
  const check = packageJson.scripts && packageJson.scripts.check || "";
  assert.match(check, /node --check dispatch_request_cancellation_policy\.js/);
  assert.match(check, /node --check dispatch_request_lifecycle_commands\.js/);
});
