"use strict";

const {
  CATEGORY_BY_CODE,
  classifyCategoriesFromText,
  expandServiceSearchTerms,
  inferCountryAndRegion,
  normalizeText,
} = require("./yellow_pages_taxonomy");

const OUTREACH_STATUSES = new Set([
  "not_contacted",
  "assigned",
  "attempted",
  "follow_up",
  "qualified_interested",
  "unreachable",
  "do_not_contact",
]);

const VERIFICATION_STATUSES = new Set([
  "unverified",
  "verified",
  "rejected",
  "inactive",
]);

const OPERATIONAL_STATUSES = new Set([
  "unverified",
  "active_in_operation",
  "active_number_updated",
  "merged_or_acquired",
  "closed_inactive",
  "flagged_prohibited",
]);

const BILLING_STATUSES = new Set([
  "unpaid",
  "paid",
  "expired",
]);

const PUBLICATION_STATUSES = new Set([
  "unpublished",
  "pending",
  "published",
  "suspended",
]);

const LISTING_TIERS = new Set([
  "featured_platinum",
  "paid_verified",
  "free_verified",
]);

const STAFF_ROLES = new Set(["agent", "manager"]);

function text(value, maxLength = 500) {
  const normalized = String(value == null ? "" : value).trim();
  return normalized.length <= maxLength ? normalized : normalized.slice(0, maxLength);
}

function stringList(value, maxItems = 30, maxLength = 120) {
  if (!Array.isArray(value)) return [];
  const seen = new Set();
  const result = [];
  for (const item of value) {
    const normalized = text(item, maxLength);
    if (!normalized || seen.has(normalized.toLowerCase())) continue;
    seen.add(normalized.toLowerCase());
    result.push(normalized);
    if (result.length >= maxItems) break;
  }
  return result;
}

function normalizedCompanyName(value) {
  return normalizeText(text(value, 200))
      .replace(/\b(ltd|limited|inc|incorporated|corp|corporation|llc|llp|co|company)\b/gu, "")
      .trim()
      .replace(/\s+/gu, " ");
}

function normalizeNorthAmericanPhone(raw) {
  const rawStr = text(raw, 80);
  if (!rawStr) return {raw: "", digits10: "", e164: "", display: "", validNanpa: false, isTollFree: false};
  const digitsOnly = rawStr.replace(/\D+/gu, "");
  let digits10 = "";
  if (digitsOnly.length === 10) {
    digits10 = digitsOnly;
  } else if (digitsOnly.length === 11 && digitsOnly.startsWith("1")) {
    digits10 = digitsOnly.slice(1);
  } else if (digitsOnly.length > 10) {
    // Strip extension after 10/11 digits when written like 780-555-1234 ext 201
    const match = rawStr.match(/(?:\+?1[\s.-]?)?\(?([2-9]\d{2})\)?[\s.-]?([2-9]\d{2})[\s.-]?(\d{4})/u);
    if (match) {
      digits10 = `${match[1]}${match[2]}${match[3]}`;
    }
  }
  if (digits10.length !== 10) {
    return {
      raw: rawStr,
      digits10: digitsOnly.slice(0, 15),
      e164: digitsOnly ? `+${digitsOnly.slice(0, 15)}` : "",
      display: rawStr,
      validNanpa: false,
      isTollFree: false,
    };
  }
  const area = digits10.slice(0, 3);
  const exchange = digits10.slice(3, 6);
  const line = digits10.slice(6, 10);
  const validNanpa = /^[2-9]\d{2}$/u.test(area) &&
    /^[2-9]\d{2}$/u.test(exchange) &&
    !(exchange === "555" && Number(line) >= 100 && Number(line) <= 199);
  const isTollFree = ["800", "888", "877", "866", "855", "844", "833"].includes(area);
  return {
    raw: rawStr,
    digits10,
    e164: `+1${digits10}`,
    display: `(${area}) ${exchange}-${line}`,
    validNanpa,
    isTollFree,
  };
}

