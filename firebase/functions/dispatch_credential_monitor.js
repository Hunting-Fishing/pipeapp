"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");

const DEFAULT_REMINDER_DAYS = Object.freeze([90, 60, 30, 14, 7, 1]);
const MAX_REMINDER_DAYS = 365;
const DAY_MS = 24 * 60 * 60 * 1000;

const credentialLabels = Object.freeze({
  general_liability_insurance: "General liability insurance",
  cargo_insurance: "Cargo insurance",
  commercial_auto_insurance: "Commercial auto insurance",
  workers_compensation: "Workers compensation",
  operating_authority: "Operating authority",
  safety_certificate: "Safety certificate",
  pilot_escort_certification: "Pilot / escort certification",
  crane_rigging_qualification: "Crane / rigging qualification",
});

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch credential reminder command failed", error);
      throw new HttpsError(
          "internal",
          "Credential reminder settings could not be synchronized.",
      );
    }
  };
}

function normalizedReminderDays(settings = {}) {
  const raw = Array.isArray(settings.reminderDays) ?
    settings.reminderDays : DEFAULT_REMINDER_DAYS;
  const values = raw
      .map((value) => Number(value))
      .filter((value) => Number.isInteger(value) && value >= 1 && value <= MAX_REMINDER_DAYS);
  const unique = [...new Set(values)].sort((a, b) => b - a);
  return unique.length > 0 ? unique : [...DEFAULT_REMINDER_DAYS];
}

function dateOnlyUtcMs(value) {
  const match = String(value || "").trim().match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const time = Date.UTC(year, month - 1, day);
  const date = new Date(time);
  if (date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 ||
      date.getUTCDate() !== day) return null;
  return time;
}

