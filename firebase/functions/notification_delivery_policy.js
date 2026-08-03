"use strict";

const crypto = require("node:crypto");

const supportedPlatforms = new Set(["android", "ios", "web"]);
const criticalTypes = new Set([
  "account_verification",
  "auction",
  "auction_settlement",
  "dispatch",
  "dispatch_award",
  "message",
  "moderation_decision",
  "offer",
  "support_response",
  "transaction",
]);

class NotificationDeliveryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "NotificationDeliveryError";
    this.code = code;
  }
}

function requireBoundedText(value, label, min, max) {
  const normalized = String(value || "").trim();
  if (normalized.length < min || normalized.length > max) {
    throw new NotificationDeliveryError(
        "invalid-argument",
        `${label} must contain ${min}-${max} characters.`,
    );
  }
  return normalized;
}

function normalizeEndpointRegistration(data = {}) {
  const token = requireBoundedText(data.token, "Notification token", 20, 4096);
  const platform = String(data.platform || "").trim().toLowerCase();
  if (!supportedPlatforms.has(platform)) {
    throw new NotificationDeliveryError(
        "invalid-argument",
        "Notifications are supported on Android, iOS, and web.",
    );
  }
  const installationId = requireBoundedText(
      data.installationId,
      "Installation identifier",
      8,
      160,
  );
  return {token, platform, installationId};
}

function endpointDocumentId(uid, token) {
  return crypto.createHash("sha256")
      .update(`${String(uid).trim()}|${String(token).trim()}`)
      .digest("hex");
}

function deliveryEventId(uid, notificationId) {
  return crypto.createHash("sha256")
      .update(`${String(uid).trim()}|${String(notificationId).trim()}`)
      .digest("hex");
}

function safeIdentifier(value) {
  const normalized = String(value || "").trim();
  return /^[A-Za-z0-9_-]{1,160}$/.test(normalized) ? normalized : "";
}

function routeForNotification(data = {}) {
  const explicit = String(data.route || "").trim();
  if (/^\/(listings|auctions|profiles|conversations)\/[A-Za-z0-9_-]{1,160}$/.test(explicit) ||
      /^\/dispatch\/jobs\/[A-Za-z0-9_-]{1,160}$/.test(explicit)) {
    return explicit;
  }
  const conversationId = safeIdentifier(data.conversationId);
  if (conversationId) return `/conversations/${conversationId}`;
  const jobId = safeIdentifier(data.jobId || data.dispatchJobId);
  if (jobId) return `/dispatch/jobs/${jobId}`;
  const listingId = safeIdentifier(data.listingId);
  if (listingId) {
    const type = String(data.type || "").toLowerCase();
    return type.includes("auction") ?
      `/auctions/${listingId}` : `/listings/${listingId}`;
  }
  return "/";
}

function deliveryCopy(data = {}) {
  const type = String(data.type || "activity").trim().toLowerCase();
  const copy = {
    message: ["New marketplace message", "Open Pipe Buyer to view and reply."],
    offer: ["Offer update", "Open Pipe Buyer to review the latest offer activity."],
    transaction: ["Transaction update", "A marketplace transaction needs your attention."],
    auction: ["Auction update", "Open Pipe Buyer to review the latest auction activity."],
    auction_settlement: ["Auction settlement update", "A settlement step needs your attention."],
    dispatch: ["Dispatch update", "Open Pipe Buyer to review the trucking job activity."],
    dispatch_award: ["Dispatch quote selected", "A Dispatch award needs your attention."],
    account_verification: ["Account verification update", "Open your account to review the decision."],
    moderation_decision: ["Report review update", "A report or appeal has been reviewed."],
    support_response: ["Support response", "Pipe Buyer Support replied to your case."],
    new_device: ["New device remembered", "Review your account device history if this was not you."],
    new_listing_match: ["New matching listing", "A new listing matches one of your saved watches."],
    wanted_match: ["Possible wanted-ad match", "A Marketplace listing may match your wanted request."],
    wanted_interest: ["Possible buyer interest", "A wanted ad may match one of your listings."],
    wanted_contact: ["Wanted match contact", "A match participant wants to continue the conversation."],
    seller_new_listing: ["Saved seller posted", "A seller you follow added a new listing."],
  }[type] || ["Pipe Buyer update", "Open Pipe Buyer to review your latest activity."];
  const title = String(data.pushTitle || copy[0]).trim().slice(0, 80) || copy[0];
  const body = String(data.pushBody || copy[1]).trim().slice(0, 160) || copy[1];
  return {
    title,
    body,
    route: routeForNotification(data),
    type,
    critical: criticalTypes.has(type),
  };
}

function invalidEndpointErrorCode(code) {
  return new Set([
    "messaging/invalid-argument",
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
    "messaging/mismatched-credential",
  ]).has(String(code || ""));
}

module.exports = {
  NotificationDeliveryError,
  deliveryCopy,
  deliveryEventId,
  endpointDocumentId,
  invalidEndpointErrorCode,
  normalizeEndpointRegistration,
  routeForNotification,
};
