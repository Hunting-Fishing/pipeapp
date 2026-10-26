"use strict";

const {normalizeLogoUrl} = require("./business_logo_upload");

const INSURANCE_COVERAGE_LINES = Object.freeze([
  Object.freeze({
    code: "commercial_auto_fleet",
    label: "Commercial Auto & Crew Truck Fleet",
    shortLabel: "Commercial Auto & Fleet",
    description:
      "Primary auto liability, physical damage, MCS-90, and DOT/NSC filings for crew pickups, hotshots, vacuum trucks, and heavy haul tractors.",
  }),
  Object.freeze({
    code: "oilfield_general_liability",
    label: "Oilfield General Liability & MSA",
    shortLabel: "General Liability & MSA",
    description:
      "Occurrence commercial general liability structured for lease sites, upstream/midstream service contractors, and operator MSAs.",
  }),
  Object.freeze({
    code: "rig_equipment_inland_marine",
    label: "Rig / Heavy Equipment & Inland Marine",
    shortLabel: "Rig & Heavy Equipment",
    description:
      "Scheduled and blanket contractors equipment, drilling/workover rigs, yellow iron, pipe inventory, and downhole tools.",
  }),
  Object.freeze({
    code: "motor_truck_cargo_hazmat",
    label: "Motor Truck Cargo & Hazmat",
    shortLabel: "Cargo & Hazmat",
    description:
      "Broad-form OCTG pipe cargo, rig moves, oilfield fluid transit, loading/unloading, and hazmat cleanup extensions.",
  }),
  Object.freeze({
    code: "pollution_environmental",
    label: "Pollution & Environmental Liability",
    shortLabel: "Pollution & Environmental",
    description:
      "Contractors pollution liability (CPL), site environmental coverage, sudden & accidental time-element, and saltwater/fluid remediation.",
  }),
  Object.freeze({
    code: "umbrella_excess_liability",
    label: "Umbrella / Excess Liability",
    shortLabel: "Umbrella / Excess",
    description:
      "Follow-form excess liability towers from $1M to $25M+ engineered to satisfy Tier-1 E&P operator and pipeline MSA schedules.",
  }),
  Object.freeze({
    code: "workers_comp_crew",
    label: "Workers' Compensation & Crew Coverage",
    shortLabel: "Workers' Comp & Crew",
    description:
      "Statutory workers' compensation, employer's liability, stop-gap, USL&H offshore extensions, and provincial WCB coordination.",
  }),
  Object.freeze({
    code: "commercial_property_yards",
    label: "Commercial Property / Yards & Modulars",
    shortLabel: "Property, Yards & Modulars",
    description:
      "Fabrication facilities, pipe storage yards, skid offices, crew camps, modular buildings, and business interruption coverage.",
  }),
]);

const COVERAGE_LINE_BY_CODE = new Map(
    INSURANCE_COVERAGE_LINES.map((line) => [line.code, line]),
);

const COVERAGE_LINE_BY_LABEL = new Map(
    INSURANCE_COVERAGE_LINES.flatMap((line) => [
      [line.label.toLowerCase(), line.code],
      [line.shortLabel.toLowerCase(), line.code],
    ]),
);

const MSA_ENDORSEMENTS = Object.freeze([
  Object.freeze({
    code: "waiver_of_subrogation",
    label: "Waiver of Subrogation",
    description: "Blanket waiver of subrogation across GL, Auto, and Workers' Comp.",
  }),
  Object.freeze({
    code: "additional_insured",
    label: "Additional Insured (Ongoing & Completed Ops)",
    description: "Blanket additional insured endorsements matching ISO CG 20 10 / CG 20 37.",
  }),
  Object.freeze({
    code: "primary_non_contributory",
    label: "Primary & Non-Contributory",
    description: "Primary and non-contributory wording required by operator MSAs.",
  }),
  Object.freeze({
    code: "thirty_day_cancellation_notice",
    label: "30-Day Notice of Cancellation",
    description: "30-day advance written notice of cancellation to certificate holders.",
  }),
  Object.freeze({
    code: "hired_non_owned_auto",
    label: "Hired & Non-Owned Auto",
    description: "Hired and non-owned commercial auto liability extension.",
  }),
  Object.freeze({
    code: "sudden_accidental_pollution",
    label: "Sudden & Accidental Pollution",
    description: "Time-element sudden and accidental oilfield pollution buyback.",
  }),
]);

