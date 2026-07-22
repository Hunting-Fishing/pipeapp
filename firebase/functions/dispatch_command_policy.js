"use strict";

const {
  CommandPolicyError,
  requireMoney,
} = require("./marketplace_command_policy");

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function validateQuoteDate(value, now) {
  const milliseconds = Number(value);
  const nowMillis = timestampMillis(now);
  if (
    !Number.isInteger(milliseconds) ||
    milliseconds < nowMillis - 24 * 60 * 60 * 1000 ||
    milliseconds > nowMillis + 730 * 24 * 60 * 60 * 1000
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Carrier availability must be within the next two years.",
    );
  }
  return milliseconds;
}

function requireText(value, fieldName, maximumLength) {
  const text = String(value || "").trim();
  if (!text || text.length > maximumLength) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} is required and must be ${maximumLength} characters or fewer.`,
    );
  }
  return text;
}

function optionalText(value, fieldName, maximumLength) {
  if (value == null) return null;
  const text = String(value).trim();
  if (text.length > maximumLength) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} must be ${maximumLength} characters or fewer.`,
    );
  }
  return text || null;
}

function optionalPositiveNumber(value, fieldName, maximum) {
  if (value == null || value === "") return null;
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0 || number > maximum) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} must be greater than zero.`,
    );
  }
  return number;
}

function optionalPoint(value, fieldName) {
  if (value == null) return null;
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
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} must be a valid mapped location.`,
    );
  }
  return {latitude, longitude};
}

function validateDispatchJobInput(data, now) {
  const sourceType = String(data.sourceType || "manual").trim();
  if (!["manual", "marketplace", "auction"].includes(sourceType)) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Dispatch request source is invalid.",
    );
  }
  const listingId = optionalText(data.listingId, "Listing reference", 180);
  if (sourceType !== "manual" && !listingId) {
    throw new CommandPolicyError(
        "invalid-argument",
        "A listing reference is required for this Dispatch request.",
    );
  }
  const truckingDate = validateQuoteDate(data.truckingDate, now);
  const pickupPoint = optionalPoint(data.pickupPoint, "Pickup location");
  const deliveryPoint = optionalPoint(
      data.deliveryPoint,
      "Delivery destination",
  );
  return {
    title: requireText(data.title, "Load title", 160),
    pickupLabel: requireText(data.pickupLabel, "Pickup location", 500),
    deliveryLabel: requireText(data.deliveryLabel, "Delivery location", 500),
    truckingDate,
    loadDetails: requireText(data.loadDetails, "Load details", 4000),
    listingId,
    sourceType,
    estimatedWeightKg: optionalPositiveNumber(
        data.estimatedWeightKg,
        "Estimated shipping weight",
        100_000_000,
    ),
    catalogWeightKg: optionalPositiveNumber(
        data.catalogWeightKg,
        "Catalog shipping weight",
        100_000_000,
    ),
    weightSource: optionalText(data.weightSource, "Weight source", 80),
    pickupPoint,
    deliveryPoint,
    distanceKm: optionalPositiveNumber(
        data.distanceKm,
        "Route distance",
        100_000,
    ),
    distanceSource: optionalText(
        data.distanceSource,
        "Distance source",
        80,
    ),
    deliveryAddress: optionalText(
        data.deliveryAddress,
        "Delivery address",
        500,
    ),
    deliveryNearestTown: optionalText(
        data.deliveryNearestTown,
        "Nearest town",
        200,
    ),
    deliveryRegion: optionalText(
        data.deliveryRegion,
        "Delivery region",
        200,
    ),
    deliveryPostalCode: optionalText(
        data.deliveryPostalCode,
        "Postal code",
        40,
    ),
    deliveryCountry: optionalText(
        data.deliveryCountry,
        "Delivery country",
        120,
    ),
    deliveryAccessNotes: optionalText(
        data.deliveryAccessNotes,
        "Delivery access notes",
        2000,
    ),
  };
}

