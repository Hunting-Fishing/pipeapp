"use strict";

class ListingPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "ListingPolicyError";
    this.code = code;
  }
}

const publicListingFields = new Set([
  "title",
  "category",
  "productType",
  "brand",
  "model",
  "modelYear",
  "machineHours",
  "operatingStatus",
  "maintenanceHistory",
  "serialNumber",
  "engineDetails",
  "attachments",
  "pipeSize",
  "quantity",
  "quantityAndLength",
  "condition",
  "inspectionStatus",
  "inspectionDetails",
  "pipeBand",
  "propertyOffering",
  "propertyInterest",
  "landAreaInputValue",
  "landAreaInputUnit",
  "landAreaAcres",
  "landAreaHectares",
  "buildingAreaValue",
  "buildingAreaUnit",
  "zoningOrUse",
  "monthlyRevenue",
  "annualRevenue",
  "netOperatingIncome",
  "annualPropertyTax",
  "leaseDetails",
  "propertyFeatures",
  "transactionType",
  "wantedStatus",
  "responseCount",
  "requestType",
  "price",
  "startingBid",
  "currentBid",
  "minimumBidIncrement",
  "buyItNowPrice",
  "auctionStartAt",
  "auctionEndAt",
  "bidCount",
  "auctionStatus",
  "priceBasis",
  "priceFlexibility",
  "openToOffers",
  "currency",
  "description",
  "sellerName",
  "sellerPhotoUrl",
  "sellerVerified",
  "imageUrls",
  "imageHashes",
  "thumbnailUrl",
  "videoUrl",
  "mediaPhotoCount",
  "hasVideo",
  "mediaUploadStatus",
  "boostRequested",
  "boostPrice",
  "boostCurrency",
  "boostStatus",
  "viewCount",
  "saveCount",
  "shareCount",
  "messageCount",
  "offerCount",
  "pendingOfferCount",
  "saleStatus",
]);

const serverOwnedFields = new Set([
  "sellerUid",
  "createdAt",
  "updatedAt",
  "source",
  "status",
  "initialPrice",
  "reservePrice",
  "reserveTotal",
  "wantedStatus",
  "responseCount",
  "requestType",
  "matchCount",
  "lastMatchedAt",
]);

const longTextFields = new Set([
  "description",
  "inspectionDetails",
  "maintenanceHistory",
  "engineDetails",
  "attachments",
  "leaseDetails",
]);

const dateFields = new Set(["auctionStartAt", "auctionEndAt"]);

const searchIndexVersion = 2;
const maximumSearchTokens = 480;

function normalizeMarketplaceSearchText(value, maximumWords = 3) {
  return String(value || "")
      .normalize("NFKD")
      .replace(/\p{M}+/gu, "")
      .toLowerCase()
      .replace(/æ/gu, "ae")
      .replace(/œ/gu, "oe")
      .replace(/ß/gu, "ss")
      .replace(/ø/gu, "o")
      .replace(/ł/gu, "l")
      .replace(/ð/gu, "d")
      .replace(/þ/gu, "th")
      .replace(/[^a-z0-9]+/gu, " ")
      .trim()
      .split(/\s+/u)
      .filter(Boolean)
      .slice(0, maximumWords)
      .join(" ")
      .slice(0, 64);
}

function buildMarketplaceSearchTokens(listing) {
  const tokens = new Set();
  const addPhrase = (value) => {
    if (tokens.size >= maximumSearchTokens) return;
    const words = normalizeMarketplaceSearchText(value, 80)
        .split(" ")
        .filter(Boolean);
    for (let start = 0; start < words.length; start++) {
      for (let length = 1; length <= 3 && start + length <= words.length;
        length++) {
        const phrase = words.slice(start, start + length).join(" ").slice(0, 64);
        const minimum = phrase.length === 1 ? 1 : 2;
        for (let size = minimum; size <= phrase.length; size++) {
          tokens.add(phrase.slice(0, size));
          if (tokens.size >= maximumSearchTokens) return;
        }
      }
    }
  };
  for (const field of [
    "title",
    "category",
    "productType",
    "brand",
    "model",
    "condition",
    "publicLocationName",
    "nearestTown",
    "region",
    "country",
    "description",
  ]) {
    addPhrase(listing && listing[field]);
  }
  return [...tokens].sort();
}

function invalid(message) {
  throw new ListingPolicyError("invalid-argument", message);
}

function isPlainObject(value) {
  return value !== null &&
    typeof value === "object" &&
    !Array.isArray(value);
}

