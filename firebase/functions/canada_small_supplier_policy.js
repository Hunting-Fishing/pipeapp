"use strict";

const SMALL_SUPPLIER_THRESHOLD_CAD_MINOR = 3000000;
const WARNING_BPS = 7500;
const HIGH_WARNING_BPS = 9000;
const BASIS_POINTS = 10000;

function safeCadMinor(value, field) {
  const amount = Number(value || 0);
  if (!Number.isSafeInteger(amount) || amount < 0) {
    throw new TypeError(`${field} must be a non-negative integer amount in CAD cents.`);
  }
  return amount;
}

function thresholdLevel(amountMinor) {
  if (amountMinor > SMALL_SUPPLIER_THRESHOLD_CAD_MINOR) return "exceeded";
  if (amountMinor * BASIS_POINTS >=
      SMALL_SUPPLIER_THRESHOLD_CAD_MINOR * HIGH_WARNING_BPS) {
    return "high_warning";
  }
  if (amountMinor * BASIS_POINTS >=
      SMALL_SUPPLIER_THRESHOLD_CAD_MINOR * WARNING_BPS) {
    return "warning";
  }
  return "within_threshold";
}

function canadaSmallSupplierThresholdState({
  singleQuarterCadMinor = 0,
  rollingFourQuarterCadMinor = 0,
} = {}) {
  const quarter = safeCadMinor(singleQuarterCadMinor, "singleQuarterCadMinor");
  const rolling = safeCadMinor(
      rollingFourQuarterCadMinor,
      "rollingFourQuarterCadMinor",
  );
  const governingAmount = Math.max(quarter, rolling);
  const exceededSingleQuarter = quarter > SMALL_SUPPLIER_THRESHOLD_CAD_MINOR;
  const exceededRolling = rolling > SMALL_SUPPLIER_THRESHOLD_CAD_MINOR;
  return Object.freeze({
    thresholdCadMinor: SMALL_SUPPLIER_THRESHOLD_CAD_MINOR,
    singleQuarterCadMinor: quarter,
    rollingFourQuarterCadMinor: rolling,
    governingAmountCadMinor: governingAmount,
    remainingCadMinor: Math.max(
        0,
        SMALL_SUPPLIER_THRESHOLD_CAD_MINOR - governingAmount,
    ),
    level: thresholdLevel(governingAmount),
    exceeded: exceededSingleQuarter || exceededRolling,
    exceededSingleQuarter,
    exceededRolling,
  });
}

module.exports = {
  SMALL_SUPPLIER_THRESHOLD_CAD_MINOR,
  canadaSmallSupplierThresholdState,
  thresholdLevel,
};
