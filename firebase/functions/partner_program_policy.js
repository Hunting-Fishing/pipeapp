"use strict";

const {normalizeLogoUrl} = require("./business_logo_upload");

const PARTNER_BRAND_CATEGORIES = Object.freeze([
  Object.freeze({
    code: "oem_fleet_crew_trucks",
    label: "OEM Vehicles, Fleet & Crew Trucks",
    shortLabel: "Fleet & Crew Trucks",
  }),
  Object.freeze({
    code: "oilfield_deals_discounts",
    label: "Oilfield Crew Deals & Corporate Discounts",
    shortLabel: "Oilfield Deals",
  }),
  Object.freeze({
    code: "heavy_equipment_machinery",
    label: "Heavy Equipment & Rig Machinery",
    shortLabel: "Heavy Equipment",
  }),
  Object.freeze({
    code: "pipe_valves_tubulars",
    label: "Pipe, OCTG, Valves & Fittings",
    shortLabel: "Pipe & OCTG",
  }),
  Object.freeze({
    code: "tools_ppe_site_gear",
    label: "Industrial Tools, Safety PPE & Crew Gear",
    shortLabel: "Tools & Safety PPE",
  }),
  Object.freeze({
    code: "modular_site_buildings",
    label: "Modular Offices, Camps & Site Buildings",
    shortLabel: "Site Buildings",
  }),
  Object.freeze({
    code: "fuel_fleet_logistics",
    label: "Fuel Cards, Telematics & Fleet Logistics",
    shortLabel: "Fuel & Fleet Ops",
  }),
  Object.freeze({
    code: "industrial_tech_services",
    label: "Field Software & Industrial Services",
    shortLabel: "Tech & Services",
  }),
]);

const PARTNER_BRAND_CATEGORY_CODES = new Set(
    PARTNER_BRAND_CATEGORIES.map((item) => item.code),
);

const PARTNER_PROGRAM_TYPES = Object.freeze([
  Object.freeze({
    code: "promote_brand",
    label: "Promote Brand & OEM Presence",
  }),
  Object.freeze({
    code: "advertise_campaigns",
    label: "Targeted Site & Category Advertising",
  }),
  Object.freeze({
    code: "showcase_sell_products",
    label: "Showcase & Sell Products on Pipe Buyer",
  }),
  Object.freeze({
    code: "oilfield_deals_discounts",
    label: "Exclusive Oilfield Deals & Fleet Rebates",
  }),
]);

const PARTNER_PROGRAM_TYPE_CODES = new Set(
    PARTNER_PROGRAM_TYPES.map((item) => item.code),
);

const PARTNER_COMMERCIAL_MODELS = Object.freeze([
  "sponsored_showcase",
  "direct_marketplace_storefront",
  "member_fleet_discount",
  "category_banner_ads",
  "custom_enterprise",
]);

const PARTNER_COMMERCIAL_MODEL_SET = new Set(PARTNER_COMMERCIAL_MODELS);

const PARTNER_INQUIRY_STATUSES = Object.freeze([
  "new",
  "in_review",
  "approved",
  "declined",
  "archived",
]);

const PARTNER_INQUIRY_STATUS_SET = new Set(PARTNER_INQUIRY_STATUSES);

const ALLOWED_STATUS_TRANSITIONS = Object.freeze({
  new: new Set(["new", "in_review", "approved", "declined", "archived"]),
  in_review: new Set(["in_review", "approved", "declined", "archived"]),
  approved: new Set(["approved", "in_review", "archived"]),
  declined: new Set(["declined", "in_review", "archived"]),
  archived: new Set(["archived", "in_review"]),
});

class PartnerProgramPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PartnerProgramPolicyError";
    this.code = code;
  }
}

function cleanText(value, maxLength = 500) {
  const normalized = String(value == null ? "" : value)
      .replace(/\s+/gu, " ")
      .trim();
  if (normalized.length > maxLength) {
    return normalized.slice(0, maxLength).trim();
  }
  return normalized;
}

