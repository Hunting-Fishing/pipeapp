"use strict";

const MAX_LISTING_IMAGE_HASHES = 12;
const MAX_RELATED_LISTINGS = 50;
const MAX_REVIEW_MEDIA_ITEMS = 12;
const MAX_MESSAGE_EVIDENCE_CHARACTERS = 500;

function boundedText(value, maximum) {
  return Array.from(String(value || "").normalize("NFKC").trim())
      .slice(0, maximum)
      .join("");
}

function safeEvidenceUrl(value) {
  const url = String(value || "").trim();
  if (url.length > 2048 || !/^https?:\/\//i.test(url)) return "";
  return url;
}

function validImageHashes(values) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values
      .map((value) => String(value || "").trim().toLowerCase())
      .filter((value) => /^[a-f0-9]{64}$/.test(value)))]
      .slice(0, MAX_LISTING_IMAGE_HASHES);
}

function duplicateListingMediaEvidence({listingId, imageHashes, matches}) {
  const currentListingId = String(listingId || "").trim();
  const currentHashes = validImageHashes(imageHashes);
  const currentHashSet = new Set(currentHashes);
  const duplicateListingIds = [];
  const matchedHashes = new Set();

  for (const match of Array.isArray(matches) ? matches : []) {
    const matchId = String(match && match.id || "").trim();
    if (!matchId || matchId === currentListingId) continue;
    const overlap = validImageHashes(match && match.imageHashes)
        .filter((hash) => currentHashSet.has(hash));
    if (!overlap.length) continue;
    if (!duplicateListingIds.includes(matchId) &&
        duplicateListingIds.length < MAX_RELATED_LISTINGS) {
      duplicateListingIds.push(matchId);
    }
    overlap.forEach((hash) => matchedHashes.add(hash));
  }

  return {
    duplicateListingIds,
    matchedImageHashes: [...matchedHashes],
  };
}

function duplicateListingMediaItems({listingId, listing, matches, evidence}) {
  const duplicateIds = new Set(evidence && evidence.duplicateListingIds || []);
  const matchedHashes = new Set(
      validImageHashes(evidence && evidence.matchedImageHashes),
  );
  const candidates = [
    {id: listingId, ...(listing || {})},
    ...(Array.isArray(matches) ? matches : [])
        .filter((match) => duplicateIds.has(String(match && match.id || ""))),
  ];
  const seen = new Set();
  const items = [];

  for (const candidate of candidates) {
    const candidateId = boundedText(candidate && candidate.id, 128);
    if (!candidateId || seen.has(candidateId)) continue;
    const hashes = validImageHashes(candidate && candidate.imageHashes);
    const matchIndex = hashes.findIndex((hash) => matchedHashes.has(hash));
    if (matchIndex < 0) continue;
    const imageUrls = Array.isArray(candidate && candidate.imageUrls) ?
      candidate.imageUrls : [];
    const photoUrl = safeEvidenceUrl(
        imageUrls[matchIndex] || candidate.thumbnailUrl,
    );
    items.push({
      listingId: candidateId,
      listingTitle: boundedText(candidate && candidate.title, 200),
      matchedImageHash: hashes[matchIndex],
      ...(photoUrl ? {photoUrl} : {}),
    });
    seen.add(candidateId);
    if (items.length >= MAX_REVIEW_MEDIA_ITEMS) break;
  }
  return items;
}

function messageContentEvidence(rawText) {
  const characters = Array.from(
      String(rawText || "").normalize("NFKC").trim(),
  );
  return {
    excerpt: characters.slice(0, MAX_MESSAGE_EVIDENCE_CHARACTERS).join(""),
    characterCount: characters.length,
    truncated: characters.length > MAX_MESSAGE_EVIDENCE_CHARACTERS,
  };
}

function classifyMessageSafety(rawText) {
  const text = String(rawText || "").normalize("NFKC").trim();
  if (!text) return {signals: [], priority: "normal"};
  const normalized = text.toLowerCase();
  const signals = [];

  if (/\b(wire|transfer|send)\b.{0,35}\b(crypto|bitcoin|gift card|western union)\b/i.test(text) ||
      /\bpay\b.{0,30}\boff[\s-]?platform\b/i.test(text)) {
    signals.push("possible_payment_fraud");
  }
  if (/\b(kill|hurt|attack|find you)\b.{0,30}\b(you|your|them)\b/i.test(text)) {
    signals.push("possible_threat");
  }
  if (/\b(race|racial|ethnic|ethnicity|religion|nationality)\b.{0,40}\b(inferior|filthy|vermin|hate|exclude|ban)\b/i.test(text) ||
      /\b(inferior|filthy|vermin|hate)\b.{0,40}\b(race|racial|ethnic|religion|nationality)\b/i.test(text)) {
    signals.push("possible_hate_or_racist_content");
  }
  const vulgarTerms = ["fuck", "cunt", "bitch", "piece of shit"];
  if (vulgarTerms.some((term) => normalized.includes(term))) {
    signals.push("vulgar_or_harassing_content");
  }

  return {
    signals,
    priority: signals.includes("possible_threat") ? "high" : "normal",
  };
}

module.exports = {
  MAX_LISTING_IMAGE_HASHES,
  MAX_MESSAGE_EVIDENCE_CHARACTERS,
  MAX_RELATED_LISTINGS,
  MAX_REVIEW_MEDIA_ITEMS,
  classifyMessageSafety,
  duplicateListingMediaEvidence,
  duplicateListingMediaItems,
  messageContentEvidence,
  validImageHashes,
};