const MSA_ENDORSEMENT_CODES = new Set(MSA_ENDORSEMENTS.map((item) => item.code));

const ANNUAL_REVENUE_BANDS = Object.freeze([
  Object.freeze({code: "under_500k", label: "Under $500K"}),
  Object.freeze({code: "500k_2m", label: "$500K - $2M"}),
  Object.freeze({code: "2m_10m", label: "$2M - $10M"}),
  Object.freeze({code: "10m_50m", label: "$10M - $50M"}),
  Object.freeze({code: "50m_plus", label: "$50M+"}),
]);

const REVENUE_BAND_CODES = new Set(ANNUAL_REVENUE_BANDS.map((band) => band.code));

const FLEET_SIZE_BANDS = Object.freeze([
  Object.freeze({
    code: "no_fleet",
    label: "0 Vehicles (Equipment / GL Only)",
    minVehicles: 0,
    maxVehicles: 0,
  }),
  Object.freeze({
    code: "1_5_units",
    label: "1 - 5 Vehicles",
    minVehicles: 1,
    maxVehicles: 5,
  }),
  Object.freeze({
    code: "6_25_units",
    label: "6 - 25 Vehicles",
    minVehicles: 6,
    maxVehicles: 25,
  }),
  Object.freeze({
    code: "26_100_units",
    label: "26 - 100 Vehicles",
    minVehicles: 26,
    maxVehicles: 100,
  }),
  Object.freeze({
    code: "100_plus_units",
    label: "100+ Vehicles",
    minVehicles: 101,
    maxVehicles: 999999,
  }),
]);

const INSURANCE_PROVIDER_TYPES = Object.freeze([
  "carrier",
  "mga",
  "specialty_broker",
]);
const PROVIDER_TYPE_SET = new Set(INSURANCE_PROVIDER_TYPES);

const RATE_APPLICATION_STATUSES = Object.freeze([
  "new",
  "matching",
  "quoted",
  "bound",
  "closed",
]);
const RATE_STATUS_SET = new Set(RATE_APPLICATION_STATUSES);

const PROVIDER_APPLICATION_STATUSES = Object.freeze([
  "pending_review",
  "approved",
  "declined",
]);
const PROVIDER_APPLICATION_STATUS_SET = new Set(PROVIDER_APPLICATION_STATUSES);

class InsurancePolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "InsurancePolicyError";
    this.code = code;
  }
}

function cleanText(value, maxLength = 500) {
  const normalized = String(value == null ? "" : value).trim();
  return normalized.length <= maxLength ?
    normalized :
    normalized.slice(0, maxLength);
}

function requiredText(data, fieldName, maxLength = 200, minLength = 2) {
  const value = String(data && data[fieldName] != null ? data[fieldName] : "").trim();
  if (value.length < minLength || value.length > maxLength) {
    throw new InsurancePolicyError(
        "invalid-argument",
        `${fieldName} must be between ${minLength} and ${maxLength} characters.`,
    );
  }
  return value;
}

function optionalText(data, fieldName, maxLength = 500) {
  const value = String(data && data[fieldName] != null ? data[fieldName] : "").trim();
  if (value.length > maxLength) {
    throw new InsurancePolicyError(
        "invalid-argument",
        `${fieldName} cannot exceed ${maxLength} characters.`,
    );
  }
  return value;
}

function normalizedCompanyKey(value) {
  return cleanText(value, 200)
      .toLowerCase()
      .replace(/[^a-z0-9\s]/gu, " ")
      .replace(
          /\b(ltd|limited|inc|incorporated|corp|corporation|llc|llp|plc|co|company|insurance|group)\b/gu,
          "",
      )
      .trim()
      .replace(/\s+/gu, " ");
}

function validateEmail(raw, fieldName = "email") {
  const email = String(raw == null ? "" : raw).trim().toLowerCase();
  if (!email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/u.test(email)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        `A valid ${fieldName} address is required.`,
    );
  }
  return email;
}

