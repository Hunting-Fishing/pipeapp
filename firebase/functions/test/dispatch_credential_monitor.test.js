"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DEFAULT_REMINDER_DAYS,
  computeCredentialReminderState,
  notificationCopy,
  normalizedReminderDays,
} = require("../dispatch_credential_monitor");

function record({expiryDate, state = "self_reported_current"} = {}) {
  return {
    state,
    expiryDate,
    coverageLimit: 5000000,
    coverageCurrency: "CAD",
  };
}

function data({expiryDate, reminderDays = [90, 60, 30, 14, 7, 1], sent = {}} = {}) {
  return {
    ownerUid: "visual-carrier",
    dispatchCredentialReminderSettings: {
      enabled: true,
      reminderDays,
    },
    dispatchCredentialReminderSent: sent,
    dispatchCredentials: {
      general_liability_insurance: record({expiryDate}),
    },
  };
}

test("reminder days are bounded, unique and deterministic", () => {
  assert.deepEqual(
      normalizedReminderDays({reminderDays: [30, 7, 30, -1, 500, 14]}),
      [30, 14, 7],
  );
  assert.deepEqual(normalizedReminderDays({reminderDays: []}), [...DEFAULT_REMINDER_DAYS]);
});

test("credential inside 30-day window produces one closest reminder", () => {
  const now = Date.UTC(2026, 7, 18);
  const state = computeCredentialReminderState(
      data({expiryDate: "2026-09-07"}),
      now,
  );
  assert.equal(state.due.length, 1);
  assert.equal(state.due[0].marker, 30);
  assert.equal(state.due[0].daysRemaining, 20);
});

test("already-sent threshold does not repeat and next future threshold remains scheduled", () => {
  const now = Date.UTC(2026, 7, 18);
  const sent = {
    "general_liability_insurance|2026-09-07|30": "2026-08-18T00:00:00.000Z",
  };
  const state = computeCredentialReminderState(
      data({expiryDate: "2026-09-07", sent}),
      now,
  );
  assert.equal(state.due.length, 0);
  assert.equal(
      new Date(state.nextDueMs).toISOString().slice(0, 10),
      "2026-08-24",
  );
});

test("after the final threshold is sent the post-expiry checkpoint remains scheduled", () => {
  const now = Date.UTC(2026, 7, 19);
  const sent = {
    "general_liability_insurance|2026-08-20|1": "2026-08-19T00:00:00.000Z",
  };
  const state = computeCredentialReminderState(
      data({expiryDate: "2026-08-20", reminderDays: [1], sent}),
      now,
  );
  assert.equal(state.due.length, 0);
  assert.equal(
      new Date(state.nextDueMs).toISOString().slice(0, 10),
      "2026-08-21",
  );
});

test("expired credential generates a single expired reminder", () => {
  const now = Date.UTC(2026, 7, 18);
  const state = computeCredentialReminderState(
      data({expiryDate: "2026-08-17"}),
      now,
  );
  assert.equal(state.due.length, 1);
  assert.equal(state.due[0].marker, "expired");
  assert.match(notificationCopy(state.due[0]).title, /expired/i);
});

test("disabled reminders have no due work or next schedule", () => {
  const value = data({expiryDate: "2026-09-07"});
  value.dispatchCredentialReminderSettings.enabled = false;
  const state = computeCredentialReminderState(value, Date.UTC(2026, 7, 18));
  assert.equal(state.enabled, false);
  assert.deepEqual(state.due, []);
  assert.equal(state.nextDueMs, null);
});

test("non-current credential does not create expiry reminders", () => {
  const value = data({expiryDate: "2026-09-07"});
  value.dispatchCredentials.general_liability_insurance.state = "not_provided";
  const state = computeCredentialReminderState(value, Date.UTC(2026, 7, 18));
  assert.deepEqual(state.due, []);
  assert.equal(state.nextDueMs, null);
});
