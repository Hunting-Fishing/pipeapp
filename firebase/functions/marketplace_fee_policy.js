"use strict";

class MarketplaceFeePolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "MarketplaceFeePolicyError";
    this.code = code;
  }
}

const BASIS_POINTS = 10000;
const MARKETPLACE_FEE_CLASSIFICATION_REVISION =
  "2026-10-16-admin-approved-v2";
const MARKETPLACE_FEE_CLASS_SOURCE = "administrator_approved_catalog";
const PIPE_FEE_PRODUCT_TYPES = new Set([
  "Drill Pipe",
  "Drill Stem",
  "Casing",
  "Tubing",
  "Sucker Rod",
  "Line Pipe",
  "OCTG",
  "Culverts",
  "Fittings",
  "Flanges",
  "Steel Plate",
]);

// Launch fee schedule. Every transaction stores the revision and computed
// snapshot so later pricing changes never rewrite an already-agreed fee.
const launchMarketplaceFeeSchedule = Object.freeze({
  revision: "2026-10-16-sale-only-v4",
  payer: "seller",
  listingFeeMinorByCurrency: Object.freeze({CAD: 0, USD: 0}),
  collectionTiming: "sale_payment",
  affiliateShareBps: 2000,
  pipe: Object.freeze({
    unitFeeMinorByCurrency: Object.freeze({CAD: 100, USD: 100}),
    percentageCapBps: 300,
    maximumFeeMinorByCurrency: Object.freeze({CAD: 250000, USD: 250000}),
  }),
  equipment: Object.freeze({
    minimumFeeMinorByCurrency: Object.freeze({CAD: 100, USD: 100}),
    maximumFeeMinorByCurrency: Object.freeze({CAD: 250000, USD: 250000}),
    brackets: Object.freeze([
      Object.freeze({upToExclusiveMinor: 500000, feeBps: 300}),
      Object.freeze({upToExclusiveMinor: 2500000, feeBps: 250}),
      Object.freeze({upToExclusiveMinor: 10000000, feeBps: 200}),
      Object.freeze({upToExclusiveMinor: 25000000, feeBps: 150}),
      Object.freeze({upToExclusiveMinor: null, feeBps: 100}),
    ]),
  }),
});

function invalid(message) {
  throw new MarketplaceFeePolicyError("invalid-argument", message);
}

function toMinorUnits(amount) {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric) || numeric < 0 || numeric > 1e12) {
    invalid("The transaction amount is invalid.");
  }
  return Math.round((numeric + Number.EPSILON) * 100);
}

function fromMinorUnits(amountMinor) {
  return Number((Number(amountMinor || 0) / 100).toFixed(2));
}

function normalizeCurrency(value) {
  const currency = String(value || "").trim().toUpperCase();
  if (!/^[A-Z]{3}$/.test(currency)) invalid("The transaction currency is invalid.");
  return currency;
}

function currencyValue(map, currency, field) {
  const value = Number(map && map[currency]);
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new MarketplaceFeePolicyError(
        "failed-precondition",
        `${field} is not configured for ${currency}.`,
    );
  }
  return value;
}

function listingRevision(listing) {
  const rawRevision = listing && listing.revision;
  const revision = rawRevision == null ? 1 : Number(rawRevision);
  return Number.isSafeInteger(revision) && revision >= 1 ? revision : null;
}

function isCanonicalPipeCatalogListing(listing) {
  return String(listing && listing.category || "") ===
      "Pipe, Tubing & Materials" &&
    PIPE_FEE_PRODUCT_TYPES.has(String(listing && listing.productType || ""));
}

