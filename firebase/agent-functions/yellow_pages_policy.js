"use strict";

const OUTREACH_STATUSES = new Set([
  "not_contacted",
  "assigned",
  "attempted",
  "follow_up",
  "unreachable",
  "do_not_contact",
]);

const VERIFICATION_STATUSES = new Set([
  "unverified",
  "verified",
  "rejected",
  "inactive",
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
  return text(value, 200)
      .toLowerCase()
      .replace(/[^a-z0-9]+/gu, " ")
      .trim()
      .replace(/\s+/gu, " ");
}

function validStatus(set, value, fallback) {
  const normalized = text(value, 40).toLowerCase();
  return set.has(normalized) ? normalized : fallback;
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

function isPublicationEligible(company, nowMillis = Date.now()) {
  if (!company || typeof company !== "object") return false;
  if (company.verificationStatus !== "verified") return false;
  if (company.billingStatus !== "paid") return false;
  if (company.publicationStatus !== "published") return false;
  if (!text(company.companyName, 200)) return false;

  if (company.nonExpiringPaid === true) return true;
  const paidThroughMillis = timestampMillis(company.paidThrough);
  return paidThroughMillis != null && paidThroughMillis > nowMillis;
}

function buildPublicEntry(company, companyId, serverTimestamp) {
  if (!isPublicationEligible(company)) return null;
  return {
    schemaVersion: 1,
    companyId: text(companyId, 200),
    companyName: text(company.companyName, 200),
    website: text(company.website, 500),
    publicPhone: text(company.publicPhone, 80),
    publicEmail: text(company.publicEmail, 254),
    countryCode: text(company.countryCode, 8).toUpperCase(),
    regionCode: text(company.regionCode, 80),
    city: text(company.city, 120),
    categories: stringList(company.categories, 30, 120),
    services: stringList(company.services, 60, 160),
    description: text(company.description, 2500),
    verified: true,
    paidThrough: company.paidThrough || null,
    nonExpiringPaid: company.nonExpiringPaid === true,
    publishedAt: company.publishedAt || null,
    updatedAt: serverTimestamp,
  };
}

function defaultCompanyWorkflow() {
  return {
    outreachStatus: "not_contacted",
    verificationStatus: "unverified",
    billingStatus: "unpaid",
    publicationStatus: "unpublished",
    doNotContact: false,
    nonExpiringPaid: false,
  };
}

module.exports = {
  BILLING_STATUSES,
  OUTREACH_STATUSES,
  PUBLICATION_STATUSES,
  STAFF_ROLES,
  VERIFICATION_STATUSES,
  buildPublicEntry,
  defaultCompanyWorkflow,
  isPublicationEligible,
  normalizedCompanyName,
  stringList,
  text,
  validStatus,
};
