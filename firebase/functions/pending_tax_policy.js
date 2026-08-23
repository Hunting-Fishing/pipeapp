"use strict";

const BASIS_POINTS = 10000;
const PROVISIONAL_TAX_RESERVE_BPS = 1500;

function taxCollectionStatus(readiness = {}) {
  if (readiness.stripeTaxReady === true) return "registered";
  if (readiness.stripeTaxRegistrationPending === true) {
    return "registration_pending";
  }
  return "not_ready";
}

function taxBillingPrepared(readiness = {}) {
  return readiness.stripeTaxReady === true ||
    (readiness.stripeTaxRegistrationPending === true &&
      readiness.stripeTaxPendingBillingApproved === true);
}

function automaticTaxEnabled(readiness = {}) {
  return readiness.stripeTaxReady === true;
}

function provisionalTaxReserveMinor(baseMinor, status) {
  const amount = Number(baseMinor);
  if (status !== "registration_pending" ||
      !Number.isSafeInteger(amount) || amount <= 0) {
    return 0;
  }
  return Math.ceil(amount * PROVISIONAL_TAX_RESERVE_BPS / BASIS_POINTS);
}

module.exports = {
  BASIS_POINTS,
  PROVISIONAL_TAX_RESERVE_BPS,
  automaticTaxEnabled,
  provisionalTaxReserveMinor,
  taxBillingPrepared,
  taxCollectionStatus,
};