function validatePhone(raw, fieldName = "phone") {
  const display = cleanText(raw, 60);
  const digits = display.replace(/\D+/gu, "");
  if (digits.length < 7 || digits.length > 15) {
    throw new InsurancePolicyError(
        "invalid-argument",
        `A valid ${fieldName} number is required.`,
    );
  }
  if (digits.length === 10) {
    return `(${digits.slice(0, 3)}) ${digits.slice(3, 6)}-${digits.slice(6)}`;
  }
  if (digits.length === 11 && digits.startsWith("1")) {
    return `+1 (${digits.slice(1, 4)}) ${digits.slice(4, 7)}-${digits.slice(7)}`;
  }
  return display;
}

function normalizeWebsite(raw) {
  const trimmed = String(raw == null ? "" : raw).trim();
  if (!trimmed) return "";
  if (trimmed.length > 500) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "website cannot exceed 500 characters.",
    );
  }
  const candidate = /^https?:\/\//iu.test(trimmed) ? trimmed : `https://${trimmed}`;
  let parsed;
  try {
    parsed = new URL(candidate);
  } catch (_) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Enter a valid website URL.",
    );
  }
  if (!["http:", "https:"].includes(parsed.protocol) || !parsed.hostname.includes(".")) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Enter a valid website URL.",
    );
  }
  return parsed.toString();
}

function normalizeStringList(value, maxItems = 20, maxLength = 100) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const output = [];
  for (const rawItem of value) {
    const item = cleanText(rawItem, maxLength);
    if (!item) continue;
    const key = item.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(item);
    if (output.length >= maxItems) break;
  }
  return output;
}

function normalizeCountryCode(raw, {fallback = "US"} = {}) {
  const value = String(raw == null ? "" : raw).trim().toUpperCase();
  if (!value) return fallback;
  if (!/^[A-Z]{2}$/u.test(value)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "countryCode must be a 2-letter ISO country code.",
    );
  }
  return value;
}

function normalizeRegionCode(raw) {
  const value = String(raw == null ? "" : raw).trim().toUpperCase();
  if (!value) return "";
  if (value.length > 20 || !/^[A-Z0-9 -]+$/u.test(value)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "regionCode contains unsupported characters.",
    );
  }
  return value;
}

function normalizeCoverageLines(rawLines, {required = true} = {}) {
  if (!Array.isArray(rawLines)) {
    if (required) {
      throw new InsurancePolicyError(
          "invalid-argument",
          "Select at least one insurance coverage line.",
      );
    }
    return [];
  }
  const seen = new Set();
  const normalized = [];
  for (const raw of rawLines) {
    const token = String(raw == null ? "" : raw).trim();
    if (!token) continue;
    const lower = token.toLowerCase();
    const resolved = COVERAGE_LINE_BY_CODE.has(lower) ?
      lower :
      COVERAGE_LINE_BY_LABEL.get(lower);
    if (!resolved) {
      throw new InsurancePolicyError(
          "invalid-argument",
          `Unsupported insurance coverage line: ${token}.`,
      );
    }
    if (!seen.has(resolved)) {
      seen.add(resolved);
      normalized.push(resolved);
    }
  }
  if (required && normalized.length === 0) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Select at least one insurance coverage line.",
    );
  }
  return normalized;
}

function normalizeMsaRequirements(rawList) {
  if (rawList == null) return [];
  if (!Array.isArray(rawList)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "msaRequirements must be an array.",
    );
  }
  const seen = new Set();
  const normalized = [];
  for (const raw of rawList) {
    const code = String(raw == null ? "" : raw).trim().toLowerCase();
    if (!code) continue;
    if (!MSA_ENDORSEMENT_CODES.has(code)) {
      throw new InsurancePolicyError(
          "invalid-argument",
          `Unsupported MSA endorsement requirement: ${code}.`,
      );
    }
    if (!seen.has(code)) {
      seen.add(code);
      normalized.push(code);
    }
  }
  return normalized;
}

function resolveFleetSizeBand(vehicleCount) {
  const count = Math.max(0, Math.trunc(Number(vehicleCount) || 0));
  for (const band of FLEET_SIZE_BANDS) {
    if (count >= band.minVehicles && count <= band.maxVehicles) {
      return band.code;
    }
  }
  return "100_plus_units";
}

