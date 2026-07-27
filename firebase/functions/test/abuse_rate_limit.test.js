"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  RATE_LIMITS,
  rateLimitDocumentId,
  rateLimitSpec,
  requestFingerprint,
} = require("../abuse_rate_limit");

test("every protected command group has a bounded hourly policy", () => {
  assert.deepEqual(Object.keys(RATE_LIMITS).sort(), [
    "account", "administration", "auctions", "dispatch", "marketplace",
    "media",
    "messaging", "offers", "privacy", "reporting", "support",
  ]);
  for (const scope of Object.keys(RATE_LIMITS)) {
    const policy = rateLimitSpec(scope);
    assert.equal(policy.windowSeconds, 3600);
    assert.ok(policy.limit > 0 && policy.limit <= 1000);
  }
});

test("rate documents and request fingerprints are private deterministic hashes", () => {
  const documentId = rateLimitDocumentId("user-123", "offers", 123456);
  assert.equal(documentId.length, 64);
  assert.equal(documentId.includes("user-123"), false);
  const request = {
    data: {requestId: "retry-1", listingId: "listing-1"},
    rawRequest: {path: "/createMarketplaceOffer"},
  };
  assert.equal(
      requestFingerprint(request, "offers"),
      requestFingerprint(request, "offers"),
  );
  assert.notEqual(
      requestFingerprint(request, "offers"),
      requestFingerprint({...request, data: {...request.data, requestId: "2"}},
          "offers"),
  );
});
