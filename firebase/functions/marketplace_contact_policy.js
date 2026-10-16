"use strict";

function normalizedText(value) {
  return String(value || "")
      .normalize("NFKC")
      .replace(/[\u200B-\u200D\u2060\uFEFF]/gu, "")
      .toLowerCase();
}

function hasEmail(value) {
  const text = normalizedText(value);
  const at = "(?:@|\\(\\s*at\\s*\\)|\\[\\s*at\\s*\\]|\\s+at\\s+)";
  const dot = "(?:\\.|\\(\\s*dot\\s*\\)|\\[\\s*dot\\s*\\]|\\s+dot\\s+)";
  return new RegExp(
      `[a-z0-9._%+-]{1,64}\\s*${at}\\s*` +
      `[a-z0-9-]{1,63}(?:\\s*${dot}\\s*[a-z0-9-]{1,63})+`,
      "u",
  ).test(text);
}

function hasWebsite(value) {
  const text = normalizedText(value);
  if (/(?:https?:\/\/|www\.)/u.test(text)) return true;
  const dot = "(?:\\.|\\(\\s*dot\\s*\\)|\\[\\s*dot\\s*\\]|\\s+dot\\s+)";
  const label = "[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?";
  return new RegExp(
      `\\b${label}\\s*${dot}\\s*[a-z]{2,24}\\b`,
      "u",
  ).test(text);
}

function hasPhone(value) {
  const text = normalizedText(value);
  const candidates = text.match(/\+?\d[\d\s().-]{5,}\d/gu) || [];
  for (const candidate of candidates) {
    const digits = candidate.replace(/\D/gu, "");
    if (digits.length < 7 || digits.length > 15) continue;
    const compact = candidate.trim();
    const isoDate = /^(?:19|20)\d{2}[-.]\d{1,2}[-.]\d{1,2}$/u;
    const localDate = /^\d{1,2}[-.]\d{1,2}[-.](?:19|20)\d{2}$/u;
    if (isoDate.test(compact) || localDate.test(compact)) continue;
    if (/^\d{10,15}$/u.test(compact)) return true;
    const offset = text.indexOf(candidate);
    const before = offset > 0 ? text[offset - 1] : "";
    const after = text[offset + candidate.length] || "";
    const isStandalone =
      !/[a-z0-9-]/u.test(before) && !/[a-z0-9-]/u.test(after);
    if (/^\d{3}[-.]\d{4}$/u.test(compact) && isStandalone) return true;
    const separatorCount = (candidate.match(/[\s().-]/gu) || []).length;
    if (candidate.startsWith("+") || separatorCount >= 2) return true;
    const context = text.slice(Math.max(0, offset - 24), offset + candidate.length + 24);
    if (/\b(?:call|cell|mobile|phone|tel|text|sms|whatsapp|signal)\b/u.test(context)) {
      return true;
    }
  }
  return false;
}

function hasContactHandle(value) {
  const text = normalizedText(value);
  const bareHandle =
    /(?:^|[\s([{:;,'"`])@[a-z0-9_][a-z0-9_.-]{1,31}(?=$|[^a-z0-9_.-])/u;
  if (bareHandle.test(text)) return true;
  const platform =
    "whatsapp|telegram|signal|wechat|line|viber|instagram|facebook|" +
    "messenger|linkedin|snapchat|tiktok|discord|twitter";
  return new RegExp(
      `\\b(?:${platform})\\b\\s*` +
      "(?:(?:handle|username|user|id)\\s*)?" +
      "(?:[:=@-]\\s*|at\\s+)(?:@?[a-z0-9_+.-]{3,})",
      "u",
  ).test(text);
}

function contactSharingSignals(value) {
  const signals = [];
  if (hasEmail(value)) signals.push("email");
  if (hasPhone(value)) signals.push("phone");
  if (hasWebsite(value)) signals.push("website");
  if (hasContactHandle(value)) signals.push("contact_handle");
  return signals;
}

function listingContactSignals(listing) {
  const fields = [
    "title",
    "category",
    "productType",
    "brand",
    "model",
    "operatingStatus",
    "description",
    "inspectionDetails",
    "inspectionStatus",
    "maintenanceHistory",
    "engineDetails",
    "attachments",
    "pipeSize",
    "quantityAndLength",
    "condition",
    "pipeBand",
    "leaseDetails",
    "propertyOffering",
    "propertyInterest",
    "propertyFeatures",
    "zoningOrUse",
    "priceBasis",
    "priceFlexibility",
    "sellerName",
  ];
  const signals = new Set();
  for (const field of fields) {
    const value = listing && listing[field];
    const values = Array.isArray(value) ? value : [value];
    for (const item of values) {
      for (const signal of contactSharingSignals(item)) signals.add(signal);
    }
  }
  return [...signals].sort();
}

module.exports = {
  contactSharingSignals,
  hasContactHandle,
  hasEmail,
  hasPhone,
  hasWebsite,
  listingContactSignals,
  normalizedText,
};