function normalizeNonNegativeNumber(raw, fieldName, maxValue, {integer = false} = {}) {
  if (raw == null || raw === "") return 0;
  const parsed = Number(raw);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > maxValue) {
    throw new InsurancePolicyError(
        "invalid-argument",
        `${fieldName} must be a number between 0 and ${maxValue}.`,
    );
  }
  return integer ? Math.trunc(parsed) : Math.round(parsed * 100) / 100;
}

function normalizeDesiredEffectiveDate(raw) {
  const trimmed = String(raw == null ? "" : raw).trim();
  if (!trimmed) return "";
  if (/^\d{4}-\d{2}-\d{2}$/u.test(trimmed)) {
    const parsed = Date.parse(`${trimmed}T00:00:00Z`);
    if (Number.isNaN(parsed)) {
      throw new InsurancePolicyError(
          "invalid-argument",
          "desiredEffectiveDate is not a valid calendar date.",
      );
    }
    return trimmed;
  }
  const parsed = new Date(trimmed);
  if (Number.isNaN(parsed.getTime())) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "desiredEffectiveDate must be a valid date (YYYY-MM-DD).",
    );
  }
  return parsed.toISOString().slice(0, 10);
}

function validateSafeEntityId(raw, fieldName) {
  const value = String(raw == null ? "" : raw).trim();
  if (!value) return "";
  if (value.length > 180 || value.includes("/")) {
    throw new InsurancePolicyError(
        "invalid-argument",
        `${fieldName} is invalid.`,
    );
  }
  return value;
}

function validateInsuranceRateApplication(input) {
  if (!input || typeof input !== "object") {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Rate application details are required.",
    );
  }

  const companyName = requiredText(input, "companyName", 200, 2);
  const contactName = requiredText(input, "contactName", 140, 2);
  const email = validateEmail(input.email, "email");
  const phone = validatePhone(input.phone, "phone");
  const countryCode = normalizeCountryCode(input.countryCode, {fallback: "US"});
  const regionCode = normalizeRegionCode(input.regionCode);
  const city = optionalText(input, "city", 120);
  const operatingBasins = normalizeStringList(input.operatingBasins, 16, 80);
  const coverageLines = normalizeCoverageLines(input.coverageLines, {required: true});
  const msaRequirements = normalizeMsaRequirements(input.msaRequirements);
  const fleetVehicleCount = normalizeNonNegativeNumber(
      input.fleetVehicleCount,
      "fleetVehicleCount",
      100000,
      {integer: true},
  );
  const equipmentValueUsd = normalizeNonNegativeNumber(
      input.equipmentValueUsd,
      "equipmentValueUsd",
      10000000000,
  );

  const rawRevenueBand = String(
      input.annualRevenueBand == null ? "" : input.annualRevenueBand,
  ).trim();
  const annualRevenueBand = rawRevenueBand || "500k_2m";
  if (!REVENUE_BAND_CODES.has(annualRevenueBand)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Select an approved annualRevenueBand.",
    );
  }

  const dotOrMcNumber = optionalText(input, "dotOrMcNumber", 60);
  const desiredEffectiveDate = normalizeDesiredEffectiveDate(
      input.desiredEffectiveDate,
  );
  const claimsSummary = optionalText(input, "claimsSummary", 2000);
  const targetProviderId = validateSafeEntityId(
      input.targetProviderId,
      "targetProviderId",
  );
  const targetProviderName = optionalText(input, "targetProviderName", 200);
  const notes = optionalText(input, "notes", 2500);

  return {
    companyName,
    normalizedCompanyName: normalizedCompanyKey(companyName),
    contactName,
    email,
    phone,
    countryCode,
    regionCode,
    city,
    operatingBasins,
    coverageLines,
    msaRequirements,
    fleetVehicleCount,
    fleetSizeBand: resolveFleetSizeBand(fleetVehicleCount),
    equipmentValueUsd,
    annualRevenueBand,
    dotOrMcNumber,
    desiredEffectiveDate,
    claimsSummary,
    targetProviderId: targetProviderId || null,
    targetProviderName: targetProviderId ? targetProviderName : "",
    distributionMode: targetProviderId ? "single_provider" : "multi_carrier",
    notes,
  };
}