function cleanMultilineText(value, maxLength = 2000) {
  const normalized = String(value == null ? "" : value)
      .replace(/\r\n/gu, "\n")
      .replace(/[ \t]+/gu, " ")
      .trim();
  if (normalized.length > maxLength) {
    return normalized.slice(0, maxLength).trim();
  }
  return normalized;
}

function requireText(value, fieldLabel, {min = 2, max = 160} = {}) {
  const cleaned = cleanText(value, max + 20);
  if (cleaned.length < min || cleaned.length > max) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        `${fieldLabel} must be between ${min} and ${max} characters.`,
    );
  }
  return cleaned;
}

function validateEmail(value, fieldLabel = "Email") {
  const cleaned = cleanText(value, 180).toLowerCase();
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/u;
  if (!cleaned || !emailPattern.test(cleaned)) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        `Enter a valid ${fieldLabel.toLowerCase()}.`,
    );
  }
  return cleaned;
}

function validatePhone(value, {required = true} = {}) {
  const cleaned = cleanText(value, 40);
  if (!cleaned) {
    if (required) {
      throw new PartnerProgramPolicyError(
          "invalid-argument",
          "Enter a valid contact phone number.",
      );
    }
    return "";
  }
  const digits = cleaned.replace(/\D/gu, "");
  if (digits.length < 7 || digits.length > 18) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Phone number must include between 7 and 18 digits.",
    );
  }
  return cleaned;
}

function normalizeWebsiteUrl(value, {required = false} = {}) {
  const raw = cleanText(value, 300);
  if (!raw) {
    if (required) {
      throw new PartnerProgramPolicyError(
          "invalid-argument",
          "Website or landing page URL is required.",
      );
    }
    return "";
  }
  const candidate = /^https?:\/\//iu.test(raw) ? raw : `https://${raw}`;
  let parsed;
  try {
    parsed = new URL(candidate);
  } catch (err) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Enter a valid https:// website URL.",
    );
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Website URL must use http or https.",
    );
  }
  if (!parsed.hostname || !parsed.hostname.includes(".")) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Enter a valid domain name for the website URL.",
    );
  }
  return parsed.toString();
}

function normalizeStringList(raw, {maxItems = 12, maxItemLength = 80} = {}) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const out = [];
  for (const item of raw) {
    const cleaned = cleanText(item, maxItemLength);
    if (!cleaned) continue;
    const key = cleaned.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(cleaned);
    if (out.length >= maxItems) break;
  }
  return out;
}

function validateProgramTypes(raw) {
  const list = Array.isArray(raw) ? raw : [];
  const normalized = [];
  for (const entry of list) {
    const code = cleanText(entry, 64);
    if (!code) continue;
    if (!PARTNER_PROGRAM_TYPE_CODES.has(code)) {
      throw new PartnerProgramPolicyError(
          "invalid-argument",
          `Unsupported partnership program type: ${code}.`,
      );
    }
    if (!normalized.includes(code)) {
      normalized.push(code);
    }
  }
  if (normalized.length === 0) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Select at least one partnership or advertising program.",
    );
  }
  return normalized;
}

function validateBrandCategory(raw) {
  const code = cleanText(raw, 64);
  if (!PARTNER_BRAND_CATEGORY_CODES.has(code)) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Select a valid partner industry or brand category.",
    );
  }
  return code;
}

