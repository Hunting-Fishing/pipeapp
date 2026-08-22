"use strict";

function safeMinor(value) {
  const amount = Number(value);
  return Number.isSafeInteger(amount) && amount >= 0 ? amount : null;
}

function canadaSmallSupplierAssessmentDecision(assessment) {
  if (!assessment || typeof assessment !== "object") {
    return Object.freeze({authorized: false, reason: "assessment_missing"});
  }
  if (assessment.worldwideAndAssociatedIncluded !== true) {
    return Object.freeze({authorized: false, reason: "attestation_missing"});
  }
  const singleQuarterCadMinor = safeMinor(assessment.singleQuarterCadMinor);
  const rollingFourQuarterCadMinor = safeMinor(
      assessment.rollingFourQuarterCadMinor,
  );
  const thresholdCadMinor = safeMinor(assessment.thresholdCadMinor);
  if (singleQuarterCadMinor == null || rollingFourQuarterCadMinor == null ||
      thresholdCadMinor == null || thresholdCadMinor !== 3000000) {
    return Object.freeze({authorized: false, reason: "assessment_invalid"});
  }
  if (assessment.exceeded === true ||
      assessment.requiresRegistrationReview === true ||
      singleQuarterCadMinor > thresholdCadMinor ||
      rollingFourQuarterCadMinor > thresholdCadMinor) {
    return Object.freeze({authorized: false, reason: "threshold_exceeded"});
  }
  const revision = Number(assessment.revision);
  if (!Number.isSafeInteger(revision) || revision < 1) {
    return Object.freeze({authorized: false, reason: "assessment_unversioned"});
  }
  return Object.freeze({
    authorized: true,
    reason: "authorized",
    revision,
    singleQuarterCadMinor,
    rollingFourQuarterCadMinor,
    thresholdCadMinor,
  });
}

module.exports = {
  canadaSmallSupplierAssessmentDecision,
  safeMinor,
};
