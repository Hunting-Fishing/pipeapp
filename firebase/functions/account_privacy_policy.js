"use strict";

const { AccountSecurityError } = require("./account_security");

const DELETION_CONFIRMATION = "DELETE MY ACCOUNT";
const DELETION_GRACE_DAYS = 14;
const EXPORT_RETENTION_DAYS = 7;
const RECENT_AUTH_SECONDS = 10 * 60;

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
  EXPORT_RETENTION_DAYS,
  RECENT_AUTH_SECONDS,
  requireDeletionConfirmation,
  requireNoDeletionBlockers,
  requireRecentAuthentication,
  summarizeDeletionBlockers,
};