function cleanScalar(field, value) {
  if (value === null) return null;
  if (typeof value === "boolean") return value;
  if (typeof value === "number") {
    if (!Number.isFinite(value) || Math.abs(value) > 1e12) {
      invalid(`${field} contains an invalid number.`);
    }
    return value;
  }
  if (typeof value === "string") {
    const maximum = longTextFields.has(field) ? 12000 : 1200;
    const clean = value.trim();
    if (clean.length > maximum) invalid(`${field} is too long.`);
    return clean;
  }
  if (Array.isArray(value)) {
    if (value.length > 30) invalid(`${field} contains too many items.`);
    return value.map((item) => {
      if (typeof item !== "string") invalid(`${field} contains invalid data.`);
      const clean = item.trim();
      if (clean.length > 2000) invalid(`${field} contains an oversized item.`);
      return clean;
    });
  }
  invalid(`${field} contains unsupported data.`);
}

function requiredText(data, field, maximum = 240) {
  const value = String(data[field] || "").trim();
  if (!value || value.length > maximum) {
    invalid(`${field} is missing or invalid.`);
  }
  return value;
}

function validPoint(value, field) {
  if (!isPlainObject(value)) invalid(`${field} is missing.`);
  const latitude = Number(value.latitude);
  const longitude = Number(value.longitude);
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    invalid(`${field} is invalid.`);
  }
  return {latitude, longitude};
}

function validateLocation(value) {
  if (!isPlainObject(value)) invalid("A pickup or search location is required.");
  const visibility = String(value.visibility || "");
  if (!["exact", "approximate", "on_request", "hidden"].includes(visibility)) {
    invalid("Location privacy is invalid.");
  }
  const point = validPoint(value.point, "Location map pin");
  const clean = {
    visibility,
    point,
    publicName: requiredText(value, "publicName"),
  };
  for (const field of [
    "address",
    "nearestTown",
    "accessNotes",
    "region",
    "postalCode",
    "country",
  ]) {
    clean[field] = String(value[field] || "").trim().slice(0, 1200);
  }
  return clean;
}

function regulatedListingsEnabled() {
  return String(process.env.PIPE_REGULATED_LISTINGS_ENABLED || "")
      .toLowerCase() === "true";
}

function validateMarketplaceListingInput(
    input,
    now = new Date(),
    options = {},
) {
  if (!isPlainObject(input)) invalid("Listing details are missing.");
  const listing = {};
  for (const [field, value] of Object.entries(input)) {
    if (serverOwnedFields.has(field)) continue;
    if (!publicListingFields.has(field)) {
      invalid(`Unsupported listing field: ${field}.`);
    }
    if (dateFields.has(field)) {
      if (!Number.isFinite(Number(value))) invalid(`${field} is invalid.`);
      listing[field] = Number(value);
    } else {
      listing[field] = cleanScalar(field, value);
    }
  }

  listing.title = requiredText(listing, "title");
  listing.category = requiredText(listing, "category");
  const transactionType = String(listing.transactionType || "For Sale");
  if (!["For Sale", "Auction", "Wanted / Seeking"].includes(transactionType)) {
    invalid("Listing destination is invalid.");
  }
  listing.transactionType = transactionType;
  if (transactionType === "Wanted / Seeking") {
    listing.wantedStatus = "open";
    listing.responseCount = 0;
    listing.requestType = "wanted_ad";
    listing.matchCount = 0;
  } else {
    delete listing.wantedStatus;
    delete listing.responseCount;
    delete listing.requestType;
    delete listing.matchCount;
  }

  if (listing.category === "Site & Property") {
    const enabled = options.regulatedListingsEnabled === true ||
      (options.regulatedListingsEnabled === undefined &&
       regulatedListingsEnabled());
    if (!enabled) {
      throw new ListingPolicyError(
          "failed-precondition",
          "Regulated property and rights listings are not available.",
      );
    }
    requiredText(listing, "productType");
    listing.propertyOffering = requiredText(listing, "propertyOffering");
    listing.propertyInterest = requiredText(listing, "propertyInterest");
    for (const field of [
      "landAreaInputValue",
      "landAreaAcres",
      "landAreaHectares",
      "buildingAreaValue",
      "monthlyRevenue",
      "annualRevenue",
      "netOperatingIncome",
      "annualPropertyTax",
    ]) {
      if (listing[field] !== null && listing[field] !== undefined &&
          (typeof listing[field] !== "number" || listing[field] < 0)) {
        invalid(`${field} must be zero or greater.`);
      }
    }
  }

  if (transactionType === "Auction") {
    const start = Number(listing.auctionStartAt);
    const end = Number(listing.auctionEndAt);
    const startingBid = Number(listing.startingBid);
    const increment = Number(listing.minimumBidIncrement);
    if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
      invalid("Choose a valid auction start and end time.");
    }
    if (end <= now.getTime()) invalid("Auction end time must be in the future.");
    if (!Number.isFinite(startingBid) || startingBid <= 0) {
      invalid("Starting bid must be greater than zero.");
    }
    if (!Number.isFinite(increment) || increment <= 0) {
      invalid("Minimum bid increase must be greater than zero.");
    }
    listing.currentBid = 0;
    listing.bidCount = 0;
    listing.auctionStatus = start > now.getTime() ? "scheduled" : "live";
  } else {
    delete listing.auctionStartAt;
    delete listing.auctionEndAt;
    delete listing.startingBid;
    delete listing.currentBid;
    delete listing.minimumBidIncrement;
    delete listing.buyItNowPrice;
    delete listing.bidCount;
    delete listing.auctionStatus;
  }
  return listing;
}