function validateDispatchJobChange(job, actorUid, now) {
  if (!job || job.createdByUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the Dispatch request owner can change this job.",
    );
  }
  if (!["draft", "open"].includes(job.status)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Awarded or completed Dispatch jobs cannot be changed.",
    );
  }
  if (Number(job.revision || 1) >= 50) {
    throw new CommandPolicyError(
        "resource-exhausted",
        "The Dispatch job revision limit has been reached.",
    );
  }
  const updatedAt = timestampMillis(job.updatedAt || job.createdAt);
  if (updatedAt != null && timestampMillis(now) - updatedAt < 3000) {
    throw new CommandPolicyError(
        "resource-exhausted",
        "Wait a few seconds before changing this Dispatch request again.",
    );
  }
}

function validateDispatchJobPublish(job, actorUid) {
  if (!job || job.createdByUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the Dispatch request owner can publish this job.",
    );
  }
  if (job.status !== "draft") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch request is no longer a draft.",
    );
  }
}

function validateDispatchQuote({
  job,
  carrier,
  vehicle,
  existingBid,
  actorUid,
  data,
  now,
}) {
  if (!job || job.status !== "open") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch job is no longer open.",
    );
  }
  if (job.createdByUid === actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "You cannot quote your own Dispatch request.",
    );
  }
  if (
    !carrier ||
    carrier.ownerUid !== actorUid ||
    carrier.status !== "active" ||
    carrier.availableForHire === false
  ) {
    throw new CommandPolicyError(
        "permission-denied",
        "Complete active Dispatch enrollment before quoting.",
    );
  }
  if (
    !vehicle ||
    vehicle.ownerUid !== actorUid ||
    vehicle.available === false
  ) {
    throw new CommandPolicyError(
        "permission-denied",
        "Choose an available vehicle from your fleet.",
    );
  }
  if (
    existingBid &&
    (existingBid.carrierUid !== actorUid ||
     existingBid.jobId !== data.jobId ||
     existingBid.status !== "pending")
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This carrier quote cannot be revised.",
    );
  }
  const amount = requireMoney(data.amount, "Carrier quote");
  const note = String(data.note || "").trim();
  if (note.length > 2000) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Quote notes must be 2,000 characters or fewer.",
    );
  }
  const availableDate = validateQuoteDate(data.availableDate, now);
  const payload = Number(
      vehicle.maximumPayloadKg || vehicle.calculatedPayloadKg || 0,
  );
  const loadWeight = Number(
      job.estimatedWeightKg || job.catalogWeightKg || 0,
  );
  if (
    Number.isFinite(payload) &&
    payload > 0 &&
    Number.isFinite(loadWeight) &&
    loadWeight > payload
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The selected vehicle payload is below the job's estimated weight.",
    );
  }
  if (existingBid) {
    const updatedAt = timestampMillis(
        existingBid.updatedAt || existingBid.createdAt,
    );
    if (updatedAt != null && timestampMillis(now) - updatedAt < 5000) {
      throw new CommandPolicyError(
          "resource-exhausted",
          "Wait a few seconds before revising this carrier quote.",
      );
    }
    if (Number(existingBid.revision || 1) >= 50) {
      throw new CommandPolicyError(
          "resource-exhausted",
          "The carrier quote revision limit has been reached.",
      );
    }
  }
  return {amount, note, availableDate};
}

function validateDispatchAward(job, bid, actorUid) {
  if (!job || job.createdByUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the Dispatch request owner can award this job.",
    );
  }
  if (job.status !== "open") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch job is no longer open.",
    );
  }
  if (
    !bid ||
    bid.jobId !== job.id ||
    bid.status !== "pending" ||
    !String(bid.carrierUid || "") ||
    !Number.isFinite(Number(bid.amount)) ||
    Number(bid.amount) <= 0
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The selected carrier quote is unavailable.",
    );
  }
  return {
    carrierUid: bid.carrierUid,
    amount: Number(bid.amount),
  };
}

module.exports = {
  validateDispatchAward,
  validateDispatchJobChange,
  validateDispatchJobInput,
  validateDispatchJobPublish,
  validateDispatchQuote,
};
