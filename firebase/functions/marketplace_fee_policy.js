"use strict";

class MarketplaceFeePolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "MarketplaceFeePolicyError";
    this.code = code;
  }
}

const BASIS_POINTS = 10000;

// Launch defaults approved for implementation planning. Every transaction stores
// the revision and computed snapshot so later pricing changes never rewrite an
// already-agreed fee. Move these values into an administrator-approved versioned
// Firestore schedule before enabling production money movement.
const launchMarketplaceFeeSchedule = Object.freeze({
  revision: "2026-08-09-launch-v1",
  payer: "seller",
  affiliateShareBps: 2000,
  pipe: Object.freeze({
    unitFeeMinorByCurrency: Object.freeze({CAD: 100, USD: 100}),
    minimumFeeMinorByCurrency: Object.freeze({CAD: 2500, USD: 2500}),
    maximumFeeMinorByCurrency: Object.freeze({CAD: 500000, USD: 500000}),
    percentageCapBps: 300,
  }),
  equipment: Object.freeze({
    minimumFeeMinorByCurrency: Object.freeze({CAD: 2500, USD: 2500}),
    tiers: Object.freeze([
      Object.freeze({upToExclusiveMinor: 1000000, feeBps: 500}),
      Object.freeze({upToExclusiveMinor: 5000000, feeBps: 300}),
      Object.freeze({upToExclusiveMinor: 25000000, feeBps: 200}),
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
  const currency = String(value || "CAD").trim().toUpperCase();
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

function inferMarketplaceFeeClass(listing) {
  const text = [
    listing && listing.category,
    listing && listing.productType,
    listing && listing.title,
  ].map((value) => String(value || "").toLowerCase()).join(" ");

  if (/\b(pipe|tubing|casing|drill pipe|line pipe|octg|joint|pup joint)\b/u
      .test(text)) {
    return "pipe";
  }
  return "equipment_asset";
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
  const minimumFeeMinor = currencyValue(
      schedule.minimumFeeMinorByCurrency,
      currency,
      "The minimum pipe marketplace fee",
  );
  const maximumFeeMinor = currencyValue(
      schedule.maximumFeeMinorByCurrency,
      currency,
      "The maximum pipe marketplace fee",
  );
  const baseFeeMinor = roundedQuantity * unitFeeMinor;
  const percentageCapMinor = Math.floor(
      agreedTotalMinor * Number(schedule.percentageCapBps || 0) / BASIS_POINTS,
  );
  const feeBeforeCapsMinor = Math.max(baseFeeMinor, minimumFeeMinor);
  const marketplaceFeeMinor = Math.max(
      0,
      Math.min(feeBeforeCapsMinor, percentageCapMinor, maximumFeeMinor),
  );
  return {
    marketplaceFeeMinor,
    feeClass: "pipe",
    quantityCharged: roundedQuantity,
    unitFeeMinor,
    minimumFeeMinor,
    percentageCapBps: schedule.percentageCapBps,
    percentageCapMinor,
    maximumFeeMinor,
  };
}

function equipmentTier(totalMinor, tiers) {
  for (const tier of tiers || []) {
    if (tier.upToExclusiveMinor == null || totalMinor < tier.upToExclusiveMinor) {
      return tier;
    }
  }
  invalid("The equipment marketplace fee schedule is invalid.");
}

function calculateEquipmentFee({agreedTotalMinor, currency, schedule}) {
  const minimumFeeMinor = currencyValue(
      schedule.minimumFeeMinorByCurrency,
      currency,
      "The minimum equipment marketplace fee",
  );
  const tier = equipmentTier(agreedTotalMinor, schedule.tiers);
  const feeBps = Number(tier.feeBps);
  if (!Number.isSafeInteger(feeBps) || feeBps < 0 || feeBps > BASIS_POINTS) {
    invalid("The equipment marketplace percentage is invalid.");
  }
  const percentageFeeMinor = Math.floor(
      agreedTotalMinor * feeBps / BASIS_POINTS,
  );
  return {
    marketplaceFeeMinor: Math.max(minimumFeeMinor, percentageFeeMinor),
    feeClass: "equipment_asset",
    feeBps,
    minimumFeeMinor,
    tierUpToExclusiveMinor: tier.upToExclusiveMinor,
  };
}

function calculateMarketplaceFeeSnapshot({
  listing,
  agreedQuantity,
  agreedTotal,
  currency,
  schedule = launchMarketplaceFeeSchedule,
}) {
  const normalizedCurrency = normalizeCurrency(currency);
  const agreedTotalMinor = toMinorUnits(agreedTotal);
  if (agreedTotalMinor <= 0) invalid("The agreed total must be greater than zero.");
  const feeClass = inferMarketplaceFeeClass(listing);
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
  MarketplaceFeePolicyError,
  calculateMarketplaceFeeSnapshot,
  fromMinorUnits,
  inferMarketplaceFeeClass,
  launchMarketplaceFeeSchedule,
  normalizeCurrency,
  toMinorUnits,
};
