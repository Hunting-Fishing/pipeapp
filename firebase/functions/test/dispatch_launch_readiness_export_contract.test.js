"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

test("Dispatch launch readiness snapshot is a protected non-secret admin callable", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "../bootstrap.js"),
      "utf8",
  );
  assert.match(
      source,
      /exports\.getDispatchSubscriptionLaunchReadiness = onCall\(\s*protectedCallableOptions,\s*dispatchSubscriptionLaunchReadinessCommands\.getDispatchSubscriptionLaunchReadiness/u,
  );
  assert.doesNotMatch(
      source,
      /exports\.getDispatchSubscriptionLaunchReadiness = onCall\(\s*stripeCallableOptions/u,
  );
});

test("Functions check includes centralized Dispatch readiness policy", () => {
  const packageJson = fs.readFileSync(
      path.join(__dirname, "../package.json"),
      "utf8",
  );
  assert.match(packageJson, /node --check dispatch_subscription_readiness_policy\.js/u);
});