function normalizeCountryList(rawCountries, fallback = ["US"]) {
  if (!Array.isArray(rawCountries) || rawCountries.length === 0) {
    return [...fallback];
  }
  const seen = new Set();
  const result = [];
  for (const item of rawCountries) {
    const token = String(item == null ? "" : item).trim().toUpperCase();
    if (!token) continue;
    const code = normalizeCountryCode(token);
    if (!seen.has(code)) {
      seen.add(code);
      result.push(code);
    }
    if (result.length >= 40) break;
  }
  return result.length > 0 ? result : [...fallback];
}

function normalizeRegionList(rawRegions) {
  if (!Array.isArray(rawRegions)) return [];
  const seen = new Set();
  const result = [];
  for (const item of rawRegions) {
    const code = normalizeRegionCode(item);
    if (!code || seen.has(code)) continue;
    seen.add(code);
    result.push(code);
    if (result.length >= 80) break;
  }
  return result;
}

function validateInsuranceProviderApplication(input) {
  if (!input || typeof input !== "object") {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Insurance provider application details are required.",
    );
  }

  const companyName = requiredText(input, "companyName", 200, 2);
  const providerType = String(
      input.providerType == null ? "" : input.providerType,
  ).trim().toLowerCase();
  if (!PROVIDER_TYPE_SET.has(providerType)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "providerType must be carrier, mga, or specialty_broker.",
    );
  }

  const contactName = requiredText(input, "contactName", 140, 2);
  const contactTitle = optionalText(input, "contactTitle", 120);
  const email = validateEmail(input.email, "email");
  const phone = validatePhone(input.phone, "phone");
  const website = normalizeWebsite(input.website);
  const logoUrl = normalizeLogoUrl(input.logoUrl, {
    ErrorClass: InsurancePolicyError,
    fieldName: "logoUrl",
  });
  const licenseSummary = requiredText(input, "licenseSummary", 1000, 3);
  const licensedCountries = normalizeCountryList(input.licensedCountries, ["US"]);
  const licensedRegions = normalizeRegionList(input.licensedRegions);
  const coverageLines = normalizeCoverageLines(input.coverageLines, {required: true});
  const amBestRating = optionalText(input, "amBestRating", 60);
  const maxLimitUsd = normalizeNonNegativeNumber(
      input.maxLimitUsd,
      "maxLimitUsd",
      1000000000,
  );
  const fastCoi24x7 = input.fastCoi24x7 === true;
  const msaCompliant = input.msaCompliant === true;
  const minimumPremiumUsd = normalizeNonNegativeNumber(
      input.minimumPremiumUsd,
      "minimumPremiumUsd",
      100000000,
  );
  const summary = optionalText(input, "summary", 2500);
  const headquartersCity = optionalText(input, "headquartersCity", 120) ||
    optionalText(input, "city", 120);
  const countryCode = normalizeCountryCode(
      input.countryCode || licensedCountries[0],
      {fallback: licensedCountries[0] || "US"},
  );
  const regionCode = normalizeRegionCode(
      input.regionCode || licensedRegions[0] || "",
  );
  const operatingBasins = normalizeStringList(input.operatingBasins, 16, 80);

  return {
    companyName,
    normalizedCompanyName: normalizedCompanyKey(companyName),
    providerType,
    contactName,
    contactTitle,
    email,
    phone,
    website,
    logoUrl,
    licenseSummary,
    countryCode,
    regionCode,
    headquartersCity,
    licensedCountries,
    licensedRegions,
    operatingBasins,
    coverageLines,
    amBestRating,
    maxLimitUsd,
    fastCoi24x7,
    msaCompliant,
    minimumPremiumUsd,
    summary,
  };
}

function buildProviderSearchTokens(record) {
  const tokens = new Set();
  const addWords = (raw) => {
    const clean = String(raw == null ? "" : raw)
        .toLowerCase()
        .replace(/[^a-z0-9\s]/gu, " ");
    for (const word of clean.split(/\s+/u)) {
      if (word.length >= 2 && tokens.size < 250) {
        tokens.add(word.slice(0, 32));
      }
    }
  };

  addWords(record.companyName);
  addWords(record.providerType);
  addWords(record.headquartersCity);
  addWords(record.countryCode);
  addWords(record.regionCode);
  addWords(record.amBestRating);
  addWords(record.summary);

  for (const country of record.licensedCountries || []) {
    tokens.add(String(country).toLowerCase());
  }
  for (const region of record.licensedRegions || []) {
    tokens.add(String(region).toLowerCase());
  }
  for (const basin of record.operatingBasins || []) {
    addWords(basin);
  }
  for (const lineCode of record.coverageLines || []) {
    tokens.add(lineCode);
    const line = COVERAGE_LINE_BY_CODE.get(lineCode);
    if (line) {
      addWords(line.label);
      addWords(line.shortLabel);
    }
  }
  return [...tokens].slice(0, 250);
}