function validatePartnerInquiryInput(input = {}) {
  const companyName = requireText(input.companyName, "Company or brand name", {
    min: 2,
    max: 140,
  });
  const brandCategory = validateBrandCategory(input.brandCategory);
  const programTypes = validateProgramTypes(input.programTypes);

  const rawModel = cleanText(input.commercialModel, 64) || "sponsored_showcase";
  if (!PARTNER_COMMERCIAL_MODEL_SET.has(rawModel)) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Select a valid commercial partnership model.",
    );
  }

  const headline = requireText(
      input.headline,
      "Campaign or product showcase headline",
      {min: 4, max: 160},
  );
  const productSummary = cleanMultilineText(input.productSummary, 2000);
  if (productSummary.length < 10) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Describe the products, fleet program, or promotion (at least 10 characters).",
    );
  }

  const dealOrDiscountOffer = cleanText(input.dealOrDiscountOffer, 240);
  const targetRegions = normalizeStringList(input.targetRegions, {
    maxItems: 12,
    maxItemLength: 64,
  });
  const effectiveRegions = targetRegions.length > 0 ?
    targetRegions : ["North America"];

  let estimatedMonthlyBudgetUsd = null;
  if (input.estimatedMonthlyBudgetUsd != null &&
      String(input.estimatedMonthlyBudgetUsd).trim() !== "") {
    const numeric = Number(input.estimatedMonthlyBudgetUsd);
    if (!Number.isFinite(numeric) || numeric < 0 || numeric > 10000000) {
      throw new PartnerProgramPolicyError(
          "invalid-argument",
          "Estimated monthly budget must be between 0 and 10,000,000 USD.",
      );
    }
    estimatedMonthlyBudgetUsd = Math.round(numeric);
  }

  const contactName = requireText(input.contactName, "Contact name", {
    min: 2,
    max: 120,
  });
  const contactTitle = cleanText(input.contactTitle, 120);
  const email = validateEmail(input.email, "Corporate email");
  const phone = validatePhone(input.phone, {required: true});
  const website = normalizeWebsiteUrl(input.website, {required: false});
  const logoUrl = normalizeLogoUrl(input.logoUrl, {
    ErrorClass: PartnerProgramPolicyError,
    fieldName: "logoUrl",
  });
  const notes = cleanMultilineText(input.notes, 2000);

  return {
    companyName,
    brandCategory,
    programTypes,
    commercialModel: rawModel,
    headline,
    productSummary,
    dealOrDiscountOffer,
    targetRegions: effectiveRegions,
    estimatedMonthlyBudgetUsd,
    contactName,
    contactTitle,
    email,
    phone,
    website,
    logoUrl,
    notes,
  };
}

function normalizePartnerShowcaseDeal(input = {}) {
  const partnerName = requireText(input.partnerName, "Partner or brand name", {
    min: 2,
    max: 140,
  });
  const brandCategory = validateBrandCategory(input.brandCategory);
  const programTypes = validateProgramTypes(
      Array.isArray(input.programTypes) && input.programTypes.length > 0 ?
        input.programTypes : ["showcase_sell_products"],
  );
  const headline = requireText(input.headline, "Showcase headline", {
    min: 4,
    max: 160,
  });
  const summary = cleanMultilineText(input.summary, 1600);
  if (summary.length < 10) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Showcase summary must be at least 10 characters.",
    );
  }
  const offerBadge = cleanText(input.offerBadge, 64) || "Featured Partner";
  const discountDetails = cleanText(input.discountDetails, 240);
  const productHighlights = normalizeStringList(input.productHighlights, {
    maxItems: 10,
    maxItemLength: 90,
  });
  const targetRegions = normalizeStringList(input.targetRegions, {
    maxItems: 12,
    maxItemLength: 64,
  });
  const ctaLabel = cleanText(input.ctaLabel, 48) || "Request Fleet / Deal Info";
  const ctaUrl = normalizeWebsiteUrl(input.ctaUrl, {required: false});
  const logoUrl = normalizeLogoUrl(input.logoUrl, {
    ErrorClass: PartnerProgramPolicyError,
    fieldName: "logoUrl",
  });
  const contactEmail = input.contactEmail ?
    validateEmail(input.contactEmail, "Partner contact email") : "";
  const contactPhone = validatePhone(input.contactPhone, {required: false});
  const featured = input.featured === true;
  const active = input.active !== false;
  const rawRank = Number(input.priorityRank);
  const priorityRank = Number.isFinite(rawRank) ?
    Math.max(1, Math.min(999, Math.round(rawRank))) : (featured ? 10 : 100);
  const adminNotes = cleanMultilineText(input.adminNotes, 1500);

  return {
    partnerName,
    brandCategory,
    programTypes,
    headline,
    summary,
    offerBadge,
    discountDetails,
    productHighlights,
    targetRegions: targetRegions.length > 0 ? targetRegions : ["North America"],
    ctaLabel,
    ctaUrl,
    logoUrl,
    contactEmail,
    contactPhone,
    featured,
    active,
    priorityRank,
    adminNotes,
  };
}