function phoneTokens(raw) {
  const parsed = normalizeNorthAmericanPhone(raw);
  const tokens = new Set();
  if (parsed.digits10) {
    tokens.add(parsed.digits10);
    if (parsed.digits10.length === 10) {
      tokens.add(`1${parsed.digits10}`);
      tokens.add(parsed.digits10.slice(0, 3));
      tokens.add(parsed.digits10.slice(3));
      tokens.add(parsed.digits10.slice(6));
      tokens.add(parsed.digits10.slice(0, 6));
    }
  }
  return [...tokens];
}

function normalizePhoneHistory(historyInput, legacyPhonesInput = [], currentPhone = "") {
  const result = [];
  const seen = new Set();

  if (Array.isArray(historyInput)) {
    for (const item of historyInput.slice(0, 20)) {
      const parsed = normalizeNorthAmericanPhone(item && item.phone);
      const key = parsed.e164 || parsed.raw;
      if (!key || seen.has(key)) continue;
      seen.add(key);
      result.push({
        phone: parsed.display || parsed.raw,
        e164: parsed.e164,
        digits10: parsed.digits10,
        status: text(item && item.status, 40) || "historical",
        source: text(item && item.source, 120) || "directory_history",
        observedYear: text(item && item.observedYear, 20) || "",
        note: text(item && item.note, 240) || "",
      });
    }
  }

  for (const oldRaw of stringList(legacyPhonesInput, 15, 80)) {
    const parsed = normalizeNorthAmericanPhone(oldRaw);
    const key = parsed.e164 || parsed.raw;
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push({
      phone: parsed.display || parsed.raw,
      e164: parsed.e164,
      digits10: parsed.digits10,
      status: "legacy_replaced",
      source: "2015_2016_book_or_prior",
      observedYear: "2015-2016",
      note: "Historical number tracked for audit",
    });
  }

  if (currentPhone) {
    const parsed = normalizeNorthAmericanPhone(currentPhone);
    const key = parsed.e164 || parsed.raw;
    if (key && !seen.has(key)) {
      seen.add(key);
      result.unshift({
        phone: parsed.display || parsed.raw,
        e164: parsed.e164,
        digits10: parsed.digits10,
        status: "current_active",
        source: "verified_current",
        observedYear: "2026",
        note: "",
      });
    }
  }

  return result;
}

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function isPaidCurrent(company, nowMillis = Date.now()) {
  if (!company || company.billingStatus !== "paid") return false;
  if (company.nonExpiringPaid === true) return true;
  const paidThroughMillis = timestampMillis(company.paidThrough);
  return paidThroughMillis != null && paidThroughMillis > nowMillis;
}

function resolveEffectiveTier(company, nowMillis = Date.now()) {
  if (!company || typeof company !== "object") return null;
  if (company.isFlaggedProhibited === true) return null;
  if (company.adminViewingEnabled === false) return null;
  if (company.verificationStatus !== "verified") return null;
  if (company.publicationStatus !== "published") return null;
  if (["closed_inactive", "flagged_prohibited"].includes(company.operationalStatus)) {
    return null;
  }
  if (!text(company.companyName, 200)) return null;

  if (isPaidCurrent(company, nowMillis)) {
    return company.listingTier === "featured_platinum" ?
      "featured_platinum" :
      "paid_verified";
  }

  // Verified operational unpaid listings can appear in Basic Verified tier below
  // all paid results unless per-company allowUnpaidPublic is explicitly false.
  if (company.allowUnpaidPublic !== false) {
    return "free_verified";
  }

  return null;
}

function computePriorityScore(company, effectiveTier) {
  const base = effectiveTier === "featured_platinum" ? 300 :
    effectiveTier === "paid_verified" ? 200 :
    effectiveTier === "free_verified" ? 100 : 0;
  if (base === 0) return 0;

  let bonus = 0;
  if (text(company.publicPhone || company.mainPhone, 80)) bonus += 8;
  if (text(company.website, 500)) bonus += 6;
  if (Array.isArray(company.certifications) && company.certifications.length > 0) bonus += 6;
  if (company.emergency24x7 === true) bonus += 5;
  if (Array.isArray(company.basins) && company.basins.length > 0) bonus += 4;
  if (text(company.description, 2500).length >= 80) bonus += 4;
  return base + bonus;
}

