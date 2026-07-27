"use strict";

const { AccountSecurityError } = require("./account_security");

const DELETION_CONFIRMATION = "DELETE MY ACCOUNT";
const DELETION_GRACE_DAYS = 14;
const EXPORT_RETENTION_DAYS = 7;
const DEVICE_HISTORY_DAYS = 180;
const RECENT_AUTH_SECONDS = 10 * 60;
const DEVICE_PLATFORMS = new Set([
  "android",
  "ios",
  "web",
  "windows",
  "macos",
  "linux",
  "unknown",
]);

function normalizeDeviceRegistration(data = {}) {
  const deviceId = String(data.deviceId || "").trim().toLowerCase();
  const label = String(data.label || "").trim().replace(/\s+/g, " ");
  const platform = String(data.platform || "").trim().toLowerCase();
  if (!/^[a-f0-9]{8}-[a-f0-9-]{27,55}$/.test(deviceId)) {
    throw new AccountSecurityError(
        "invalid-argument",
        "The app installation identifier is invalid. Refresh and try again.",
    );
  }
  if (label.length < 2 || label.length > 80) {
    throw new AccountSecurityError(
        "invalid-argument",
        "The device label must contain between 2 and 80 characters.",
    );
  }
  if (!DEVICE_PLATFORMS.has(platform)) {
    throw new AccountSecurityError(
        "invalid-argument",
        "The device platform is not supported.",
    );
  }
  return {deviceId, label, platform};
}

function requireRecentAuthentication(request, nowSeconds = Date.now() / 1000) {
  const authTime = Number(
    request &&
      request.auth &&
      request.auth.token &&
      request.auth.token.auth_time,
  );
  if (
    !Number.isFinite(authTime) ||
    authTime <= 0 ||
    nowSeconds - authTime > RECENT_AUTH_SECONDS ||
    authTime > nowSeconds + 30
  ) {
    throw new AccountSecurityError(
      "failed-precondition",
      "For security, sign in again before completing this account action.",
    );
  }
  return authTime;
}

function requireDeletionConfirmation(data = {}) {
  if (String(data.confirmation || "").trim() !== DELETION_CONFIRMATION) {
    throw new AccountSecurityError(
      "invalid-argument",
      `Enter ${DELETION_CONFIRMATION} to schedule account deletion.`,
    );
  }
}

function summarizeDeletionBlockers(results = {}) {
  const labels = {
    listings: "active marketplace or auction listings",
    offers: "open marketplace offers",
    marketplaceTransactions: "unfinished marketplace transactions",
    auctionTransactions: "unfinished auction settlements",
    dispatchJobs: "open Dispatch jobs",
    dispatchTransactions: "unfinished Dispatch deliveries",
    administratorRole: "an active administrator role",
  };
  return Object.entries(labels)
    .filter(([key]) => Number(results[key] || 0) > 0)
    .map(([key, label]) => ({ key, label, count: Number(results[key]) }));
}

function requireNoDeletionBlockers(results) {
  const blockers = summarizeDeletionBlockers(results);
  if (blockers.length > 0) {
    throw new AccountSecurityError(
      "failed-precondition",
      "Account deletion is blocked until these responsibilities are closed: " +
        blockers.map((item) => item.label).join(", ") +
        ".",
    );
  }
  return blockers;
}

module.exports = {
  DELETION_CONFIRMATION,
  DELETION_GRACE_DAYS,
  DEVICE_HISTORY_DAYS,
  EXPORT_RETENTION_DAYS,
  RECENT_AUTH_SECONDS,
  normalizeDeviceRegistration,
  requireDeletionConfirmation,
  requireNoDeletionBlockers,
  requireRecentAuthentication,
  summarizeDeletionBlockers,
};