function computeProviderPriorityScore(record) {
  let score = 100;
  if (record.featured === true) score += 100;
  if (record.msaCompliant === true) score += 20;
  if (record.fastCoi24x7 === true) score += 15;
  if (record.amBestRating) score += 10;
  if (record.logoUrl) score += 5;
  score += Math.min(24, (record.coverageLines || []).length * 3);
  return score;
}

function normalizeInsuranceProviderRecord(input) {
  if (!input || typeof input !== "object") {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Insurance provider record details are required.",
    );
  }

  const companyName = requiredText(input, "companyName", 200, 2);
  const rawType = String(
      input.providerType == null ? "specialty_broker" : input.providerType,
  ).trim().toLowerCase() || "specialty_broker";
  if (!PROVIDER_TYPE_SET.has(rawType)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "providerType must be carrier, mga, or specialty_broker.",
    );
  }

  const licensedCountries = normalizeCountryList(
      input.licensedCountries,
      input.countryCode ? [normalizeCountryCode(input.countryCode)] : ["US"],
  );
  const licensedRegions = normalizeRegionList(input.licensedRegions);
  const countryCode = normalizeCountryCode(
      input.countryCode || licensedCountries[0],
      {fallback: "US"},
  );
  const regionCode = normalizeRegionCode(
      input.regionCode || licensedRegions[0] || "",
  );
  const headquartersCity = optionalText(input, "headquartersCity", 120) ||
    optionalText(input, "city", 120);
  const coverageLines = normalizeCoverageLines(input.coverageLines, {required: true});
  const msaCapabilities = normalizeMsaRequirements(input.msaCapabilities);

  const rawPublicEmail = String(
      input.publicEmail != null ? input.publicEmail : (input.email || ""),
  ).trim();
  const publicEmail = rawPublicEmail ?
    validateEmail(rawPublicEmail, "publicEmail") :
    "";

  const rawPublicPhone = String(
      input.publicPhone != null ? input.publicPhone : (input.phone || ""),
  ).trim();
  const publicPhone = rawPublicPhone ?
    validatePhone(rawPublicPhone, "publicPhone") :
    "";

  const rawInternalEmail = String(input.internalContactEmail || "").trim();
  const internalContactEmail = rawInternalEmail ?
    validateEmail(rawInternalEmail, "internalContactEmail") :
    "";

  const rawInternalPhone = String(input.internalContactPhone || "").trim();
  const internalContactPhone = rawInternalPhone ?
    validatePhone(rawInternalPhone, "internalContactPhone") :
    "";

  const record = {
    companyName,
    normalizedCompanyName: normalizedCompanyKey(companyName),
    providerType: rawType,
    contactName: optionalText(input, "contactName", 140),
    contactTitle: optionalText(input, "contactTitle", 120),
    publicEmail,
    publicPhone,
    website: normalizeWebsite(input.website),
    logoUrl: normalizeLogoUrl(input.logoUrl, {
      ErrorClass: InsurancePolicyError,
      fieldName: "logoUrl",
    }),
    countryCode,
    regionCode,
    headquartersCity,
    licensedCountries,
    licensedRegions,
    operatingBasins: normalizeStringList(input.operatingBasins, 16, 80),
    coverageLines,
    coverageLabels: coverageLines
        .map((code) => COVERAGE_LINE_BY_CODE.get(code)?.label || code),
    msaCapabilities,
    licenseSummary: optionalText(input, "licenseSummary", 1000),
    amBestRating: optionalText(input, "amBestRating", 60),
    maxLimitUsd: normalizeNonNegativeNumber(
        input.maxLimitUsd,
        "maxLimitUsd",
        1000000000,
    ),
    minimumPremiumUsd: normalizeNonNegativeNumber(
        input.minimumPremiumUsd,
        "minimumPremiumUsd",
        100000000,
    ),
    fastCoi24x7: input.fastCoi24x7 === true,
    msaCompliant: input.msaCompliant === true,
    featured: input.featured === true,
    verified: input.verified !== false,
    active: input.active !== false,
    summary: optionalText(input, "summary", 2500),
    highlights: normalizeStringList(input.highlights, 10, 140),
    adminNotes: optionalText(input, "adminNotes", 3000),
    internalContactEmail,
    internalContactPhone,
  };

  record.priorityScore = computeProviderPriorityScore(record);
  record.searchTokens = buildProviderSearchTokens(record);
  return record;
}

