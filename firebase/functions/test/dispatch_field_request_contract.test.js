"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = (relativePath) =>
  fs.readFileSync(path.join(root, relativePath), "utf8");

test("field-service requests are received as drafts outside freight matching", () => {
  const commands = source("dispatch_field_request_commands.js");
  assert.match(commands, /requestPath: "field_service"/);
  assert.match(commands, /routeRelevant: false/);
  assert.match(commands, /status: "draft"/);
  assert.match(commands, /dispatchRequestStatus: "service_request_received"/);
  assert.doesNotMatch(commands, /buildDispatchRouteState/);
  assert.doesNotMatch(commands, /accepting_carrier_bids/);
});

test("field-service request keeps exact site details on the private record", () => {
  const commands = source("dispatch_field_request_commands.js");
  assert.match(commands, /pickupPoint: pointValue/);
  assert.match(commands, /workSiteAddress/);
  assert.match(commands, /workSiteAccessNotes/);
  assert.match(commands, /contactPreference: metadata\.contactPreference/);
});

test("production wrapper routes field create and edit without changing callable names", () => {
  const production = source("production_bootstrap.js");
  assert.match(production, /createDispatchFieldRequestCommands/);
  assert.match(production, /createFieldServiceRequest/);
  assert.match(production, /updateDispatchJobWithRequestRouter/);
  assert.match(production, /exports\.updateDispatchJob\s*=\s*onCall\(/);
  assert.match(production, /dispatchFieldRequestCommands\.updateFieldServiceRequest/);
  assert.doesNotMatch(production, /exports\.updateDispatchFieldRequest\s*=/);
});

test("Functions check includes the field-service command module", () => {
  const packageJson = JSON.parse(source("package.json"));
  assert.match(
      packageJson.scripts.check,
      /node --check dispatch_field_request_commands\.js/,
  );
});
