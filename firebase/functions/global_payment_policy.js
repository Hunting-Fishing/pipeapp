"use strict";

class GlobalPaymentPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "GlobalPaymentPolicyError";
    this.code = code;
  }
}

/**
 * Countries prohibited from Stripe payment processing, paid directory tiers,
 * subscriptions, and payouts under Stripe compliance rules, Canadian SEMA,
 * and US OFAC comprehensive/sectoral sanctions.
 */
const STRIPE_SANCTIONED_COUNTRIES = Object.freeze([
  "BY", // Belarus
  "CU", // Cuba
  "IR", // Iran
  "KP", // North Korea
  "RU", // Russia
  "SY", // Syria
]);

const STRIPE_SANCTIONED_COUNTRY_SET = new Set(STRIPE_SANCTIONED_COUNTRIES);

const OCCUPIED_UKRAINE_REGION_PATTERN =
  /\b(crimea|sevastopol|donetsk|luhansk|dnr|lnr)\b/i;

/**
 * Jurisdictions subject to targeted sanctions / heightened AML & SDN screening
 * where international Stripe Checkout cards may operate for non-sanctioned
 * private parties, while Stripe Connect payouts are unavailable.
 */
const ELEVATED_SANCTIONS_COUNTRIES = Object.freeze([
  "AF",
  "CD",
  "CF",
  "ER",
  "HT",
  "IQ",
  "LB",
  "LY",
  "ML",
  "MM",
  "NI",
  "SD",
  "SO",
  "SS",
  "VE",
  "YE",
  "ZW",
]);

const ELEVATED_SANCTIONS_COUNTRY_SET = new Set(ELEVATED_SANCTIONS_COUNTRIES);

/**
 * Exact 37 countries supported for Stripe Connect Express accounts and
 * cross-border transfers from Pipe Buyer's Canadian ("CA") Stripe platform
 * (`CountrySpec("CA").supported_transfer_countries`).
 */
const STRIPE_CA_CONNECT_SELLER_COUNTRIES = Object.freeze([
  "AT",
  "BE",
  "BG",
  "CA",
  "CH",
  "CY",
  "CZ",
  "DE",
  "DK",
  "EE",
  "ES",
  "FI",
  "FR",
  "GB",
  "GI",
  "GR",
  "HR",
  "HU",
  "IE",
  "IS",
  "IT",
  "LI",
  "LT",
  "LU",
  "LV",
  "MC",
  "MT",
  "NL",
  "NO",
  "PL",
  "PT",
  "RO",
  "SE",
  "SI",
  "SK",
  "SM",
  "US",
]);

const STRIPE_CA_CONNECT_SELLER_COUNTRY_SET = new Set(
    STRIPE_CA_CONNECT_SELLER_COUNTRIES,
);

/**
 * Stripe zero-decimal currencies (unit_amount is in whole major units).
 */
const STRIPE_ZERO_DECIMAL_CURRENCIES = new Set([
  "BIF",
  "CLP",
  "DJF",
  "GNF",
  "JPY",
  "KMF",
  "KRW",
  "MGA",
  "PYG",
  "RWF",
  "VND",
  "VUV",
  "XAF",
  "XOF",
  "XPF",
]);

/**
 * Stripe three-decimal currencies (unit_amount is in thousandths; Stripe
 * requires the final digit to be divisible by 10 for card charges).
 */
const STRIPE_THREE_DECIMAL_CURRENCIES = new Set([
  "BHD",
  "JOD",
  "KWD",
  "OMR",
  "TND",
]);

function normalizeCountryCode(value) {
  return String(value || "").trim().toUpperCase();
}

function isCountryBlockedForStripePayments(countryCode, regionText = "") {
  const code = normalizeCountryCode(countryCode);
  if (!code) return false;
  if (STRIPE_SANCTIONED_COUNTRY_SET.has(code)) {
    return true;
  }
  if (code === "UA" && OCCUPIED_UKRAINE_REGION_PATTERN.test(String(regionText || ""))) {
    return true;
  }
  return false;
}

function assertCountryPayableWithStripe(countryCode, regionText = "") {
  const code = normalizeCountryCode(countryCode);
  if (isCountryBlockedForStripePayments(code, regionText)) {
    throw new GlobalPaymentPolicyError(
        "permission-denied",
        `Online Stripe payments are unavailable for jurisdiction ${code} due to international sanctions and payment network restrictions.`,
    );
  }
  return code;
}

function isElevatedSanctionsCountry(countryCode) {
  return ELEVATED_SANCTIONS_COUNTRY_SET.has(normalizeCountryCode(countryCode));
}

function isStripeConnectSellerCountrySupported(countryCode) {
  return STRIPE_CA_CONNECT_SELLER_COUNTRY_SET.has(
      normalizeCountryCode(countryCode),
  );
}

