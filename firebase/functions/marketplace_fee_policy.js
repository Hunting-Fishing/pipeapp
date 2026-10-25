"use strict";

class MarketplaceFeePolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "MarketplaceFeePolicyError";
    this.code = code;
  }
}

const BASIS_POINTS = 10000;
const {
  fromStripeMinorUnits,
  toStripeMinorUnits,
} = require("./global_payment_policy");

// Launch fee schedule. Every transaction stores the revision and computed
// snapshot so later pricing changes never rewrite an already-agreed fee.
const launchMarketplaceFeeSchedule = Object.freeze({
  revision: "2026-08-10-launch-v2",
  payer: "seller",
  affiliateShareBps: 2000,
  pipe: Object.freeze({
    unitFeeMinorByCurrency: Object.freeze({
      CAD: 100,
      USD: 100,
      EUR: 100,
      GBP: 100,
      AUD: 150,
      NZD: 150,
      CHF: 100,
      NOK: 1000,
      SEK: 1000,
      DKK: 700,
      PLN: 400,
      RON: 450,
      AED: 370,
      SAR: 375,
      QAR: 365,
      BRL: 500,
      MXN: 1800,
      SGD: 135,
      HKD: 780,
      ZAR: 1800,
      INR: 8500,
      JPY: 150,
      KRW: 1350,
      KWD: 310,
      BHD: 380,
      OMR: 390,
    }),
    minimumFeeMinorByCurrency: Object.freeze({
      CAD: 2500,
      USD: 2500,
      EUR: 2500,
      GBP: 2000,
      AUD: 3500,
      NZD: 4000,
      CHF: 2200,
      NOK: 25000,
      SEK: 25000,
      DKK: 17500,
      PLN: 10000,
      RON: 11500,
      AED: 9200,
      SAR: 9400,
      QAR: 9100,
      BRL: 12500,
      MXN: 45000,
      SGD: 3400,
      HKD: 19500,
      ZAR: 45000,
      INR: 210000,
      JPY: 3750,
      KRW: 34000,
      KWD: 7750,
      BHD: 9500,
      OMR: 9600,
    }),
    maximumFeeMinorByCurrency: Object.freeze({
      CAD: 500000,
      USD: 500000,
      EUR: 500000,
      GBP: 400000,
      AUD: 700000,
      NZD: 800000,
      CHF: 440000,
      NOK: 5000000,
      SEK: 5000000,
      DKK: 3500000,
      PLN: 2000000,
      RON: 2300000,
      AED: 1840000,
      SAR: 1875000,
      QAR: 1820000,
      BRL: 2500000,
      MXN: 9000000,
      SGD: 680000,
      HKD: 3900000,
      ZAR: 9000000,
      INR: 42000000,
      JPY: 750000,
      KRW: 6800000,
      KWD: 1550000,
      BHD: 1900000,
      OMR: 1925000,
    }),
  }),
  equipment: Object.freeze({
    minimumFeeMinorByCurrency: Object.freeze({
      CAD: 2500,
      USD: 2500,
      EUR: 2500,
      GBP: 2000,
      AUD: 3500,
      NZD: 4000,
      CHF: 2200,
      NOK: 25000,
      SEK: 25000,
      DKK: 17500,
      PLN: 10000,
      RON: 11500,
      AED: 9200,
      SAR: 9400,
      QAR: 9100,
      BRL: 12500,
      MXN: 45000,
      SGD: 3400,
      HKD: 19500,
      ZAR: 45000,
      INR: 210000,
      JPY: 3750,
      KRW: 34000,
      KWD: 7750,
      BHD: 9500,
      OMR: 9600,
    }),
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

function toMinorUnits(amount, currency = "CAD") {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric) || numeric < 0 || numeric > 1e12) {
    invalid("The transaction amount is invalid.");
  }
  return toStripeMinorUnits(numeric, currency);
}

function fromMinorUnits(amountMinor, currency = "CAD") {
  return fromStripeMinorUnits(amountMinor, currency);
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
  const marketplaceFeeMinor = Math.max(
      minimumFeeMinor,
      Math.min(baseFeeMinor, maximumFeeMinor),
  );
  if (marketplaceFeeMinor > agreedTotalMinor) {
    invalid(
        "The agreed transaction total must be at least the minimum Pipe Buyer marketplace fee.",
    );
  }
  return {
    marketplaceFeeMinor,
    feeClass: "pipe",
    quantityCharged: roundedQuantity,
    unitFeeMinor,
    minimumFeeMinor,
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
  const agreedTotalMinor = toMinorUnits(agreedTotal, normalizedCurrency);
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
    marketplaceFee: fromMinorUnits(marketplaceFeeMinor, normalizedCurrency),
    affiliateShareBps: Number(schedule.affiliateShareBps || 0),
    affiliateCommissionMinor,
    affiliateCommission: fromMinorUnits(
        affiliateCommissionMinor,
        normalizedCurrency,
    ),
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