// A public listing is seller-authored. Never trust fee fields embedded in it.
// The only discounted pipe path is a separate, server-only administrator
// approval bound to the exact listing identity, catalog values, and revision.
function resolveMarketplaceFeeClassification(listing, feeClassification) {
  const listingId = String(listing && listing.id || "").trim();
  const sellerUid = String(listing && listing.sellerUid || "").trim();
  const revision = listingRevision(listing);
  const approval = feeClassification || {};
  const decisionRevision = Number(approval.decisionRevision);
  const approvedPipe = listingId && sellerUid && revision != null &&
    isCanonicalPipeCatalogListing(listing) &&
    approval.status === "approved" &&
    approval.marketplaceFeeClass === "pipe" &&
    approval.marketplaceFeeUnit === "item" &&
    approval.marketplaceFeeClassSource === MARKETPLACE_FEE_CLASS_SOURCE &&
    approval.marketplaceFeeClassificationRevision ===
      MARKETPLACE_FEE_CLASSIFICATION_REVISION &&
    String(approval.listingId || "").trim() === listingId &&
    String(approval.sellerUid || "").trim() === sellerUid &&
    Number(approval.listingRevision) === revision &&
    Number.isSafeInteger(decisionRevision) && decisionRevision >= 1 &&
    String(approval.decidedByUid || "").trim().length > 0 &&
    String(approval.decisionReason || "").trim().length >= 10 &&
    Boolean(approval.decidedAt) &&
    String(approval.category || "") === String(listing.category || "") &&
    String(approval.productType || "") === String(listing.productType || "");
  return Object.freeze({
    feeClass: approvedPipe ? "pipe" : "equipment_asset",
    feeUnit: approvedPipe ? "item" : "sale_value",
    source: approvedPipe ? MARKETPLACE_FEE_CLASS_SOURCE :
      "server_fail_closed_default",
    classificationRevision: MARKETPLACE_FEE_CLASSIFICATION_REVISION,
  });
}

function inferMarketplaceFeeClass(listing, feeClassification) {
  return resolveMarketplaceFeeClassification(listing, feeClassification)
      .feeClass;
}

function calculatePipeFee({
  agreedQuantity,
  agreedTotalMinor,
  currency,
  schedule,
}) {
  const quantity = Number(agreedQuantity);
  if (!Number.isFinite(quantity) || quantity <= 0 || quantity > 10000000) {
    invalid("The agreed pipe quantity is invalid.");
  }
  const roundedQuantity = Math.ceil(quantity);
  const unitFeeMinor = currencyValue(
      schedule.unitFeeMinorByCurrency,
      currency,
      "The per-stick marketplace fee",
  );
  const maximumFeeMinor = currencyValue(
      schedule.maximumFeeMinorByCurrency,
      currency,
      "The maximum pipe marketplace fee",
  );
  const percentageCapBps = Number(schedule.percentageCapBps);
  if (!Number.isSafeInteger(percentageCapBps) || percentageCapBps <= 0 ||
      percentageCapBps > BASIS_POINTS) {
    invalid("The pipe marketplace percentage cap is invalid.");
  }
  const baseFeeMinor = roundedQuantity * unitFeeMinor;
  const percentageCapMinor = Math.floor(
      agreedTotalMinor * percentageCapBps / BASIS_POINTS,
  );
  const marketplaceFeeMinor = Math.min(
      baseFeeMinor,
      maximumFeeMinor,
      percentageCapMinor,
  );
  return {
    marketplaceFeeMinor,
    feeClass: "pipe",
    quantityCharged: roundedQuantity,
    unitFeeMinor,
    percentageCapBps,
    percentageCapMinor,
    maximumFeeMinor,
  };
}

function calculateProgressiveFee(totalMinor, brackets) {
  if (!Array.isArray(brackets) || brackets.length === 0) {
    invalid("The equipment marketplace fee schedule is invalid.");
  }
  let lowerBoundMinor = 0;
  let feeNumerator = 0;
  const appliedBrackets = [];
  for (const bracket of brackets) {
    const feeBps = Number(bracket && bracket.feeBps);
    const upperBoundMinor = bracket && bracket.upToExclusiveMinor;
    if (!Number.isSafeInteger(feeBps) || feeBps < 0 ||
        feeBps > BASIS_POINTS ||
        (upperBoundMinor != null &&
         (!Number.isSafeInteger(upperBoundMinor) ||
          upperBoundMinor <= lowerBoundMinor))) {
      invalid("The equipment marketplace fee schedule is invalid.");
    }
    const bracketEndMinor = upperBoundMinor == null ?
      totalMinor : Math.min(totalMinor, upperBoundMinor);
    const amountInBracketMinor = Math.max(
        0,
        bracketEndMinor - lowerBoundMinor,
    );
    if (amountInBracketMinor > 0) {
      const bracketFeeMinor = Math.floor(
          amountInBracketMinor * feeBps / BASIS_POINTS,
      );
      feeNumerator += amountInBracketMinor * feeBps;
      appliedBrackets.push({
        fromMinor: lowerBoundMinor,
        upToExclusiveMinor: upperBoundMinor,
        amountMinor: amountInBracketMinor,
        feeBps,
        feeMinor: bracketFeeMinor,
      });
    }
    if (upperBoundMinor == null || totalMinor <= upperBoundMinor) break;
    lowerBoundMinor = upperBoundMinor;
  }
  if (appliedBrackets.length === 0 ||
      appliedBrackets.reduce((sum, item) => sum + item.amountMinor, 0) !==
        totalMinor) {
    invalid("The equipment marketplace fee schedule is invalid.");
  }
  return {
    appliedBrackets,
    progressiveFeeMinor: Math.floor(feeNumerator / BASIS_POINTS),
  };
}

