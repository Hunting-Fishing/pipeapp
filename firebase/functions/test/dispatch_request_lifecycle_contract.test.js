"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");

function source(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

test("production entrypoint overrides createDispatchJob through R4 adapter", () => {
  const production = source("production_bootstrap.js");
  assert.match(production, /adaptDispatchRequestInput/);
  assert.match(production, /createDispatchJobWithRequestAdapter/);
  assert.match(
      production,
      /exports\.createDispatchJob\s*=\s*onCall\(/,
  );
  assert.match(
      production,
      /policyAcceptanceCommands\.requireCurrentPolicies\([\s\S]*createDispatchJobWithRequestAdapter/,
  );
  assert.match(production, /requestSchemaVersion/);
  assert.match(production, /serviceCodes/);
  assert.match(production, /contactPreference/);
  assert.match(production, /finalizeDispatchRequestAttachments/);
});

test("production entrypoint exports protected request upload and cancellation", () => {
  const production = source("production_bootstrap.js");
  assert.match(production, /createDispatchRequestAttachmentCommands/);
  assert.match(
      production,
      /exports\.authorizeDispatchRequestUpload\s*=\s*onCall\(/,
  );
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

  const publicChanges = lifecycle.match(
      /const publicChanges\s*=\s*\{([\s\S]*?)\n\s*\};/,
  );
  assert.ok(publicChanges, "publicChanges object must remain explicit");
  assert.doesNotMatch(publicChanges[1], /cancellationReason\s*:/);
});

test("Functions check command includes all R4 request modules", () => {
  const packageJson = JSON.parse(source("package.json"));
  const check = packageJson.scripts && packageJson.scripts.check || "";
  assert.match(check, /node --check dispatch_request_attachment_policy\.js/);
  assert.match(check, /node --check dispatch_request_attachment_commands\.js/);
  assert.match(check, /node --check dispatch_request_input_adapter\.js/);
  assert.match(check, /node --check dispatch_request_cancellation_policy\.js/);
  assert.match(check, /node --check dispatch_request_lifecycle_commands\.js/);
});