function toPublicPartnerShowcaseDeal(showcaseId, record = {}) {
  return {
    showcaseId: String(showcaseId || record.showcaseId || "").trim(),
    partnerName: cleanText(record.partnerName, 140),
    brandCategory: cleanText(record.brandCategory, 64),
    programTypes: Array.isArray(record.programTypes) ?
      record.programTypes.map((item) => cleanText(item, 64)).filter(Boolean) :
      [],
    headline: cleanText(record.headline, 160),
    summary: cleanMultilineText(record.summary, 1600),
    offerBadge: cleanText(record.offerBadge, 64) || "Featured Partner",
    discountDetails: cleanText(record.discountDetails, 240),
    productHighlights: normalizeStringList(record.productHighlights, {
      maxItems: 10,
      maxItemLength: 90,
    }),
    targetRegions: normalizeStringList(record.targetRegions, {
      maxItems: 12,
      maxItemLength: 64,
    }),
    ctaLabel: cleanText(record.ctaLabel, 48) || "Request Fleet / Deal Info",
    ctaUrl: cleanText(record.ctaUrl, 300),
    logoUrl: normalizeLogoUrl(record.logoUrl),
    featured: record.featured === true,
    active: record.active !== false,
    priorityRank: Number.isFinite(Number(record.priorityRank)) ?
      Number(record.priorityRank) : 100,
  };
}

function validatePartnerDealInterestInput(input = {}) {
  const showcaseId = requireText(input.showcaseId, "Showcase identifier", {
    min: 2,
    max: 140,
  });
  if (showcaseId.includes("/")) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        "Showcase identifier is invalid.",
    );
  }
  const companyName = requireText(input.companyName, "Company name", {
    min: 2,
    max: 140,
  });
  const contactName = requireText(input.contactName, "Contact name", {
    min: 2,
    max: 120,
  });
  const email = validateEmail(input.email, "Work email");
  const phone = validatePhone(input.phone, {required: true});
  const fleetOrQuantityNeed = cleanText(input.fleetOrQuantityNeed, 160);
  const region = cleanText(input.region, 80);
  const message = cleanMultilineText(input.message, 1200);

  return {
    showcaseId,
    partnerName: cleanText(input.partnerName, 140),
    companyName,
    contactName,
    email,
    phone,
    fleetOrQuantityNeed,
    region,
    message,
  };
}

function assertPartnerInquiryStatusTransition(fromStatus, toStatus) {
  const current = cleanText(fromStatus, 32) || "new";
  const next = cleanText(toStatus, 32);
  if (!PARTNER_INQUIRY_STATUS_SET.has(next)) {
    throw new PartnerProgramPolicyError(
        "invalid-argument",
        `Unsupported inquiry status: ${next}.`,
    );
  }
  const allowed = ALLOWED_STATUS_TRANSITIONS[current];
  if (!allowed || !allowed.has(next)) {
    throw new PartnerProgramPolicyError(
        "failed-precondition",
        `Cannot transition partner inquiry from ${current} to ${next}.`,
    );
  }
  return next;
}

module.exports = {
  PARTNER_BRAND_CATEGORIES,
  PARTNER_COMMERCIAL_MODELS,
  PARTNER_INQUIRY_STATUSES,
  PARTNER_PROGRAM_TYPES,
  PartnerProgramPolicyError,
  assertPartnerInquiryStatusTransition,
  normalizePartnerShowcaseDeal,
   normalizeWebsiteUrl,
  toPublicPartnerShowcaseDeal,
  validatePartnerDealInterestInput,
  validatePartnerInquiryInput,
};