function addWordAndPrefixes(tokenSet, rawText, maxTokens = 320) {
  const norm = normalizeText(rawText);
  if (!norm) return;
  const words = norm.split(" ").filter(Boolean);
  for (const word of words) {
    if (tokenSet.size >= maxTokens) return;
    if (word.length >= 2) {
      tokenSet.add(word.slice(0, 32));
      const maxPrefix = Math.min(word.length, 12);
      for (let len = 3; len <= maxPrefix; len += 1) {
        if (tokenSet.size >= maxTokens) return;
        tokenSet.add(word.slice(0, len));
      }
    }
  }
}

function buildPublicSearchTokens(company) {
  const tokens = new Set();
  addWordAndPrefixes(tokens, company.companyName, 320);
  addWordAndPrefixes(tokens, company.city, 320);
  addWordAndPrefixes(tokens, company.regionCode, 320);
  addWordAndPrefixes(tokens, company.countryCode, 320);

  const geo = inferCountryAndRegion(company.countryCode, company.regionCode);
  addWordAndPrefixes(tokens, geo.regionName, 320);

  const categoryCodes = classifyCategoriesFromText(
      [...(company.categoryCodes || []), ...(company.categories || []), ...(company.services || [])],
      company.description || "",
  );
  for (const code of categoryCodes) {
    tokens.add(code);
    const cat = CATEGORY_BY_CODE.get(code);
    if (cat) {
      addWordAndPrefixes(tokens, cat.label, 320);
      for (const kw of cat.keywords.slice(0, 8)) {
        addWordAndPrefixes(tokens, kw, 320);
      }
    }
  }

  for (const item of [...(company.categories || []), ...(company.services || []), ...(company.basins || []), ...(company.serviceAreas || []), ...(company.certifications || [])]) {
    addWordAndPrefixes(tokens, item, 320);
    const expanded = expandServiceSearchTerms(item);
    for (const term of expanded.terms.slice(0, 8)) {
      if (tokens.size < 320) tokens.add(term);
    }
  }

  for (const ph of phoneTokens(company.publicPhone || company.mainPhone)) {
    if (tokens.size < 320) tokens.add(ph);
  }
  for (const ph of phoneTokens(company.tollFreePhone)) {
    if (tokens.size < 320) tokens.add(ph);
  }

  return [...tokens].slice(0, 320);
}

function buildAdminSearchTokens(company) {
  const tokens = new Set(buildPublicSearchTokens(company));
  addWordAndPrefixes(tokens, company.normalizedCompanyName, 450);
  addWordAndPrefixes(tokens, company.website, 450);
  addWordAndPrefixes(tokens, company.generalEmail, 450);
  addWordAndPrefixes(tokens, company.publicEmail, 450);

  for (const ph of phoneTokens(company.mainPhone)) tokens.add(ph);
  for (const ph of phoneTokens(company.publicPhone)) tokens.add(ph);
  for (const ph of phoneTokens(company.tollFreePhone)) tokens.add(ph);

  for (const legacy of (company.legacyPhones || [])) {
    for (const ph of phoneTokens(legacy)) {
      if (tokens.size < 450) tokens.add(ph);
    }
  }
  for (const entry of (company.phoneHistory || [])) {
    for (const ph of phoneTokens(entry && (entry.e164 || entry.phone))) {
      if (tokens.size < 450) tokens.add(ph);
    }
  }
  return [...tokens].slice(0, 450);
}

function isPublicationEligible(company, nowMillis = Date.now()) {
  return resolveEffectiveTier(company, nowMillis) !== null;
}

