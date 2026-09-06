"use strict";

const {FieldPath, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {
  BILLING_STATUSES,
  OUTREACH_STATUSES,
  PUBLICATION_STATUSES,
  STAFF_ROLES,
  VERIFICATION_STATUSES,
  buildPublicEntry,
  defaultCompanyWorkflow,
  isPublicationEligible,
  normalizedCompanyName,
  stringList,
  text,
} = require("./yellow_pages_policy");

class YellowPagesError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "YellowPagesError";
    this.code = code;
  }
}

const PRIVATE_COMPANIES = "yellow_pages_companies";
const PRIVATE_CONTACT_EVENTS = "yellow_pages_contact_events";
const STAFF = "yellow_pages_staff";
const AUDIT = "yellow_pages_audit_events";
const PUBLIC_ENTRIES = "yellow_pages_public_entries";

function secondFactor(token) {
  const value = token && token.firebase && token.firebase.sign_in_second_factor;
  return typeof value === "string" && value.trim().length > 0;
}

function jsonSafe(value) {
  if (value == null) return value;
  if (typeof value.toDate === "function") return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(jsonSafe);
  if (typeof value === "object") {
    return Object.fromEntries(
        Object.entries(value).map(([key, child]) => [key, jsonSafe(child)]),
    );
  }
  return value;
}

function pageSize(value, fallback = 50) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.max(1, Math.min(100, Math.trunc(number)));
}

function sourceReferences(value) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 20).map((entry) => ({
    sourceType: text(entry && entry.sourceType, 80),
    sourceName: text(entry && entry.sourceName, 160),
    sourceUrl: text(entry && entry.sourceUrl, 1000),
    sourceExternalId: text(entry && entry.sourceExternalId, 200),
    observedAt: text(entry && entry.observedAt, 80),
  })).filter((entry) => entry.sourceName || entry.sourceUrl || entry.sourceExternalId);
}

function parsePaidThrough(value) {
  if (value == null || value === "") return null;
  const date = value instanceof Date ? value : new Date(String(value));
  if (Number.isNaN(date.getTime())) {
    throw new YellowPagesError("invalid-argument", "A valid paid-through date is required.");
  }
  return Timestamp.fromDate(date);
}

async function resolveActor(db, context) {
  if (!context || !context.auth) return {authorized: false, reason: "signed_out"};
  const uid = context.auth.uid;
  const token = context.auth.token || {};
  const verifiedEmail = token.email_verified === true;
  const mfa = secondFactor(token);

  if (token.admin === true && token.role === "administrator") {
    if (!verifiedEmail) return {authorized: false, reason: "verified_email_required"};
    if (!mfa) return {authorized: false, reason: "mfa_required"};
    return {authorized: true, uid, role: "administrator", isAdmin: true};
  }

  const claimRole = text(token.yellowPagesRole, 40).toLowerCase();
  if (!STAFF_ROLES.has(claimRole)) return {authorized: false, reason: "role_missing"};
  if (!verifiedEmail) return {authorized: false, reason: "verified_email_required"};
  if (!mfa) return {authorized: false, reason: "mfa_required"};

  const roster = await db.collection(STAFF).doc(uid).get();
  const rosterData = roster.data() || {};
  if (!roster.exists || rosterData.active !== true || rosterData.role !== claimRole) {
    return {authorized: false, reason: "roster_inactive"};
  }
  return {
    authorized: true,
    uid,
    role: claimRole,
    isAdmin: false,
  };
}

async function requireActor(db, context, roles = ["agent", "manager", "administrator"]) {
  if (!context || !context.auth) {
    throw new YellowPagesError("unauthenticated", "Sign in to the PipeBuyer Contact Center.");
  }
  const actor = await resolveActor(db, context);
  if (!actor.authorized || !roles.includes(actor.role)) {
    const message = actor.reason === "mfa_required" ?
      "Multi-factor authentication is required for Contact Center access." :
      "Your account is not authorized for this Contact Center action.";
    throw new YellowPagesError("permission-denied", message);
  }
  return actor;
}