function toPublicInsuranceProvider(record) {
  if (!record || typeof record !== "object") {
    throw new InsurancePolicyError(
        "invalid-argument",
        "A valid provider record is required for public projection.",
    );
  }
  const normalized = normalizeInsuranceProviderRecord(record);
  const providerId = validateSafeEntityId(
      record.providerId || record.id || "",
      "providerId",
  );
  return {
    ...(providerId ? {providerId} : {}),
    companyName: normalized.companyName,
    normalizedCompanyName: normalized.normalizedCompanyName,
    providerType: normalized.providerType,
    publicEmail: normalized.publicEmail,
    publicPhone: normalized.publicPhone,
    website: normalized.website,
    logoUrl: normalized.logoUrl,
    countryCode: normalized.countryCode,
    regionCode: normalized.regionCode,
    headquartersCity: normalized.headquartersCity,
    licensedCountries: normalized.licensedCountries,
    licensedRegions: normalized.licensedRegions,
    operatingBasins: normalized.operatingBasins,
    coverageLines: normalized.coverageLines,
    coverageLabels: normalized.coverageLabels,
    msaCapabilities: normalized.msaCapabilities,
    licenseSummary: normalized.licenseSummary,
    amBestRating: normalized.amBestRating,
    maxLimitUsd: normalized.maxLimitUsd,
    minimumPremiumUsd: normalized.minimumPremiumUsd,
    fastCoi24x7: normalized.fastCoi24x7,
    msaCompliant: normalized.msaCompliant,
    featured: normalized.featured,
    verified: normalized.verified,
    active: normalized.active,
    summary: normalized.summary,
    highlights: normalized.highlights,
    priorityScore: normalized.priorityScore,
    searchTokens: normalized.searchTokens,
  };
}

function assertRateApplicationStatusTransition(fromStatus, toStatus) {
  const from = String(fromStatus == null ? "" : fromStatus).trim().toLowerCase();
  const to = String(toStatus == null ? "" : toStatus).trim().toLowerCase();
  if (!RATE_STATUS_SET.has(from) || !RATE_STATUS_SET.has(to)) {
    throw new InsurancePolicyError(
        "invalid-argument",
        "Select a valid rate application status (new, matching, quoted, bound, closed).",
    );
  }
  if (from === to) return to;

  const allowed = {
    new: new Set(["matching", "quoted", "closed"]),
    matching: new Set(["quoted", "bound", "closed"]),
    quoted: new Set(["matching", "bound", "closed"]),
    bound: new Set(["closed"]),
    closed: new Set([]),
  }[from];

  if (!allowed || !allowed.has(to)) {
    throw new InsurancePolicyError(
        "failed-precondition",
        `Cannot transition insurance rate application from ${from} to ${to}.`,
    );
  }
  return to;
}

module.exports = {
  ANNUAL_REVENUE_BANDS,
  COVERAGE_LINE_BY_CODE,
  FLEET_SIZE_BANDS,
  INSURANCE_COVERAGE_LINES,
  INSURANCE_PROVIDER_TYPES,
  InsurancePolicyError,
  MSA_ENDORSEMENTS,
  MSA_ENDORSEMENT_CODES,
  PROVIDER_APPLICATION_STATUSES,
  PROVIDER_APPLICATION_STATUS_SET,
  RATE_APPLICATION_STATUSES,
  RATE_STATUS_SET,
  assertRateApplicationStatusTransition,
  computeProviderPriorityScore,
  normalizeCoverageLines,
  normalizeInsuranceProviderRecord,
  normalizeMsaRequirements,
  resolveFleetSizeBand,
  toPublicInsuranceProvider,
  validateInsuranceProviderApplication,
  validateInsuranceRateApplication,
};
