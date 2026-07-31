"use strict";

const crypto = require("node:crypto");
const {
  normalizeMarketplaceSearchText,
} = require("./marketplace_listing_policy");

const WANTED_MATCH_VERSION = 1;
const MINIMUM_WANTED_MATCH_SCORE = 45;
const MAXIMUM_WANTED_CANDIDATES = 100;
const MAXIMUM_WANTED_MATCHES_PER_LISTING = 20;
const WANTED_MATCH_ACTIONS = new Set([
  "dismiss",
  "mark_contacted",
  "restore",
]);

class WantedMatchingPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "WantedMatchingPolicyError";
    this.code = code;
  }
}

const ignoredTerms = new Set([
  "and", "for", "from", "good", "item", "items", "looking", "need",
  "needed", "other", "sale", "seeking", "the", "used", "want", "wanted",
]);

function normalized(value) {
  return normalizeMarketplaceSearchText(value, 20);
}

function meaningfulTerms(listing) {
  const text = [
    listing && listing.title,
    listing && listing.productType,
    listing && listing.brand,
    listing && listing.model,
    listing && listing.pipeSize,
  ].filter(Boolean).join(" ");
  return new Set(normalized(text).split(" ")
      .filter((term) => term.length > 1 && !ignoredTerms.has(term))
      .slice(0, 40));
}

function exactField(wanted, supply, field) {
  const expected = normalized(wanted && wanted[field]);
  const offered = normalized(supply && supply[field]);
  return expected && offered && expected === offered;
}

function validWantedPair(wanted, supply) {
  return wanted && supply &&
    wanted.transactionType === "Wanted / Seeking" &&
    wanted.status === "active" &&
    String(wanted.wantedStatus || "open") === "open" &&
    supply.transactionType === "For Sale" &&
    supply.status === "active" &&
    String(wanted.sellerUid || "") &&
    String(supply.sellerUid || "") &&
    wanted.sellerUid !== supply.sellerUid &&
    normalized(wanted.category) === normalized(supply.category);
}

function scoreWantedMatch(wanted, supply) {
  if (!validWantedPair(wanted, supply)) return null;
  let score = 20;
  const reasons = ["Same marketplace category"];

  if (exactField(wanted, supply, "productType")) {
    score += 35;
    reasons.push("Exact product type");
  }
  if (exactField(wanted, supply, "brand")) {
    score += 10;
    reasons.push("Requested brand");
  }
  if (exactField(wanted, supply, "model")) {
    score += 15;
    reasons.push("Requested model");
  }
  if (exactField(wanted, supply, "pipeSize")) {
    score += 15;
    reasons.push("Requested pipe size");
  }

  const wantedTerms = meaningfulTerms(wanted);
  const supplyTerms = meaningfulTerms(supply);
  const matchedTerms = [...wantedTerms]
      .filter((term) => supplyTerms.has(term))
      .slice(0, 8);
  if (matchedTerms.length > 0) {
    score += Math.min(20, matchedTerms.length * 4);
    reasons.push(`${matchedTerms.length} matching specification terms`);
  }

  const wantedQuantity = Number(wanted.quantity);
  const supplyQuantity = Number(supply.quantity);
  if (Number.isFinite(wantedQuantity) && wantedQuantity > 0 &&
      Number.isFinite(supplyQuantity) && supplyQuantity > 0) {
    if (supplyQuantity >= wantedQuantity) {
      score += 8;
      reasons.push("Available quantity meets request");
    } else {
      score += 3;
      reasons.push("Partial requested quantity available");
    }
  }

  const wantedPrice = Number(wanted.price);
  const supplyPrice = Number(supply.price);
  if (Number.isFinite(wantedPrice) && wantedPrice > 0 &&
      Number.isFinite(supplyPrice) && supplyPrice > 0 &&
      normalized(wanted.priceBasis) === normalized(supply.priceBasis) &&
      supplyPrice <= wantedPrice) {
    score += 7;
    reasons.push("Price is within stated target");
  }

  if (exactField(wanted, supply, "region")) {
    score += 5;
    reasons.push("Same region");
  } else if (exactField(wanted, supply, "country")) {
    score += 2;
    reasons.push("Same country");
  }

  const boundedScore = Math.min(100, score);
  if (boundedScore < MINIMUM_WANTED_MATCH_SCORE) return null;
  return {
    score: boundedScore,
    confidence: boundedScore >= 75 ? "high" : "possible",
    reasons: reasons.slice(0, 8),
    matchedTerms,
    version: WANTED_MATCH_VERSION,
  };
}

