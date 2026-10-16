"use strict";

const {
  contactSharingSignals,
  listingContactSignals,
} = require("./marketplace_contact_policy");

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
  "marketplaceFeeClass",
  "marketplaceFeeUnit",
  "marketplaceFeeClassSource",
  "marketplaceFeeClassificationRevision",
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

const MARKETPLACE_MAX_QUANTITY = 1_000_000;
const marketplacePriceBases = new Map([
  ["total", {canonical: "Total asking price", kind: "total"}],
  ["total asking price", {canonical: "Total asking price", kind: "total"}],
  ["total for all", {canonical: "Total for all", kind: "total"}],
  ["per piece", {canonical: "Per piece", kind: "count"}],
  ["per joint", {canonical: "Per joint", kind: "count"}],
  ["per item", {canonical: "Per item", kind: "count"}],
  ["price per machine", {canonical: "Price per machine", kind: "count"}],
]);

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

function marketplacePriceBasis(value) {
  return marketplacePriceBases.get(
      String(value || "").trim().toLowerCase(),
  ) || null;
}

function marketplaceQuantity(value, {allowMissingTotal = false, priceBasis} = {}) {
  if (value == null || value === "") {
    const basis = marketplacePriceBasis(priceBasis);
    return allowMissingTotal && basis && basis.kind === "total" ? 1 : null;
  }
  if (typeof value !== "number" ||
      !Number.isSafeInteger(value) ||
      value < 1 ||
      value > MARKETPLACE_MAX_QUANTITY) {
    return null;
  }
  return value;
}

function normalizeMarketplaceSaleTerms(listing) {
  const basis = marketplacePriceBasis(listing.priceBasis);
  if (!basis) {
    invalid(
        "Choose a total price or a supported count-based price. Per-length, " +
        "per-area, lease, bundle, and call-for-price sales are unavailable " +
        "until their settlement units can be verified.",
    );
  }
  const quantity = marketplaceQuantity(listing.quantity, {
    allowMissingTotal: true,
    priceBasis: basis.canonical,
  });
  if (quantity == null) {
    invalid("Quantity must be a whole number between 1 and 1,000,000.");
  }
  listing.priceBasis = basis.canonical;
  listing.quantity = quantity;
}

function auctionMoney(value, fieldName, {optional = false} = {}) {
  if (optional && (value == null || value === "")) return null;
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount <= 0 || amount > 1_000_000_000_000 ||
      Math.abs(amount * 100 - Math.round(amount * 100)) > 0.000001) {
    invalid(`${fieldName} must be a positive amount with no more than two decimals.`);
  }
  return amount;
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
  const locationContactFields = [
    "publicName",
    "address",
    "nearestTown",
    "accessNotes",
    "region",
    "postalCode",
    "country",
  ];
  if (locationContactFields.some((field) =>
    contactSharingSignals(clean[field]).length > 0)) {
    invalid(
        "Remove phone numbers, email addresses, websites, and contact handles " +
        "from location notes.",
    );
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
  const requestedCurrency = String(listing.currency || "").trim().toUpperCase();
  if (requestedCurrency && requestedCurrency !== "USD") {
    invalid("Marketplace and Timed Buying listings must use USD.");
  }
  listing.currency = "USD";
  if (transactionType === "For Sale" || transactionType === "Auction") {
    normalizeMarketplaceSaleTerms(listing);
  }
  if (transactionType === "For Sale") {
    const requestedFlexibility = String(
        listing.priceFlexibility || "",
    ).trim();
    if (requestedFlexibility &&
        !["Open to offers", "Firm"].includes(requestedFlexibility)) {
      invalid("Price flexibility must be Open to offers or Firm.");
    }
    if (listing.openToOffers != null &&
        typeof listing.openToOffers !== "boolean") {
      invalid("Offer availability must be true or false.");
    }
    const priceFlexibility = requestedFlexibility ||
      (listing.openToOffers === false ? "Firm" : "Open to offers");
    const openToOffers = priceFlexibility === "Open to offers";
    if (typeof listing.openToOffers === "boolean" &&
        listing.openToOffers !== openToOffers) {
      invalid("Offer availability must match the selected price flexibility.");
    }
    if (!openToOffers) {
      listing.price = auctionMoney(listing.price, "Firm asking price");
    }
    listing.priceFlexibility = priceFlexibility;
    listing.openToOffers = openToOffers;
  }
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
    const startingBid = auctionMoney(listing.startingBid, "Starting bid");
    const increment = auctionMoney(
        listing.minimumBidIncrement,
        "Minimum bid increase",
    );
    const buyItNowPrice = auctionMoney(
        listing.buyItNowPrice,
        "Buy It Now price",
        {optional: true},
    );
    if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
      invalid("Choose a valid auction start and end time.");
    }
    if (end <= now.getTime()) invalid("Auction end time must be in the future.");
    if (end - start > 360 * 24 * 60 * 60 * 1000) {
      invalid("Auction duration cannot exceed 360 days.");
    }
    if (increment < 0.5 || increment > 1000) {
      invalid("Minimum bid increase must be between 0.50 and 1,000.00.");
    }
    if (buyItNowPrice != null && buyItNowPrice < startingBid) {
      invalid("Buy It Now must be at least the starting bid and reserve price.");
    }
    listing.startingBid = startingBid;
    listing.minimumBidIncrement = increment;
    if (buyItNowPrice == null) delete listing.buyItNowPrice;
    else listing.buyItNowPrice = buyItNowPrice;
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
  if (listingContactSignals(listing).length > 0) {
    invalid(
        "Remove phone numbers, email addresses, websites, and contact handles. " +
        "Keep buyer and seller communication in secure marketplace messages.",
    );
  }
  return listing;
}