function calculateEquipmentFee({agreedTotalMinor, currency, schedule}) {
  const minimumFeeMinor = currencyValue(
      schedule.minimumFeeMinorByCurrency,
      currency,
      "The minimum equipment marketplace fee",
  );
  const maximumFeeMinor = currencyValue(
      schedule.maximumFeeMinorByCurrency,
      currency,
      "The maximum equipment marketplace fee",
  );
  const progressive = calculateProgressiveFee(
      agreedTotalMinor,
      schedule.brackets,
  );
  return {
    marketplaceFeeMinor: Math.min(
        agreedTotalMinor,
        maximumFeeMinor,
        Math.max(minimumFeeMinor, progressive.progressiveFeeMinor),
    ),
    feeClass: "equipment_asset",
    minimumFeeMinor,
    maximumFeeMinor,
    progressiveFeeMinor: progressive.progressiveFeeMinor,
    appliedBrackets: progressive.appliedBrackets,
  };
}

function calculateMarketplaceFeeSnapshot({
  listing,
  feeClassification,
  agreedQuantity,
  agreedTotal,
  currency,
  schedule = launchMarketplaceFeeSchedule,
}) {
  const normalizedCurrency = normalizeCurrency(currency);
  const agreedTotalMinor = toMinorUnits(agreedTotal);
  if (agreedTotalMinor <= 0) invalid("The agreed total must be greater than zero.");
  const classification = resolveMarketplaceFeeClassification(
      listing,
      feeClassification,
  );
  const feeClass = classification.feeClass;
  const calculation = feeClass === "pipe" ?
    calculatePipeFee({
      agreedQuantity,
      agreedTotalMinor,
      currency: normalizedCurrency,
      schedule: schedule.pipe,
    }) :
    calculateEquipmentFee({
      agreedTotalMinor,
      currency: normalizedCurrency,
      schedule: schedule.equipment,
    });
  const marketplaceFeeMinor = calculation.marketplaceFeeMinor;
  if (!Number.isSafeInteger(marketplaceFeeMinor) || marketplaceFeeMinor <= 0) {
    invalid("The marketplace fee could not be calculated for this sale.");
  }
  if (marketplaceFeeMinor > agreedTotalMinor) {
    invalid("The marketplace fee cannot exceed the agreed transaction total.");
  }
  const affiliateCommissionMinor = Math.floor(
      marketplaceFeeMinor * Number(schedule.affiliateShareBps || 0) /
      BASIS_POINTS,
  );
  return Object.freeze({
    scheduleRevision: String(schedule.revision),
    feePayer: String(schedule.payer || "seller"),
    collectionTiming: String(schedule.collectionTiming || "sale_payment"),
    listingFeeMinor: currencyValue(
        schedule.listingFeeMinorByCurrency,
        normalizedCurrency,
        "The marketplace listing fee",
    ),
    feeClassificationSource: classification.source,
    feeClassificationRevision: classification.classificationRevision,
    feeClass: calculation.feeClass,
    currency: normalizedCurrency,
    agreedTotalMinor,
    marketplaceFeeMinor,
    marketplaceFee: fromMinorUnits(marketplaceFeeMinor),
    affiliateShareBps: Number(schedule.affiliateShareBps || 0),
    affiliateCommissionMinor,
    affiliateCommission: fromMinorUnits(affiliateCommissionMinor),
    sellerProceedsBeforeTaxMinor: Math.max(0, agreedTotalMinor - marketplaceFeeMinor),
    ...calculation,
  });
}

module.exports = {
  BASIS_POINTS,
  MARKETPLACE_FEE_CLASS_SOURCE,
  MARKETPLACE_FEE_CLASSIFICATION_REVISION,
  MarketplaceFeePolicyError,
  PIPE_FEE_PRODUCT_TYPES,
  calculateMarketplaceFeeSnapshot,
  calculateProgressiveFee,
  fromMinorUnits,
  inferMarketplaceFeeClass,
  isCanonicalPipeCatalogListing,
  launchMarketplaceFeeSchedule,
  listingRevision,
  normalizeCurrency,
  resolveMarketplaceFeeClassification,
  toMinorUnits,
};