function wantedMatchId(wantedListingId, supplyListingId) {
  return crypto.createHash("sha256")
      .update(`${wantedListingId}|${supplyListingId}|${WANTED_MATCH_VERSION}`)
      .digest("hex");
}

function validateWantedMatchAction({match, actorUid, action}) {
  if (!match || typeof match !== "object") {
    throw new WantedMatchingPolicyError(
        "not-found", "This Wanted match is unavailable.");
  }
  const actor = String(actorUid || "");
  const role = actor === String(match.wantedOwnerUid || "") ?
    "wantedOwner" : actor === String(match.sellerUid || "") ?
      "seller" : "";
  if (!role) {
    throw new WantedMatchingPolicyError(
        "permission-denied",
        "Only match participants can update this match.",
    );
  }
  if (!WANTED_MATCH_ACTIONS.has(action)) {
    throw new WantedMatchingPolicyError(
        "invalid-argument", "This Wanted match action is not supported.");
  }
  const field = `${role}State`;
  const previousState = String(match[field] || "suggested");
  const nextState = action === "dismiss" ? "dismissed" :
    action === "mark_contacted" ? "contacted" : "suggested";
  if (action === "restore" && previousState !== "dismissed") {
    throw new WantedMatchingPolicyError(
        "failed-precondition", "Only a dismissed match can be restored.");
  }
  if (action !== "restore" && previousState === nextState) {
    throw new WantedMatchingPolicyError(
        "failed-precondition", "This Wanted match is already in that state.");
  }
  const wantedOwnerState = role === "wantedOwner" ? nextState :
    String(match.wantedOwnerState || "suggested");
  const sellerState = role === "seller" ? nextState :
    String(match.sellerState || "suggested");
  const status = wantedOwnerState === "dismissed" &&
    sellerState === "dismissed" ? "dismissed" :
    wantedOwnerState === "contacted" || sellerState === "contacted" ?
      "contacted" : "suggested";
  return {
    action,
    role,
    field,
    previousState,
    nextState,
    wantedOwnerState,
    sellerState,
    status,
    revision: Number(match.revision || 1) + 1,
  };
}

function publicListingSnapshot(listing) {
  return {
    title: String(listing && listing.title || "").slice(0, 180),
    category: String(listing && listing.category || "").slice(0, 180),
    productType: String(listing && listing.productType || "").slice(0, 180),
    brand: String(listing && listing.brand || "").slice(0, 180),
    model: String(listing && listing.model || "").slice(0, 180),
    pipeSize: String(listing && listing.pipeSize || "").slice(0, 120),
    price: Number.isFinite(Number(listing && listing.price)) ?
      Number(listing.price) : null,
    priceBasis: String(listing && listing.priceBasis || "").slice(0, 120),
    quantity: Number.isFinite(Number(listing && listing.quantity)) ?
      Number(listing.quantity) : null,
    currency: String(listing && listing.currency || "CAD").slice(0, 8),
    publicLocationName: String(
        listing && listing.publicLocationName || "Location by request",
    ).slice(0, 240),
    thumbnailUrl: String(listing && listing.thumbnailUrl || "").slice(0, 2000),
  };
}

module.exports = {
  MAXIMUM_WANTED_CANDIDATES,
  MAXIMUM_WANTED_MATCHES_PER_LISTING,
  MINIMUM_WANTED_MATCH_SCORE,
  WantedMatchingPolicyError,
  WANTED_MATCH_VERSION,
  meaningfulTerms,
  publicListingSnapshot,
  scoreWantedMatch,
  validateWantedMatchAction,
  validWantedPair,
  wantedMatchId,
};
