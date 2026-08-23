"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  canadaSmallSupplierReadinessDecision,
} = require("./canada_small_supplier_readiness_guard");

const ASSESSMENT_COLLECTION = "tax_threshold_assessments";
const CURRENT_ASSESSMENT_ID = "canada_gst_hst_current";

async function requireCanadaSmallSupplierRuntimeEvidence(db, readiness = {}) {
  if (readiness.canadaGstHstSmallSupplier !== true) {
    return Object.freeze({applicable: false, authorized: true});
  }
  const snapshot = await db.collection(ASSESSMENT_COLLECTION)
      .doc(CURRENT_ASSESSMENT_ID).get();
  const assessment = snapshot.exists ? snapshot.data() : null;
  const decision = canadaSmallSupplierReadinessDecision(readiness, assessment);
  if (!decision.authorized) {
    throw new HttpsError(
        "failed-precondition",
        "Canadian small-supplier billing evidence is missing, stale, or no longer eligible. Update the audited GST/HST threshold assessment before billing.",
    );
  }
  return Object.freeze({
    applicable: true,
    ...decision,
  });
}

module.exports = {
  ASSESSMENT_COLLECTION,
  CURRENT_ASSESSMENT_ID,
  requireCanadaSmallSupplierRuntimeEvidence,
};