async function audit(db, actor, action, companyId, details = {}) {
  await db.collection(AUDIT).add({
    schemaVersion: 1,
    actorUid: actor.uid,
    actorRole: actor.role,
    action,
    companyId: companyId || null,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function getCompanyForActor(db, actor, companyId) {
  const id = text(companyId, 200);
  if (!id) throw new YellowPagesError("invalid-argument", "A company ID is required.");
  const snapshot = await db.collection(PRIVATE_COMPANIES).doc(id).get();
  if (!snapshot.exists) throw new YellowPagesError("not-found", "Company record not found.");
  const company = snapshot.data() || {};
  if (actor.role === "agent" && company.assignedAgentUid !== actor.uid) {
    throw new YellowPagesError("permission-denied", "This company is not assigned to your queue.");
  }
  return {id, snapshot, company};
}

async function reconcilePublicProjection(db, companyId) {
  const companyRef = db.collection(PRIVATE_COMPANIES).doc(companyId);
  const publicRef = db.collection(PUBLIC_ENTRIES).doc(companyId);
  await db.runTransaction(async (transaction) => {
    const companySnapshot = await transaction.get(companyRef);
    if (!companySnapshot.exists) {
      transaction.delete(publicRef);
      return;
    }
    const company = companySnapshot.data() || {};
    const entry = buildPublicEntry(company, companyId, FieldValue.serverTimestamp());
    if (entry) transaction.set(publicRef, entry);
    else transaction.delete(publicRef);
  });
}

function createYellowPagesCommands({db, auth}) {
  if (!db || !auth) throw new Error("Yellow Pages commands require Firestore and Auth.");

  return {
    async getAccess(data, context) {
      if (!context || !context.auth) {
        return {authorized: false, reason: "signed_out"};
      }
      const actor = await resolveActor(db, context);
      return {
        authorized: actor.authorized === true,
        role: actor.authorized ? actor.role : null,
        reason: actor.authorized ? null : actor.reason,
      };
    },

    async listPublic(data) {
      const limit = pageSize(data && data.pageSize, 40);
      const cursor = text(data && data.cursor, 200);
      let query = db.collection(PUBLIC_ENTRIES)
          .orderBy(FieldPath.documentId())
          .limit(limit + 1);
      if (cursor) query = query.startAfter(cursor);
      const snapshot = await query.get();
      const docs = snapshot.docs.slice(0, limit);
      return {
        entries: docs.map((doc) => ({id: doc.id, ...jsonSafe(doc.data())})),
        nextCursor: snapshot.docs.length > limit ? docs[docs.length - 1].id : null,
      };
    },

    async getPublic(data) {
      const companyId = text(data && data.companyId, 200);
      if (!companyId) throw new YellowPagesError("invalid-argument", "A company ID is required.");
      const snapshot = await db.collection(PUBLIC_ENTRIES).doc(companyId).get();
      if (!snapshot.exists) throw new YellowPagesError("not-found", "Yellow Pages listing not found.");
      return {id: snapshot.id, ...jsonSafe(snapshot.data())};
    },

    async listCompanies(data, context) {
      const actor = await requireActor(db, context);
      const limit = pageSize(data && data.pageSize, 50);
      const cursor = text(data && data.cursor, 200);
      const dimension = text(data && data.filterDimension, 40);
      const value = text(data && data.filterValue, 80).toLowerCase();

      let query = db.collection(PRIVATE_COMPANIES);
      if (actor.role === "agent") {
        query = query.where("assignedAgentUid", "==", actor.uid);
      } else if (dimension) {
        const allowed = {
          outreach: ["outreachStatus", OUTREACH_STATUSES],
          verification: ["verificationStatus", VERIFICATION_STATUSES],
          billing: ["billingStatus", BILLING_STATUSES],
          publication: ["publicationStatus", PUBLICATION_STATUSES],
        };
        const rule = allowed[dimension];
        if (!rule || !rule[1].has(value)) {
          throw new YellowPagesError("invalid-argument", "The requested company filter is invalid.");
        }
        query = query.where(rule[0], "==", value);
      }
      query = query.orderBy(FieldPath.documentId()).limit(limit + 1);
      if (cursor) query = query.startAfter(cursor);
      const snapshot = await query.get();
      const docs = snapshot.docs.slice(0, limit);
      return {
        companies: docs.map((doc) => ({id: doc.id, ...jsonSafe(doc.data())})),
        nextCursor: snapshot.docs.length > limit ? docs[docs.length - 1].id : null,
      };
    },

    async getCompany(data, context) {
      const actor = await requireActor(db, context);
      const record = await getCompanyForActor(db, actor, data && data.companyId);
      return {id: record.id, ...jsonSafe(record.company)};
    },

    async upsertCompany(data, context) {
      const actor = await requireActor(db, context, ["manager", "administrator"]);
      const payload = (data && data.company) || {};
      const companyName = text(payload.companyName, 200);
      if (!companyName) throw new YellowPagesError("invalid-argument", "Company name is required.");
      const requestedId = text(data && data.companyId, 200);
      const ref = requestedId ?
        db.collection(PRIVATE_COMPANIES).doc(requestedId) :
        db.collection(PRIVATE_COMPANIES).doc();
      const existing = await ref.get();
      const now = FieldValue.serverTimestamp();
      const writable = {
        schemaVersion: 1,
        companyName,
        normalizedCompanyName: normalizedCompanyName(companyName),
        website: text(payload.website, 500),
        countryCode: text(payload.countryCode, 8).toUpperCase(),
        regionCode: text(payload.regionCode, 80),
        city: text(payload.city, 120),
        postalCode: text(payload.postalCode, 40),
        streetAddress: text(payload.streetAddress, 300),
        mainPhone: text(payload.mainPhone, 80),
        generalEmail: text(payload.generalEmail, 254),
        publicPhone: text(payload.publicPhone, 80),
        publicEmail: text(payload.publicEmail, 254),
        categories: stringList(payload.categories, 30, 120),
        services: stringList(payload.services, 60, 160),
        description: text(payload.description, 2500),
        sourceReferences: sourceReferences(payload.sourceReferences),
        updatedAt: now,
        updatedByUid: actor.uid,
      };
      if (!existing.exists) {
        Object.assign(writable, defaultCompanyWorkflow(), {
          assignedAgentUid: null,
          paidThrough: null,
          verifiedAt: null,
          verifiedByUid: null,
          publishedAt: null,
          publishedByUid: null,
          createdAt: now,
          createdByUid: actor.uid,
        });
      }
      await ref.set(writable, {merge: existing.exists});
      await audit(db, actor, existing.exists ? "company_updated" : "company_created", ref.id);
      await reconcilePublicProjection(db, ref.id);
      return {companyId: ref.id};
    },

    async assignCompany(data, context) {
      const actor = await requireActor(db, context, ["manager", "administrator"]);
      const companyId = text(data && data.companyId, 200);
      const assignedAgentUid = text(data && data.assignedAgentUid, 200);
      if (!companyId) throw new YellowPagesError("invalid-argument", "A company ID is required.");
      if (assignedAgentUid) {
        const staff = await db.collection(STAFF).doc(assignedAgentUid).get();
        const staffData = staff.data() || {};
        if (!staff.exists || staffData.active !== true || !STAFF_ROLES.has(staffData.role)) {
          throw new YellowPagesError("failed-precondition", "The selected employee is not active in the Contact Center.");
        }
      }
      const ref = db.collection(PRIVATE_COMPANIES).doc(companyId);
      const current = await ref.get();
      if (!current.exists) throw new YellowPagesError("not-found", "Company record not found.");
      const update = {
        assignedAgentUid: assignedAgentUid || null,
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
      };
      const currentData = current.data() || {};
      if (!currentData.doNotContact && currentData.outreachStatus === "not_contacted" && assignedAgentUid) {
        update.outreachStatus = "assigned";
      }
      await ref.update(update);
      await audit(db, actor, "company_assignment_changed", companyId, {assignedAgentUid: assignedAgentUid || null});
      return {companyId, assignedAgentUid: assignedAgentUid || null};
    },

    async recordContactEvent(data, context) {
      const actor = await requireActor(db, context);
      const record = await getCompanyForActor(db, actor, data && data.companyId);
      if (record.company.doNotContact === true) {
        throw new YellowPagesError("failed-precondition", "This company is on the Do Not Contact list.");
      }
      const eventType = text(data && data.eventType, 80);
      const disposition = text(data && data.disposition, 120);
      const summary = text(data && data.summary, 3000);
      if (!eventType) throw new YellowPagesError("invalid-argument", "A contact event type is required.");
      const nextFollowUpRaw = data && data.nextFollowUpAt;
      const nextFollowUpAt = nextFollowUpRaw ? parsePaidThrough(nextFollowUpRaw) : null;
      const event = await db.collection(PRIVATE_CONTACT_EVENTS).add({
        schemaVersion: 1,
        companyId: record.id,
        actorUid: actor.uid,
        actorRole: actor.role,
        eventType,
        disposition,
        summary,
        contactId: text(data && data.contactId, 200) || null,
        nextFollowUpAt,
        createdAt: FieldValue.serverTimestamp(),
      });
      const outreachStatus = nextFollowUpAt ? "follow_up" : "attempted";
      await record.snapshot.ref.update({
        outreachStatus,
        lastContactAt: FieldValue.serverTimestamp(),
        lastContactByUid: actor.uid,
        nextFollowUpAt,
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
      });
      return {eventId: event.id, outreachStatus};
    },

    async setDoNotContact(data, context) {
      const actor = await requireActor(db, context);
      const enabled = data && data.enabled === true;
      if (!enabled && actor.role !== "administrator") {
        throw new YellowPagesError("permission-denied", "Only an administrator can remove Do Not Contact status.");
      }
      const record = await getCompanyForActor(db, actor, data && data.companyId);
      const reason = text(data && data.reason, 1000);
      if (enabled && !reason) {
        throw new YellowPagesError("invalid-argument", "Record the reason for Do Not Contact status.");
      }
      await record.snapshot.ref.update({
        doNotContact: enabled,
        doNotContactReason: enabled ? reason : null,
        outreachStatus: enabled ? "do_not_contact" : "not_contacted",
        nextFollowUpAt: null,
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
      });
      await audit(db, actor, enabled ? "do_not_contact_set" : "do_not_contact_removed", record.id, {reason});
      return {companyId: record.id, doNotContact: enabled};
    },

    async reviewVerification(data, context) {
      const actor = await requireActor(db, context, ["manager", "administrator"]);
      const companyId = text(data && data.companyId, 200);
      const status = text(data && data.status, 40).toLowerCase();
      if (!VERIFICATION_STATUSES.has(status)) {
        throw new YellowPagesError("invalid-argument", "The verification status is invalid.");
      }
      const ref = db.collection(PRIVATE_COMPANIES).doc(companyId);
      const snapshot = await ref.get();
      if (!snapshot.exists) throw new YellowPagesError("not-found", "Company record not found.");
      const update = {
        verificationStatus: status,
        verificationReviewNote: text(data && data.reviewNote, 2000),
        verifiedAt: status === "verified" ? FieldValue.serverTimestamp() : null,
        verifiedByUid: status === "verified" ? actor.uid : null,
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
      };
      await ref.update(update);
      await audit(db, actor, "verification_reviewed", companyId, {status});
      await reconcilePublicProjection(db, companyId);
      return {companyId, verificationStatus: status};
    },

    async setBillingStatus(data, context) {
      const actor = await requireActor(db, context, ["administrator"]);
      const companyId = text(data && data.companyId, 200);
      const status = text(data && data.status, 40).toLowerCase();
      if (!BILLING_STATUSES.has(status)) {
        throw new YellowPagesError("invalid-argument", "The billing status is invalid.");
      }
      const ref = db.collection(PRIVATE_COMPANIES).doc(companyId);
      const snapshot = await ref.get();
      if (!snapshot.exists) throw new YellowPagesError("not-found", "Company record not found.");
      const nonExpiringPaid = status === "paid" && data && data.nonExpiringPaid === true;
      const paidThrough = status === "paid" && !nonExpiringPaid ? parsePaidThrough(data && data.paidThrough) : null;
      if (status === "paid" && !nonExpiringPaid && paidThrough.toMillis() <= Date.now()) {
        throw new YellowPagesError("failed-precondition", "Paid-through must be in the future.");
      }
      await ref.update({
        billingStatus: status,
        paidThrough,
        nonExpiringPaid,
        paymentReference: text(data && data.paymentReference, 300) || null,
        billingReviewNote: text(data && data.reviewNote, 2000),
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
      });
      await audit(db, actor, "billing_status_changed", companyId, {
        status,
        paidThrough: paidThrough ? paidThrough.toDate().toISOString() : null,
        nonExpiringPaid,
      });
      await reconcilePublicProjection(db, companyId);
      return {companyId, billingStatus: status};
    },

    async setPublicationStatus(data, context) {
      const actor = await requireActor(db, context, ["administrator"]);
      const companyId = text(data && data.companyId, 200);
      const status = text(data && data.status, 40).toLowerCase();
      if (!PUBLICATION_STATUSES.has(status)) {
        throw new YellowPagesError("invalid-argument", "The publication status is invalid.");
      }
      const ref = db.collection(PRIVATE_COMPANIES).doc(companyId);
      const snapshot = await ref.get();
      if (!snapshot.exists) throw new YellowPagesError("not-found", "Company record not found.");
      const company = snapshot.data() || {};
      if (status === "published" && !isPublicationEligible({...company, publicationStatus: "published"})) {
        throw new YellowPagesError(
            "failed-precondition",
            "A company must be verified and currently paid before publication.",
        );
      }
      await ref.update({
        publicationStatus: status,
        publishedAt: status === "published" ? (company.publishedAt || FieldValue.serverTimestamp()) : company.publishedAt || null,
        publishedByUid: status === "published" ? actor.uid : company.publishedByUid || null,
        publicationReviewNote: text(data && data.reviewNote, 2000),
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
      });
      await audit(db, actor, "publication_status_changed", companyId, {status});
      await reconcilePublicProjection(db, companyId);
      return {companyId, publicationStatus: status};
    },

    async listStaff(data, context) {
      await requireActor(db, context, ["manager", "administrator"]);
      const snapshot = await db.collection(STAFF)
          .orderBy(FieldPath.documentId())
          .limit(200)
          .get();
      return {staff: snapshot.docs.map((doc) => ({uid: doc.id, ...jsonSafe(doc.data())}))};
    },

    async manageStaff(data, context) {
      const actor = await requireActor(db, context, ["administrator"]);
      const email = text(data && data.email, 254).toLowerCase();
      const active = data && data.active !== false;
      const role = text(data && data.role, 40).toLowerCase();
      if (!email) throw new YellowPagesError("invalid-argument", "The employee email is required.");
      if (active && !STAFF_ROLES.has(role)) {
        throw new YellowPagesError("invalid-argument", "Contact Center role must be agent or manager.");
      }
      let user;
      try {
        user = await auth.getUserByEmail(email);
      } catch (error) {
        if (error && error.code === "auth/user-not-found") {
          throw new YellowPagesError("not-found", "The employee must create a Pipe Buyer account first.");
        }
        throw error;
      }
      if (active && user.emailVerified !== true) {
        throw new YellowPagesError("failed-precondition", "The employee must verify their email first.");
      }
      const factors = user.multiFactor && Array.isArray(user.multiFactor.enrolledFactors) ?
        user.multiFactor.enrolledFactors : [];
      if (active && factors.length === 0) {
        throw new YellowPagesError("failed-precondition", "The employee must enroll multi-factor authentication first.");
      }
      const claims = {...(user.customClaims || {})};
      if (active) claims.yellowPagesRole = role;
      else delete claims.yellowPagesRole;
      await auth.setCustomUserClaims(user.uid, claims);
      await db.collection(STAFF).doc(user.uid).set({
        uid: user.uid,
        email,
        displayName: text(user.displayName, 160),
        role: active ? role : null,
        active,
        updatedAt: FieldValue.serverTimestamp(),
        updatedByUid: actor.uid,
        ...(active ? {createdAt: FieldValue.serverTimestamp(), createdByUid: actor.uid} : {}),
      }, {merge: true});
      await auth.revokeRefreshTokens(user.uid);
      await audit(db, actor, active ? "staff_access_granted" : "staff_access_revoked", null, {
        targetUid: user.uid,
        targetEmail: email,
        role: active ? role : null,
      });
      return {uid: user.uid, email, active, role: active ? role : null};
    },
  };
}

module.exports = {
  YellowPagesError,
  createYellowPagesCommands,
  jsonSafe,
  resolveActor,
};