function validateReserve(data, transactionType, listing = null) {
  if (transactionType !== "Auction") {
    return null;
  }
  const reservePrice = auctionMoney(
      data && data.reservePrice,
      "Reserve price",
      {optional: true},
  );
  if (reservePrice == null) {
    if (data &&
        Object.prototype.hasOwnProperty.call(data, "reserveTotal") &&
        data.reserveTotal != null && data.reserveTotal !== "") {
      invalid("Reserve total requires a valid reserve price.");
    }
    return null;
  }
  const startingBid = auctionMoney(
      listing && listing.startingBid != null ?
        listing.startingBid : data && data.startingBid,
      "Starting bid",
  );
  const buyItNowPrice = auctionMoney(
      listing && listing.buyItNowPrice != null ?
        listing.buyItNowPrice : data && data.buyItNowPrice,
      "Buy It Now price",
      {optional: true},
  );
  if (reservePrice < startingBid) {
    invalid("Reserve price must be at least the starting bid.");
  }
  if (buyItNowPrice != null && buyItNowPrice < reservePrice) {
    invalid("Buy It Now must be at least the starting bid and reserve price.");
  }
  const reserveTotal = auctionMoney(
      data && data.reserveTotal,
      "Reserve total",
      {optional: true},
  );
  if (reserveTotal != null && listing) {
    const basis = marketplacePriceBasis(listing.priceBasis);
    const quantity = marketplaceQuantity(listing.quantity, {
      allowMissingTotal: true,
      priceBasis: listing.priceBasis,
    });
    const expectedReserveTotal = basis && basis.kind === "total" ?
      reservePrice : reservePrice * quantity;
    if (!basis || quantity == null ||
        Math.round(reserveTotal * 100) !==
          Math.round(expectedReserveTotal * 100)) {
      invalid("Reserve total must match the reserve price and listing quantity.");
    }
  }
  return {
    reservePrice,
    ...(reserveTotal == null ? {} : {reserveTotal}),
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
  MARKETPLACE_MAX_QUANTITY,
  ListingPolicyError,
  buildMarketplaceSearchTokens,
  listingMediaObjectPath,
  marketplacePriceBasis,
  marketplaceQuantity,
  normalizeMarketplaceSearchText,
  searchIndexVersion,
  validateLocation,
  validateListingMediaManifest,
  validateMarketplaceListingInput,
  validateReserve,
};
