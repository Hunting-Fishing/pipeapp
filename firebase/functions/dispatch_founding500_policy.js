"use strict";

const FOUNDING500_CODE = "FOUNDING500";
const FOUNDING500_PROGRAM_ID = "dispatch_founding500_2026";
const FOUNDING500_POLICY_REVISION = "2026-08-23-founding500-v2-trial";
const FOUNDING500_MAX_CLAIMS = 500;
const FOUNDING500_TRIAL_MONTHS = 6;

function normalizeDispatchLaunchCode(value) {
  return String(value || "").trim().toUpperCase();
}

function isFounding500Code(value) {
  return normalizeDispatchLaunchCode(value) === FOUNDING500_CODE;
}

function founding500PriorSubscriptionExists(state = {}) {
  const subscriptionId = String(state.stripeSubscriptionId || "").trim();
  if (subscriptionId.startsWith("sub_")) return true;
  const retired = Array.isArray(state.retiredStripeSubscriptionIds) ?
    state.retiredStripeSubscriptionIds : [];
  if (retired.some((value) => String(value || "").startsWith("sub_"))) {
    return true;
  }
  const status = String(state.status || "").trim().toLowerCase();
  return new Set([
    "active",
    "trialing",
    "past_due",
    "unpaid",
    "canceled",
  ]).has(status);
}

function calendarMonthsFromUnixMs(nowMs, months) {
  const sourceMs = Number(nowMs);
  if (!Number.isFinite(sourceMs)) {
    throw new TypeError("Founding 500 trial clock is invalid.");
  }
  const source = new Date(sourceMs);
  const sourceMonth = source.getUTCMonth();
  const absoluteMonth = sourceMonth + Number(months);
  const targetYear = source.getUTCFullYear() + Math.floor(absoluteMonth / 12);
  const targetMonth = ((absoluteMonth % 12) + 12) % 12;
  const lastTargetDay = new Date(Date.UTC(
      targetYear,
      targetMonth + 1,
      0,
  )).getUTCDate();
  const targetDay = Math.min(source.getUTCDate(), lastTargetDay);
  return Date.UTC(
      targetYear,
      targetMonth,
      targetDay,
      source.getUTCHours(),
      source.getUTCMinutes(),
      source.getUTCSeconds(),
  );
}

function founding500TrialEndUnix(nowMs = Date.now()) {
  return Math.floor(
      calendarMonthsFromUnixMs(nowMs, FOUNDING500_TRIAL_MONTHS) / 1000,
  );
}

module.exports = {
  FOUNDING500_CODE,
  FOUNDING500_MAX_CLAIMS,
  FOUNDING500_POLICY_REVISION,
  FOUNDING500_PROGRAM_ID,
  FOUNDING500_TRIAL_MONTHS,
  calendarMonthsFromUnixMs,
  founding500PriorSubscriptionExists,
  founding500TrialEndUnix,
  isFounding500Code,
  normalizeDispatchLaunchCode,
};
