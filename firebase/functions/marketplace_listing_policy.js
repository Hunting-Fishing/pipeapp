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

function validateMarketplaceListingInput(input, now = new Date()) {
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

  if (listing.category === "Site & Property") {
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

module.exports = {
  ListingPolicyError,
  validateLocation,
  validateMarketplaceListingInput,
  validateReserve,
};
