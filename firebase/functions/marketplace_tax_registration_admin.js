"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");

const REVIEW_FIELDS = Object.freeze({
  businessNumber: "businessNumberStatus",
  gstHstNumber: "gstHstStatus",
  pstBcNumber: "pstBcStatus",
});
const REVIEW_STATUSES = new Set(["verified", "invalid", "review_required"]);
const TAX_REGISTRATION_REVIEW_DAYS = 180;
const REVIEW_INTERVAL_MS = TAX_REGISTRATION_REVIEW_DAYS * 24 * 60 * 60 * 1000;

function clean(value, maxLength = 1200) {
  const text = String(value == null ? "" : value).trim();
  if (text.length > maxLength) {
    throw new HttpsError("invalid-argument", "The tax review field is too long.");
  }
  return text;
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return 0;
}

function isRegistrationVerificationCurrent(profile, field, nowMs = Date.now()) {
  const statusField = REVIEW_FIELDS[field];
  if (!statusField || !profile || profile[statusField] !== "verified") return false;
  if (!String(profile[field] || "").trim()) return false;
  const reviewDueAt = timestampMillis(profile[`${field}ReviewDueAt`]);
  return reviewDueAt > nowMs;
}

function effectiveVerificationStatus(profile, field, nowMs = Date.now()) {
  const statusField = REVIEW_FIELDS[field];
  const raw = String(profile && profile[statusField] || "not_provided");
  if (raw === "verified" && !isRegistrationVerificationCurrent(profile, field, nowMs)) {
    return "review_required";
  }
  return raw;
}

function createMarketplaceTaxRegistrationAdmin(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  const getMarketplaceTaxRegistrationAdmin = async (request) => {
    try {
      requireAdministrator(request);
      const snapshot = await db.collection("business_tax_profiles").limit(250).get();
      const nowMs = Date.now();
      const rows = snapshot.docs.map((doc) => ({uid: doc.id, ...doc.data()}));
      const prepared = rows.map((row) => ({
        ...row,
        businessNumberEffectiveStatus: effectiveVerificationStatus(
            row,
            "businessNumber",
            nowMs,
        ),
        gstHstEffectiveStatus: effectiveVerificationStatus(
            row,
            "gstHstNumber",
            nowMs,
        ),
        pstBcEffectiveStatus: effectiveVerificationStatus(
            row,
            "pstBcNumber",
            nowMs,
        ),
      }));
      return {
        reviewIntervalDays: TAX_REGISTRATION_REVIEW_DAYS,
        pendingProfiles: prepared
            .filter((row) => [
              row.businessNumberEffectiveStatus,
              row.gstHstEffectiveStatus,
              row.pstBcEffectiveStatus,
            ].some((status) => status === "pending_verification" ||
              status === "review_required"))
            .slice(0, 100)
            .map((row) => ({
              uid: row.uid,
              legalBusinessName: String(row.legalBusinessName || ""),
              countryCode: String(row.countryCode || ""),
              regionCode: String(row.regionCode || ""),
              businessNumber: String(row.businessNumber || ""),
              businessNumberStatus: row.businessNumberEffectiveStatus,
              businessNumberReviewDueAt: row.businessNumberReviewDueAt || null,
              gstHstNumber: String(row.gstHstNumber || ""),
              gstHstStatus: row.gstHstEffectiveStatus,
              gstHstNumberReviewDueAt: row.gstHstNumberReviewDueAt || null,
              pstBcNumber: String(row.pstBcNumber || ""),
              pstBcStatus: row.pstBcEffectiveStatus,
              pstBcNumberReviewDueAt: row.pstBcNumberReviewDueAt || null,
              sellerNormalGstHstRegistered: String(
                  row.sellerNormalGstHstRegistered || "pending",
              ),
              revision: Number(row.revision || 0),
            })),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Tax registration admin queue failed", error);
      throw new HttpsError("internal", "The tax registration queue is unavailable.");
    }
  };

  const reviewMarketplaceTaxRegistration = async (request) => {
    try {
      const adminUid = requireAdministrator(request);
      const uid = clean(request.data && request.data.uid, 180);
      const field = clean(request.data && request.data.field, 40);
      const status = clean(request.data && request.data.status, 40);
      const reviewNote = clean(request.data && request.data.reviewNote, 1200);
      if (!uid || uid.includes("/") || !Object.hasOwn(REVIEW_FIELDS, field)) {
        throw new HttpsError("invalid-argument", "The tax registration review is invalid.");
      }
      if (!REVIEW_STATUSES.has(status)) {
        throw new HttpsError("invalid-argument", "Select a valid verification result.");
      }
      if (reviewNote.length < 4) {
        throw new HttpsError("invalid-argument", "Record the verification source or reason.");
      }
      const ref = db.collection("business_tax_profiles").doc(uid);
      const snapshot = await ref.get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "The business tax profile was not found.");
      }
      const data = snapshot.data();
      if (!String(data[field] || "").trim()) {
        throw new HttpsError(
            "failed-precondition",
            "The user has not provided a value for this tax registration field.",
        );
      }
      const statusField = REVIEW_FIELDS[field];
      const reviewDueField = `${field}ReviewDueAt`;
      const nextReviewAt = status === "verified" ?
        Timestamp.fromMillis(Date.now() + REVIEW_INTERVAL_MS) :
        FieldValue.delete();
      await ref.set({
        [statusField]: status,
        [`${field}ReviewNote`]: reviewNote,
        [`${field}ReviewedBy`]: adminUid,
        [`${field}ReviewedAt`]: FieldValue.serverTimestamp(),
        [reviewDueField]: nextReviewAt,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await db.collection("tax_compliance_events").add({
        type: "tax_registration_reviewed",
        actorUid: adminUid,
        ownerUid: uid,
        field,
        status,
        reviewIntervalDays: TAX_REGISTRATION_REVIEW_DAYS,
        profileRevision: Number(data.revision || 0),
        createdAt: FieldValue.serverTimestamp(),
      });
      return {
        uid,
        field,
        status,
        reviewIntervalDays: TAX_REGISTRATION_REVIEW_DAYS,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Tax registration review failed", error);
      throw new HttpsError("internal", "The tax registration review could not be saved.");
    }
  };

  return {
    getMarketplaceTaxRegistrationAdmin,
    reviewMarketplaceTaxRegistration,
  };
}

module.exports = {
  REVIEW_FIELDS,
  REVIEW_STATUSES,
  TAX_REGISTRATION_REVIEW_DAYS,
  createMarketplaceTaxRegistrationAdmin,
  effectiveVerificationStatus,
  isRegistrationVerificationCurrent,
  timestampMillis,
};