function buildPublicEntry(company, companyId, serverTimestamp, nowMillis = Date.now()) {
  const effectiveTier = resolveEffectiveTier(company, nowMillis);
  if (!effectiveTier) return null;

  const isPaid = effectiveTier === "featured_platinum" || effectiveTier === "paid_verified";
  const geo = inferCountryAndRegion(company.countryCode, company.regionCode);
  const categoryCodes = classifyCategoriesFromText(
      [...(company.categoryCodes || []), ...(company.categories || []), ...(company.services || [])],
      company.description || "",
  );
  const categoryLabels = stringList(
      company.categories && company.categories.length > 0 ?
        company.categories :
        categoryCodes.map((c) => (CATEGORY_BY_CODE.get(c) ? CATEGORY_BY_CODE.get(c).label : c)),
      isPaid ? 25 : 2,
      120,
  );
  const serviceLabels = stringList(company.services, isPaid ? 50 : 4, 160);
  const mainPhoneParsed = normalizeNorthAmericanPhone(company.publicPhone || company.mainPhone);
  const tollFreeParsed = normalizeNorthAmericanPhone(company.tollFreePhone);
  const priorityScore = computePriorityScore(company, effectiveTier);

  return {
    schemaVersion: 2,
    companyId: text(companyId, 200),
    companyName: text(company.companyName, 200),
    normalizedCompanyName: normalizedCompanyName(company.companyName),
    effectiveTier,
    isPaidTier: isPaid,
    isFeatured: effectiveTier === "featured_platinum",
    priorityScore,
    claimable: !isPaid,
    website: isPaid ? text(company.website, 500) : "",
    publicPhone: mainPhoneParsed.display || text(company.publicPhone || company.mainPhone, 80),
    tollFreePhone: isPaid ? (tollFreeParsed.display || text(company.tollFreePhone, 80)) : "",
    publicEmail: isPaid ? text(company.publicEmail, 254) : "",
    countryCode: geo.countryCode,
    regionCode: geo.regionCode,
    regionName: geo.regionName,
    city: text(company.city, 120),
    serviceAreas: stringList(company.serviceAreas, isPaid ? 20 : 3, 120),
    basins: stringList(
        company.basins && company.basins.length > 0 ? company.basins : geo.defaultBasins,
        isPaid ? 12 : 2,
        80,
    ),
    categoryCodes: categoryCodes.slice(0, isPaid ? 16 : 3),
    categories: categoryLabels,
    services: serviceLabels,
    certifications: isPaid ? stringList(company.certifications, 15, 80) : [],
    emergency24x7: company.emergency24x7 === true,
    description: isPaid ?
      text(company.description, 2500) :
      text(company.shortSummary || company.description, 220),
    operationalStatus: text(company.operationalStatus, 40) || "active_in_operation",
    verified: true,
    paidThrough: isPaid ? (company.paidThrough || null) : null,
    nonExpiringPaid: isPaid && company.nonExpiringPaid === true,
    searchTokens: buildPublicSearchTokens(company),
    publishedAt: company.publishedAt || null,
    updatedAt: serverTimestamp,
  };
}

function isPublicEntryCurrent(entry, nowMillis = Date.now()) {
  if (!entry || typeof entry !== "object") return false;
  if (entry.verified !== true) return false;
  if (entry.isPaidTier === true) {
    if (entry.nonExpiringPaid === true) return true;
    const paidThroughMillis = timestampMillis(entry.paidThrough);
    return paidThroughMillis != null && paidThroughMillis > nowMillis;
  }
  return entry.effectiveTier === "free_verified";
}

function defaultCompanyWorkflow() {
  return {
    outreachStatus: "not_contacted",
    verificationStatus: "unverified",
    operationalStatus: "unverified",
    billingStatus: "unpaid",
    publicationStatus: "unpublished",
    listingTier: "free_verified",
    allowUnpaidPublic: true,
    adminViewingEnabled: true,
    isFlaggedProhibited: false,
    flagReason: "",
    doNotContact: false,
    nonExpiringPaid: false,
  };
}

module.exports = {
  BILLING_STATUSES,
  LISTING_TIERS,
  OPERATIONAL_STATUSES,
  OUTREACH_STATUSES,
  PUBLICATION_STATUSES,
  STAFF_ROLES,
  VERIFICATION_STATUSES,
  buildAdminSearchTokens,
  buildPublicEntry,
  buildPublicSearchTokens,
  computePriorityScore,
  defaultCompanyWorkflow,
  isPaidCurrent,
  isPublicEntryCurrent,
  isPublicationEligible,
  normalizeNorthAmericanPhone,
  normalizePhoneHistory,
  normalizedCompanyName,
  phoneTokens,
  resolveEffectiveTier,
  stringList,
  text,
};