function startOfUtcDayMs(value) {
  const date = new Date(value);
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function reminderKey(typeCode, expiryDate, marker) {
  return `${typeCode}|${expiryDate}|${marker}`;
}

function sentKeys(data = {}) {
  const raw = data.dispatchCredentialReminderSent;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  return {...raw};
}

function credentialEntries(data = {}) {
  const raw = data.dispatchCredentials;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return [];
  return Object.entries(raw)
      .filter(([typeCode, record]) => typeCode && record && typeof record === "object")
      .map(([typeCode, record]) => ({typeCode, record}));
}

function dueReminderForCredential({typeCode, record, reminderDays, sent, nowMs}) {
  if (String(record.state || "") !== "self_reported_current") return null;
  const expiryDate = String(record.expiryDate || "").trim();
  const expiryMs = dateOnlyUtcMs(expiryDate);
  if (expiryMs == null) return null;
  const todayMs = startOfUtcDayMs(nowMs);
  const daysRemaining = Math.ceil((expiryMs - todayMs) / DAY_MS);
  if (daysRemaining < 0) {
    const key = reminderKey(typeCode, expiryDate, "expired");
    return sent[key] ? null : {key, typeCode, expiryDate, daysRemaining, marker: "expired"};
  }
  const dueThresholds = reminderDays
      .filter((days) => daysRemaining <= days)
      .sort((a, b) => a - b);
  if (dueThresholds.length === 0) return null;
  const threshold = dueThresholds[0];
  const key = reminderKey(typeCode, expiryDate, threshold);
  if (sent[key]) return null;
  return {key, typeCode, expiryDate, daysRemaining, marker: threshold};
}

function computeCredentialReminderState(data = {}, nowMs = Date.now(), sentOverride = null) {
  const settings = data.dispatchCredentialReminderSettings || {};
  const enabled = settings.enabled === true;
  const reminderDays = normalizedReminderDays(settings);
  const sent = sentOverride || sentKeys(data);
  if (!enabled) {
    return {enabled: false, reminderDays, due: [], nextDueMs: null, sent};
  }

  const entries = credentialEntries(data);
  const due = [];
  let nextDueMs = null;
  const todayMs = startOfUtcDayMs(nowMs);

  for (const {typeCode, record} of entries) {
    const currentDue = dueReminderForCredential({
      typeCode,
      record,
      reminderDays,
      sent,
      nowMs,
    });
    if (currentDue) due.push(currentDue);

    if (String(record.state || "") !== "self_reported_current") continue;
    const expiryDate = String(record.expiryDate || "").trim();
    const expiryMs = dateOnlyUtcMs(expiryDate);
    if (expiryMs == null) continue;

    if (expiryMs < todayMs) {
      const expiredKey = reminderKey(typeCode, expiryDate, "expired");
      if (!sent[expiredKey]) nextDueMs = nowMs;
      continue;
    }

    for (const threshold of reminderDays) {
      const key = reminderKey(typeCode, expiryDate, threshold);
      if (sent[key]) continue;
      const dueMs = expiryMs - (threshold * DAY_MS);
      const candidate = dueMs <= nowMs ? nowMs : dueMs;
      if (nextDueMs == null || candidate < nextDueMs) nextDueMs = candidate;
    }
  }

  if (due.length > 0) nextDueMs = nowMs;
  return {enabled: true, reminderDays, due, nextDueMs, sent};
}

function notificationId(uid, reminder) {
  const digest = crypto.createHash("sha256")
      .update(`${uid}|${reminder.key}`)
      .digest("hex")
      .slice(0, 32);
  return `dispatch_credential_${digest}`;
}

function notificationCopy(reminder) {
  const label = credentialLabels[reminder.typeCode] || "Dispatch credential";
  if (reminder.marker === "expired") {
    return {
      title: `${label} expired`,
      body: "Update the credential record before relying on it for Dispatch matching.",
    };
  }
  const days = Number(reminder.daysRemaining);
  return {
    title: `${label} expiry reminder`,
    body: days === 0 ?
      "This credential expires today." :
      `This credential expires in ${days} day${days === 1 ? "" : "s"}.`,
  };
}

function createDispatchCredentialMonitor(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function writeSchedule(reference, state) {
    const payload = {
      dispatchCredentialReminderScheduleUpdatedAt: FieldValue.serverTimestamp(),
    };
    if (state.enabled && state.nextDueMs != null) {
      payload.dispatchCredentialNextReminderAt = Timestamp.fromMillis(state.nextDueMs);
    } else {
      payload.dispatchCredentialNextReminderAt = FieldValue.delete();
    }
    await reference.set(payload, {merge: true});
  }

  const syncDispatchCredentialReminderSchedule = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
    const reference = db.collection("business_private").doc(identity.uid);
    const snapshot = await reference.get();
    if (!snapshot.exists) {
      throw new HttpsError("failed-precondition", "Save credential settings before enabling reminders.");
    }
    const state = computeCredentialReminderState(snapshot.data() || {}, Date.now());
    await writeSchedule(reference, state);
    return {
      enabled: state.enabled,
      nextReminderAt: state.nextDueMs == null ? "" : new Date(state.nextDueMs).toISOString(),
    };
  });

  async function processDocument(document, nowMs) {
    const data = document.data() || {};
    const state = computeCredentialReminderState(data, nowMs);
    if (!state.enabled) {
      await writeSchedule(document.ref, state);
      return {notifications: 0};
    }

    const mergedSent = {...state.sent};
    let notifications = 0;
    for (const reminder of state.due) {
      const copy = notificationCopy(reminder);
      const uid = String(data.ownerUid || document.id).trim() || document.id;
      const id = notificationId(uid, reminder);
      await db.collection("users").doc(uid).collection("notifications").doc(id).set({
        recipientUid: uid,
        type: "dispatch_credential",
        pushTitle: copy.title,
        pushBody: copy.body,
        externalDelivery: true,
        credentialType: reminder.typeCode,
        expiryDate: reminder.expiryDate,
        reminderMarker: String(reminder.marker),
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      mergedSent[reminder.key] = new Date(nowMs).toISOString();
      notifications += 1;
    }

    const nextState = computeCredentialReminderState(data, nowMs, mergedSent);
    const update = {
      dispatchCredentialReminderSent: mergedSent,
      dispatchCredentialReminderScheduleUpdatedAt: FieldValue.serverTimestamp(),
    };
    if (nextState.enabled && nextState.nextDueMs != null) {
      update.dispatchCredentialNextReminderAt = Timestamp.fromMillis(nextState.nextDueMs);
    } else {
      update.dispatchCredentialNextReminderAt = FieldValue.delete();
    }
    await document.ref.set(update, {merge: true});
    return {notifications};
  }

  async function monitorCredentialReminders() {
    const now = Timestamp.now();
    const snapshot = await db.collection("business_private")
        .where("dispatchCredentialNextReminderAt", "<=", now)
        .limit(200)
        .get();
    let processed = 0;
    let notifications = 0;
    for (const document of snapshot.docs) {
      const result = await processDocument(document, now.toMillis());
      processed += 1;
      notifications += result.notifications;
    }
    return {processed, notifications};
  }

  return {
    monitorCredentialReminders,
    syncDispatchCredentialReminderSchedule,
  };
}

module.exports = {
  DEFAULT_REMINDER_DAYS,
  computeCredentialReminderState,
  createDispatchCredentialMonitor,
  notificationCopy,
  normalizedReminderDays,
};
