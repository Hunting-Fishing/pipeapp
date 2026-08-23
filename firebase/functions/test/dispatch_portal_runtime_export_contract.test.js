"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

test("client-exposed Dispatch Checkout and Portal session both use live Portal runtime gate", () => {
  const source = fs.readFileSync(
      path.join(__dirname, "../bootstrap.js"),
      "utf8",
  );

  assert.match(source, /createDispatchSubscriptionPortalRuntimeGate/u);
  assert.match(source, /actionLabel: "Dispatch subscription checkout"/u);
  assert.match(source, /actionLabel: "Dispatch billing management"/u);
  assert.match(
      source,
      /exports\.createDispatchSubscriptionCheckout = onCall\([\s\S]*?createDispatchSubscriptionCheckout/u,
  );
  assert.match(
      source,
      /exports\.createDispatchBillingPortalSession = onCall\([\s\S]*?createDispatchBillingPortalSession/u,
  );
});
