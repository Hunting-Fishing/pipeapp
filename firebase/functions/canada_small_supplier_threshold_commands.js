"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  canadaSmallSupplierThresholdState,
} = require("./canada_small_supplier_policy");

const ASSESSMENT_COLLECTION = "tax_threshold_assessments";
const CURRENT_ASSESSMENT_ID = "canada_gst_hst_current";
const AUDIT_COLLECTION = "tax_threshold_assessment_audit";
const READINESS_COLLECTION = "platform_configuration";
const READINESS_ID = "payment_provider_readiness";
const READINESS_AUDIT_COLLECTION = "payment_readiness_audit";

function safeText(value, field, {min = 1, max = 1000} = {}) {
  const text = String(value || "").trim();
  if (text.length < min || text.length > max) {
    throw new HttpsError(
        "invalid-argument",
        `${field} must be between ${min} and ${max} characters.`,
    );
  }
  return text;
}

function safeCadMinor(value, field) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new HttpsError(
        "invalid-argument",
        `${field} must be a non-negative integer amount in CAD cents.`,
    );
  }
  return amount;
}

function assessmentFromRequest(data = {}) {
  if (data.worldwideAndAssociatedIncluded !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Confirm that the assessment includes worldwide taxable supplies and associated businesses before saving it.",
    );
  }
  const singleQuarterCadMinor = safeCadMinor(
      data.singleQuarterCadMinor,
      "singleQuarterCadMinor",
  );
  const rollingFourQuarterCadMinor = safeCadMinor(
      data.rollingFourQuarterCadMinor,
      "rollingFourQuarterCadMinor",
  );
  const state = canadaSmallSupplierThresholdState({
    singleQuarterCadMinor,
    rollingFourQuarterCadMinor,
  });
  return {
    periodLabel: safeText(data.periodLabel, "periodLabel", {min: 4, max: 80}),
    sourceNote: safeText(data.sourceNote, "sourceNote", {min: 20, max: 1200}),
    worldwideAndAssociatedIncluded: true,
    ...state,
    requiresRegistrationReview: state.exceeded,
  };
}

function smallSupplierBillingSafetyDecision(assessment, readiness = {}) {
  const thresholdExceeded = assessment &&
    assessment.requiresRegistrationReview === true;
  const smallSupplierActive = readiness &&
    readiness.canadaGstHstSmallSupplier === true;
  if (!thresholdExceeded || !smallSupplierActive) {
    return Object.freeze({
      disableBilling: false,
      reason: thresholdExceeded ?
        "small_supplier_not_active" : "threshold_not_exceeded",
    });
  }
  return Object.freeze({
    disableBilling: true,
    reason: "small_supplier_threshold_exceeded",
  });
}

function createCanadaSmallSupplierThresholdCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function getCanadaGstHstThresholdAssessment(request) {
    try {
      requireAdministrator(request);
      const [assessmentSnapshot, readinessSnapshot] = await Promise.all([
        db.collection(ASSESSMENT_COLLECTION).doc(CURRENT_ASSESSMENT_ID).get(),
        db.collection(READINESS_COLLECTION).doc(READINESS_ID).get(),
      ]);
      const assessment = assessmentSnapshot.exists ? assessmentSnapshot.data() : null;
      const readiness = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      return {
        assessment,
        canadaGstHstSmallSupplier: readiness.canadaGstHstSmallSupplier === true,
        stripeTaxReady: readiness.stripeTaxReady === true,
        stripeTaxRegistrationPending:
          readiness.stripeTaxRegistrationPending === true,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("GST/HST threshold assessment read failed", error);
      throw new HttpsError(
          "internal",
          "The GST/HST threshold assessment could not be loaded.",
      );
    }
  }

  async function setCanadaGstHstThresholdAssessment(request) {
    try {
      const administratorUid = requireAdministrator(request);
      const next = assessmentFromRequest(request.data || {});
      const ref = db.collection(ASSESSMENT_COLLECTION).doc(CURRENT_ASSESSMENT_ID);
      const readinessRef = db.collection(READINESS_COLLECTION).doc(READINESS_ID);
      return await db.runTransaction(async (transaction) => {
        const [previousSnapshot, readinessSnapshot] = await Promise.all([
          transaction.get(ref),
          transaction.get(readinessRef),
        ]);
        const previous = previousSnapshot.exists ? previousSnapshot.data() : null;
        const readiness = readinessSnapshot.exists ? readinessSnapshot.data() : {};
        const revision = Math.max(0, Number(previous && previous.revision || 0)) + 1;
        const safety = smallSupplierBillingSafetyDecision(next, readiness);
        const record = {
          ...next,
          revision,
          reviewedByUid: administratorUid,
          reviewedAt: FieldValue.serverTimestamp(),
          billingSafetyAction: safety.disableBilling ?
            "small_supplier_billing_disabled" : "none",
          updatedAt: FieldValue.serverTimestamp(),
        };
        transaction.set(ref, record, {merge: false});
        const auditRef = db.collection(AUDIT_COLLECTION).doc();
        transaction.create(auditRef, {
          administratorUid,
          revision,
          previous,
          next: record,
          billingSafetyAction: record.billingSafetyAction,
          createdAt: FieldValue.serverTimestamp(),
        });

        let readinessRevision = null;
        if (safety.disableBilling) {
          readinessRevision = Math.max(
              0,
              Number(readiness && readiness.revision || 0),
          ) + 1;
          const readinessPatch = {
            canadaGstHstSmallSupplier: false,
            canadaGstHstSmallSupplierAssessmentRevision: null,
            stripeFeeBillingEnabled: false,
            stripeSubscriptionsEnabled: false,
            revision: readinessRevision,
            lastChangedByUid: administratorUid,
            lastChangeReason:
              "Automatic safety shutdown: audited Canadian GST/HST small-supplier threshold assessment is exceeded. Tax registration/effective-date review is required before billing resumes.",
            updatedAt: FieldValue.serverTimestamp(),
          };
          transaction.set(readinessRef, readinessPatch, {merge: true});
          const readinessAuditRef = db.collection(READINESS_AUDIT_COLLECTION).doc();
          transaction.create(readinessAuditRef, {
            administratorUid,
            reason: readinessPatch.lastChangeReason,
            revision: readinessRevision,
            automaticSafetyAction: "small_supplier_threshold_exceeded",
            triggeringThresholdAssessmentRevision: revision,
            previous: readiness,
            patch: readinessPatch,
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        return {
          revision,
          assessment: {
            ...next,
            reviewedByUid: administratorUid,
            billingSafetyAction: record.billingSafetyAction,
          },
          billingSafetyAction: record.billingSafetyAction,
          readinessRevision,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("GST/HST threshold assessment write failed", error);
      throw new HttpsError(
          "internal",
          "The GST/HST threshold assessment could not be saved.",
      );
    }
  }

  return {
    getCanadaGstHstThresholdAssessment,
    setCanadaGstHstThresholdAssessment,
  };
}

module.exports = {
  ASSESSMENT_COLLECTION,
  AUDIT_COLLECTION,
  CURRENT_ASSESSMENT_ID,
  READINESS_AUDIT_COLLECTION,
  READINESS_COLLECTION,
  READINESS_ID,
  assessmentFromRequest,
  createCanadaSmallSupplierThresholdCommands,
  smallSupplierBillingSafetyDecision,
};