function validateReserve(data, transactionType) {
  const reservePrice = Number(data && data.reservePrice);
  const reserveTotal = Number(data && data.reserveTotal);
  if (transactionType !== "Auction" || !Number.isFinite(reservePrice) ||
      reservePrice <= 0) {
    return null;
  }
  return {
    reservePrice,
    ...(Number.isFinite(reserveTotal) && reserveTotal > 0 ?
      {reserveTotal} : {}),
  };
}

function listingMediaObjectPath(rawUrl) {
  let url;
  try {
    url = new URL(String(rawUrl || "").trim());
  } catch (_) {
    invalid("A listing media URL is invalid.");
  }
  if (url.protocol !== "https:") {
    invalid("Listing media must use a secure Firebase Storage URL.");
  }
  if (url.hostname === "firebasestorage.googleapis.com") {
    const marker = "/o/";
    const offset = url.pathname.indexOf(marker);
    if (offset < 0) invalid("A listing media URL is invalid.");
    try {
      return decodeURIComponent(url.pathname.slice(offset + marker.length));
    } catch (_) {
      invalid("A listing media URL is invalid.");
    }
  }
  if (url.hostname === "storage.googleapis.com") {
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts.length < 2) invalid("A listing media URL is invalid.");
    return parts.slice(1).join("/");
  }
  invalid("Listing media must be stored in the application storage bucket.");
}

function validateListingMediaManifest(data, options) {
  if (!isPlainObject(data)) invalid("Listing media details are missing.");
  const ownerUid = String(options && options.ownerUid || "").trim();
  const listingId = String(options && options.listingId || "").trim();
  const expectedPhotoCount = Number(
      options && options.expectedPhotoCount || 0,
  );
  const expectsVideo = options && options.expectsVideo === true;
  const requireComplete = options && options.requireComplete === true;
  if (!ownerUid || !listingId || !Number.isInteger(expectedPhotoCount) ||
      expectedPhotoCount < 0 || expectedPhotoCount > 12) {
    invalid("Listing media expectations are invalid.");
  }

  const status = String(data.status || "").trim();
  if (!["uploading", "complete", "failed"].includes(status)) {
    invalid("Listing media status is invalid.");
  }
  if (requireComplete && status !== "complete") {
    throw new ListingPolicyError(
        "failed-precondition",
        "Finish uploading the selected listing media before publishing.",
    );
  }
  const imageUrls = Array.isArray(data.imageUrls) ?
    data.imageUrls.map((value) => String(value || "").trim()) : [];
  const imageHashes = Array.isArray(data.imageHashes) ?
    data.imageHashes.map((value) => String(value || "").trim()) : [];
  const thumbnailUrl = String(data.thumbnailUrl || "").trim();
  const videoUrl = String(data.videoUrl || "").trim();
  if (imageUrls.length > 12 || imageHashes.length > 12 ||
      new Set(imageUrls).size !== imageUrls.length ||
      imageHashes.some((value) => !/^[a-f0-9]{64}$/.test(value))) {
    invalid("Listing photo metadata is invalid.");
  }
  if (status === "complete" &&
      (imageUrls.length !== expectedPhotoCount ||
       imageHashes.length !== expectedPhotoCount ||
       Boolean(videoUrl) !== expectsVideo)) {
    invalid("Uploaded listing media does not match the selected files.");
  }
  if (thumbnailUrl && !imageUrls.includes(thumbnailUrl)) {
    invalid("Choose one of the uploaded photos as the listing thumbnail.");
  }
  if (status === "complete" && imageUrls.length > 0 && !thumbnailUrl) {
    invalid("Choose a listing thumbnail before publishing.");
  }
  const expectedPrefix = `listing_media/${ownerUid}/${listingId}/`;
  for (const imageUrl of imageUrls) {
    const path = listingMediaObjectPath(imageUrl);
    if (!path.startsWith(expectedPrefix) || !path.includes("/photo_")) {
      invalid("A listing photo does not belong to this draft.");
    }
  }
  if (videoUrl) {
    const path = listingMediaObjectPath(videoUrl);
    if (!path.startsWith(expectedPrefix) || !path.includes("/video.")) {
      invalid("The listing video does not belong to this draft.");
    }
  }
  return {status, imageUrls, imageHashes, thumbnailUrl, videoUrl};
}

module.exports = {
  ListingPolicyError,
  buildMarketplaceSearchTokens,
  listingMediaObjectPath,
  normalizeMarketplaceSearchText,
  searchIndexVersion,
  validateLocation,
  validateListingMediaManifest,
  validateMarketplaceListingInput,
  validateReserve,
};
