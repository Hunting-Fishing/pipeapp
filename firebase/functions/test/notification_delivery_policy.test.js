"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  deliveryCopy,
  deliveryEventId,
  endpointDocumentId,
  invalidEndpointErrorCode,
  normalizeEndpointRegistration,
  routeForNotification,
} = require("../notification_delivery_policy");

test("notification endpoints are bounded and privately addressable", () => {
  const endpoint = normalizeEndpointRegistration({
    token: `token-${"a".repeat(80)}`,
    platform: "Android",
    installationId: "installation-12345",
  });
  assert.equal(endpoint.platform, "android");
  assert.match(endpointDocumentId("user-1", endpoint.token), /^[a-f0-9]{64}$/);
  assert.notEqual(endpointDocumentId("user-2", endpoint.token),
      endpointDocumentId("user-1", endpoint.token));
  assert.throws(() => normalizeEndpointRegistration({
    token: "short",
    platform: "android",
    installationId: "installation-12345",
  }), /Notification token/);
  assert.throws(() => normalizeEndpointRegistration({
    token: `token-${"a".repeat(80)}`,
    platform: "windows",
    installationId: "installation-12345",
  }), /supported/);
});

test("push copy never leaks private notification message content", () => {
  const copy = deliveryCopy({
    type: "message",
    title: "Private title from database",
    body: "Private message contents",
    message: "Private message contents",
    conversationId: "conversation_123",
  });
  assert.equal(copy.title, "New marketplace message");
  assert.equal(copy.body, "Open Pipe Buyer to view and reply.");
  assert.equal(copy.route, "/conversations/conversation_123");
  assert.equal(copy.critical, true);
});

test("notification routes fail closed to recognized deep links", () => {
  assert.equal(routeForNotification({route: "https://evil.example/path"}), "/");
  assert.equal(routeForNotification({route: "/admin/secret"}), "/");
  assert.equal(routeForNotification({listingId: "pipe-42"}),
      "/listings/pipe-42");
  assert.equal(routeForNotification({type: "auction", listingId: "pipe-42"}),
      "/auctions/pipe-42");
  assert.equal(routeForNotification({jobId: "job_42"}),
      "/dispatch/jobs/job_42");
  assert.match(deliveryEventId("user", "notification"), /^[a-f0-9]{64}$/);
});

test("wanted match notifications use safe copy and listing deep links", () => {
  const wantedOwnerCopy = deliveryCopy({
    type: "wanted_match",
    listingId: "supply_42",
    body: "Seller private data must not appear here.",
  });
  assert.equal(wantedOwnerCopy.title, "Possible wanted-ad match");
  assert.equal(wantedOwnerCopy.route, "/listings/supply_42");
  assert.equal(wantedOwnerCopy.body,
      "A Marketplace listing may match your wanted request.");

  const sellerCopy = deliveryCopy({
    type: "wanted_interest",
    listingId: "wanted_42",
  });
  assert.equal(sellerCopy.title, "Possible buyer interest");
  assert.equal(sellerCopy.route, "/listings/wanted_42");

  const contactCopy = deliveryCopy({
    type: "wanted_contact",
    listingId: "supply_42",
  });
  assert.equal(contactCopy.title, "Wanted match contact");
  assert.equal(contactCopy.route, "/listings/supply_42");
});

test("offer notifications use explicit safe copy and open the listing", () => {
  const copy = deliveryCopy({
    type: "offer",
    listingId: "listing_42",
    pushTitle: "New offer received",
    pushBody: "Tap to compare price, payment, pickup, and trucking.",
    body: "Private conditions must not be copied to the lock screen.",
  });
  assert.equal(copy.title, "New offer received");
  assert.equal(copy.body,
      "Tap to compare price, payment, pickup, and trucking.");
  assert.equal(copy.route, "/listings/listing_42");
  assert.equal(copy.critical, true);
});

test("only permanent messaging errors revoke an endpoint", () => {
  assert.equal(invalidEndpointErrorCode(
      "messaging/registration-token-not-registered"), true);
  assert.equal(invalidEndpointErrorCode("messaging/internal-error"), false);
  assert.equal(invalidEndpointErrorCode("messaging/server-unavailable"), false);
});