function currencyExponent(currency) {
  const normalized = String(currency || "CAD").trim().toUpperCase();
  if (STRIPE_ZERO_DECIMAL_CURRENCIES.has(normalized)) return 0;
  if (STRIPE_THREE_DECIMAL_CURRENCIES.has(normalized)) return 3;
  return 2;
}

function hasValidCurrencyPrecision(amount, currency) {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric)) return false;
  const exp = currencyExponent(currency);
  const factor = Math.pow(10, exp);
  if (exp === 3) {
    // Allow up to 3 decimals (or 2 decimals for Stripe 10-fils rounding).
    return Math.abs(numeric * 1000 - Math.round(numeric * 1000)) <= 0.000001;
  }
  return Math.abs(numeric * factor - Math.round(numeric * factor)) <= 0.000001;
}

function toStripeMinorUnits(amount, currency = "CAD") {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric)) {
    throw new GlobalPaymentPolicyError(
        "invalid-argument",
        "Monetary amount must be finite.",
    );
  }
  const normalized = String(currency || "CAD").trim().toUpperCase();
  const exp = currencyExponent(normalized);
  const factor = Math.pow(10, exp);
  let minor = Math.round((numeric + Number.EPSILON) * factor);
  if (exp === 3 && minor % 10 !== 0) {
    // Stripe requires 3-decimal currencies (BHD, JOD, KWD, OMR, TND) to have
    // the least-significant digit equal to 0.
    minor = Math.round(minor / 10) * 10;
  }
  return minor;
}

function fromStripeMinorUnits(minor, currency = "CAD") {
  const exp = currencyExponent(currency);
  if (exp === 0) return Math.round(Number(minor || 0));
  const factor = Math.pow(10, exp);
  return Number((Number(minor || 0) / factor).toFixed(exp));
}

/**
 * Extracts settlement vs presentment currency amounts from a Stripe Checkout
 * Session so Stripe Adaptive Pricing (local currency conversion across 135+
 * buyer currencies) never causes false amount-mismatch failures in webhooks.
 */
function extractCheckoutSettlementAmounts(session) {
  const safeSession = session && typeof session === "object" ? session : {};
  const presentmentCurrency = String(safeSession.currency || "").toUpperCase();
  const presentmentSubtotalMinor = Number(safeSession.amount_subtotal || 0);
  const presentmentTotalMinor = Number(safeSession.amount_total || 0);
  const presentmentTaxMinor = Number(
      (safeSession.total_details && safeSession.total_details.amount_tax) || 0,
  );

  const conversion = safeSession.currency_conversion;
  if (
    conversion &&
    typeof conversion === "object" &&
    conversion.source_currency
  ) {
    const settlementCurrency = String(conversion.source_currency).toUpperCase();
    const settlementSubtotalMinor = Number(
        conversion.amount_subtotal != null ?
          conversion.amount_subtotal :
          presentmentSubtotalMinor,
    );
    const settlementTotalMinor = Number(
        conversion.amount_total != null ?
          conversion.amount_total :
          presentmentTotalMinor,
    );
    const settlementTaxMinor = Math.max(
        0,
        settlementTotalMinor - settlementSubtotalMinor,
    );
    return {
      adaptivePricingApplied: true,
      settlementCurrency,
      settlementSubtotalMinor,
      settlementTotalMinor,
      settlementTaxMinor,
      presentmentCurrency,
      presentmentSubtotalMinor,
      presentmentTotalMinor,
      presentmentTaxMinor,
      fxRate: conversion.fx_rate ? String(conversion.fx_rate) : null,
    };
  }

  return {
    adaptivePricingApplied: false,
    settlementCurrency: presentmentCurrency,
    settlementSubtotalMinor: presentmentSubtotalMinor,
    settlementTotalMinor: presentmentTotalMinor,
    settlementTaxMinor: presentmentTaxMinor,
    presentmentCurrency,
    presentmentSubtotalMinor,
    presentmentTotalMinor,
    presentmentTaxMinor,
    fxRate: null,
  };
}

function appendCheckoutReturnParams(rawUrl, params = {}) {
  const parsed = new URL(String(rawUrl || "").trim());
  for (const [key, value] of Object.entries(params)) {
    const clean = String(value == null ? "" : value).trim();
    if (clean) {
      parsed.searchParams.set(key, clean);
    }
  }
  return parsed.toString();
}

module.exports = {
  ELEVATED_SANCTIONS_COUNTRIES,
  GlobalPaymentPolicyError,
  STRIPE_CA_CONNECT_SELLER_COUNTRIES,
  STRIPE_SANCTIONED_COUNTRIES,
  appendCheckoutReturnParams,
  assertCountryPayableWithStripe,
  currencyExponent,
  extractCheckoutSettlementAmounts,
  fromStripeMinorUnits,
  hasValidCurrencyPrecision,
  isCountryBlockedForStripePayments,
  isElevatedSanctionsCountry,
  isStripeConnectSellerCountrySupported,
  normalizeCountryCode,
  toStripeMinorUnits,
};
