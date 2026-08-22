"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

function source(name) {
  return fs.readFileSync(path.join(__dirname, "..", name), "utf8");
}

test("production external-settlement commands do not inject test providers", () => {
  const bootstrap = source("bootstrap.js");
  assert.match(
      bootstrap,
      /const externalSettlementCommands = createExternalSettlementCommands\(admin\);/u,
  );
  assert.doesNotMatch(
      bootstrap,
      /createExternalSettlementCommands\(admin\s*,/u,
  );
});

test("production bootstrap overrides the core webhook with claimed handler", () => {
  const production = source("production_bootstrap.js");
  assert.match(
      production,
      /const claimedStripeWebhookHandler = createClaimedStripeWebhookHandler\(admin\);/u,
  );
  assert.match(
      production,
      /exports\.stripeMarketplaceWebhook\s*=\s*onRequest/u,
  );
  assert.match(production, /claimedStripeWebhookHandler/u);
});
