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

const DISPATCH_ACTIVE_TRANSACTION_STATES = new Set([
  "awarded",
  "accepted",
  "scheduled",
  "in_transit",
  "delivered",
]);

const DISPATCH_TERMINAL_TRANSACTION_STATES = new Set([
  "closed",
  "cancelled",
  "disputed",
]);

function validateDispatchTransactionAction({
  job,
  dispatchTransaction,
  actorUid,
  action,
  data = {},
  now,
  administrator = false,
}) {
  if (!job || !dispatchTransaction || dispatchTransaction.jobId !== job.id) {
    throw new CommandPolicyError(
        "not-found",
        "This awarded Dispatch job is unavailable.",
    );
  }
  const customerUid = String(dispatchTransaction.customerUid || "");
  const carrierUid = String(dispatchTransaction.carrierUid || "");
  const actorRole = actorUid === customerUid ?
    "customer" : actorUid === carrierUid ? "carrier" : null;
  if (!actorRole && !administrator) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the Dispatch customer or awarded carrier can update this job.",
    );
  }
  const status = String(dispatchTransaction.status || "awarded");
  if (action === "accept_award") {
    if (actorRole !== "carrier") {
      throw new CommandPolicyError(
          "permission-denied",
          "Only the awarded carrier can accept this job.",
      );
    }
    if (status === "accepted") return {status, actorRole, alreadyApplied: true};
    if (status !== "awarded") {
      throw new CommandPolicyError(
          "failed-precondition",
          "This Dispatch award cannot be accepted in its current state.",
      );
    }
    return {status: "accepted", actorRole, alreadyApplied: false};
  }
  if (action === "schedule") {
    if (actorRole !== "carrier") {
      throw new CommandPolicyError(
          "permission-denied",
          "Only the awarded carrier can schedule pickup.",
      );
    }
    if (!["accepted", "scheduled"].includes(status)) {
      throw new CommandPolicyError(
          "failed-precondition",
          "Accept the Dispatch award before scheduling pickup.",
      );
    }
    const scheduledDate = validateQuoteDate(data.scheduledDate, now);
    if (scheduledDate < timestampMillis(now)) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Scheduled pickup cannot be in the past.",
      );
    }
    return {
      status: "scheduled",
      actorRole,
      alreadyApplied: status === "scheduled" &&
        timestampMillis(dispatchTransaction.scheduledDate) === scheduledDate,
      scheduledDate,
    };
  }
  if (action === "start_transit") {
    if (actorRole !== "carrier") {
      throw new CommandPolicyError(
          "permission-denied",
          "Only the awarded carrier can start transport.",
      );
    }
    if (status === "in_transit") {
      return {status, actorRole, alreadyApplied: true};
    }
    if (status !== "scheduled") {
      throw new CommandPolicyError(
          "failed-precondition",
          "Schedule pickup before marking this load in transit.",
      );
    }
    return {status: "in_transit", actorRole, alreadyApplied: false};
  }
  if (action === "mark_delivered") {
    if (actorRole !== "carrier") {
      throw new CommandPolicyError(
          "permission-denied",
          "Only the awarded carrier can mark this load delivered.",
      );
    }
    if (status === "delivered") {
      return {status, actorRole, alreadyApplied: true};
    }
    if (status !== "in_transit") {
      throw new CommandPolicyError(
          "failed-precondition",
          "The load must be in transit before delivery can be recorded.",
      );
    }
    const receiverName = requireText(
        data.receiverName,
        "Receiver name",
        160,
    );
    const deliveryNote = requireText(
        data.deliveryNote,
        "Proof of delivery note",
        2000,
    );
    const proofStoragePath = optionalText(
        data.proofStoragePath,
        "Proof attachment path",
        500,
    );
    if (proofStoragePath &&
        (!proofStoragePath.startsWith(`dispatch_proof/${job.id}/`) ||
         proofStoragePath.includes(".."))) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Proof attachment path does not belong to this Dispatch job.",
      );
    }
    return {
      status: "delivered",
      actorRole,
      alreadyApplied: false,
      proofOfDelivery: {receiverName, deliveryNote, proofStoragePath},
    };
  }
  if (action === "confirm_delivery") {
    if (actorRole !== "customer") {
      throw new CommandPolicyError(
          "permission-denied",
          "Only the Dispatch customer can confirm delivery.",
      );
    }
    if (status === "closed") return {status, actorRole, alreadyApplied: true};
    if (status !== "delivered") {
      throw new CommandPolicyError(
          "failed-precondition",
          "The carrier must record delivery before the job can close.",
      );
    }
    return {status: "closed", actorRole, alreadyApplied: false};
  }

  const reason = requireText(data.reason, "Reason", 2000);
  if (reason.length < 10) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Provide a reason of at least 10 characters.",
    );
  }
  if (action === "cancel") {
    if (!actorRole || !["awarded", "accepted", "scheduled"].includes(status)) {
      throw new CommandPolicyError(
          "failed-precondition",
          "This Dispatch job can no longer be cancelled by a participant.",
      );
    }
    return {status: "cancelled", actorRole, alreadyApplied: false, reason};
  }
  if (action === "dispute") {
    if (!actorRole || !DISPATCH_ACTIVE_TRANSACTION_STATES.has(status)) {
      throw new CommandPolicyError(
          "failed-precondition",
          "This Dispatch job cannot be disputed in its current state.",
      );
    }
    return {status: "disputed", actorRole, alreadyApplied: false, reason};
  }
  if (action === "admin_resolve" && administrator) {
    if (status !== "disputed") {
      throw new CommandPolicyError(
          "failed-precondition",
          "Only a disputed Dispatch job can be resolved by an administrator.",
      );
    }
    const resolution = String(data.resolution || "").trim();
    if (!["closed", "cancelled"].includes(resolution)) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Administrator resolution must close or cancel the job.",
      );
    }
    return {
      status: resolution,
      actorRole: "administrator",
      alreadyApplied: false,
      reason,
    };
  }
  if (DISPATCH_TERMINAL_TRANSACTION_STATES.has(status)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This Dispatch transaction is already closed.",
    );
  }
  throw new CommandPolicyError(
      "permission-denied",
      "This Dispatch transaction action is not available.",
  );
}

module.exports = {
  DISPATCH_ACTIVE_TRANSACTION_STATES,
  DISPATCH_TERMINAL_TRANSACTION_STATES,
  validateDispatchAward,
  validateDispatchJobChange,
  validateDispatchJobInput,
  validateDispatchJobPublish,
  validateDispatchQuote,
  validateDispatchTransactionAction,
};
