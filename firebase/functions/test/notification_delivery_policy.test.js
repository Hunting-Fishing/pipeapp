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

test("only permanent messaging errors revoke an endpoint", () => {
  assert.equal(invalidEndpointErrorCode(
      "messaging/registration-token-not-registered"), true);
  assert.equal(invalidEndpointErrorCode("messaging/internal-error"), false);
  assert.equal(invalidEndpointErrorCode("messaging/server-unavailable"), false);
});

test("vendor & brand portal notifications use critical delivery, safe copy, and allowlisted routes", () => {
  const adminAlert = deliveryCopy({
    type: "shop_vendor_application",
    title: "Internal DB title with contact phone 555-0199",
    body: "Internal DB body with private notes",
    pushTitle: "New Brand / Vendor Request",
    pushBody: "Brandt Tractor requested to list products on Pipe Buyer.",
    route: "/admin/shop?tab=applications",
  });
  assert.equal(adminAlert.critical, true);
  assert.equal(adminAlert.route, "/admin/shop?tab=applications");
  assert.equal(adminAlert.title, "New Brand / Vendor Request");
  assert.equal(
      adminAlert.body,
      "Brandt Tractor requested to list products on Pipe Buyer.",
  );

  // Default fallback route and copy when pushTitle/route are omitted
  const defaultVendorAlert = deliveryCopy({
    type: "shop_vendor_application",
    body: "Must not leak arbitrary body",
  });
  assert.equal(defaultVendorAlert.critical, true);
  assert.equal(defaultVendorAlert.route, "/admin/shop?tab=applications");
  assert.equal(defaultVendorAlert.title, "New Brand / Vendor Request");
  assert.doesNotMatch(defaultVendorAlert.body, /Must not leak/);

  const statusUpdate = deliveryCopy({
    type: "shop_vendor_application_status",
    pushTitle: "Partner Application: Approved Partner",
    pushBody: "Open Pipe Buyer to view the latest update for Milwaukee.",
  });
  assert.equal(statusUpdate.critical, true);
  assert.equal(statusUpdate.route, "/shop/apply");
  assert.equal(statusUpdate.title, "Partner Application: Approved Partner");

  // Unrecognized admin routes still fail closed
  assert.equal(routeForNotification({route: "/admin/secret"}), "/");
});
