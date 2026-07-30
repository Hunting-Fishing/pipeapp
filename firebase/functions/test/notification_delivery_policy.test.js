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

test("only permanent messaging errors revoke an endpoint", () => {
  assert.equal(invalidEndpointErrorCode(
      "messaging/registration-token-not-registered"), true);
  assert.equal(invalidEndpointErrorCode("messaging/internal-error"), false);
  assert.equal(invalidEndpointErrorCode("messaging/server-unavailable"), false);
});
