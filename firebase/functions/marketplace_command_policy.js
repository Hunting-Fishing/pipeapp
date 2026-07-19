"use strict";

const TERMINAL_AUCTION_STATUSES = new Set([
  "bought_now",
  "accepted_below_reserve",
  "won",
  "ended",
  "cancelled",
]);
const TRUCKING_PLANS = new Set([
  "buyer_arranged",
  "request_dispatch",
  "seller_pickup",
]);

class CommandPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CommandPolicyError";
    this.code = code;
  }
}

function timestampMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : null;
}

function requireMoney(value, fieldName) {
  const amount = Number(value);
  if (
    !Number.isFinite(amount) ||
    amount <= 0 ||
    amount > 1_000_000_000_000 ||
    Math.abs(amount * 100 - Math.round(amount * 100)) > 0.000001
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} must be a positive amount with no more than two decimals.`,
    );
  }
  return amount;
}

function minimumAuctionBid(listing) {
  const current = Number(listing.currentBid || 0);
  const starting = Number(listing.startingBid || listing.price || 0);
  const increment = Number(listing.minimumBidIncrement || 1);
  return current > 0 ? current + increment : starting;
}

function requireLiveAuction(listing, actorUid, now) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  if (listing.status !== "active") {
    throw new CommandPolicyError("failed-precondition", "This auction is not active.");
  }
  if (!String(listing.sellerUid || "")) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The auction seller is missing.",
    );
  }
  if (TERMINAL_AUCTION_STATUSES.has(listing.auctionStatus)) {
    throw new CommandPolicyError("failed-precondition", "This auction has ended.");
  }
  const nowMillis = timestampMillis(now);
  const startMillis = timestampMillis(listing.auctionStartAt);
  const endMillis = timestampMillis(listing.auctionEndAt);
  if (!startMillis || !endMillis || nowMillis < startMillis) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction has not started.",
    );
  }
  if (nowMillis >= endMillis) {
    throw new CommandPolicyError("failed-precondition", "This auction has ended.");
  }
  if (listing.sellerUid === actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Sellers cannot bid on their own auction.",
    );
  }
}

function validatePlaceBid(listing, actorUid, requestedAmount, now) {
  requireLiveAuction(listing, actorUid, now);
  const amount = requireMoney(requestedAmount, "Bid");
  const current = Number(listing.currentBid || 0);
  if (
    !Number.isFinite(current) ||
    current < 0 ||
    current > 1_000_000_000_000 ||
    Math.abs(current * 100 - Math.round(current * 100)) > 0.000001
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The current auction price is invalid.",
    );
  }
  const starting = requireMoney(
      listing.startingBid || listing.price,
      "Starting bid",
  );
  const increment = requireMoney(
      listing.minimumBidIncrement || 1,
      "Minimum bid increase",
  );
  const minimum = requireMoney(
      current > 0 ? current + increment : starting,
      "Minimum bid",
  );
  if (amount < minimum) {
    throw new CommandPolicyError(
        "failed-precondition",
        `The next bid must be at least ${minimum.toFixed(2)}.`,
    );
  }
  return {amount, minimum};
}

function validateBuyNow(listing, actorUid, now) {
  requireLiveAuction(listing, actorUid, now);
  return requireMoney(listing.buyItNowPrice, "Buy It Now price");
}

function validateAcceptBelowReserve(listing, actorUid, now) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  if (listing.sellerUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the seller can accept this bid.",
    );
  }
  if (TERMINAL_AUCTION_STATUSES.has(listing.auctionStatus)) {
    throw new CommandPolicyError("failed-precondition", "This auction has ended.");
  }
  if (listing.status !== "active") {
    throw new CommandPolicyError("failed-precondition", "This auction is not active.");
  }
  const startMillis = timestampMillis(listing.auctionStartAt);
  const endMillis = timestampMillis(listing.auctionEndAt);
  const nowMillis = timestampMillis(now);
  if (!startMillis || nowMillis < startMillis) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction has not started.",
    );
  }
  if (!endMillis || nowMillis >= endMillis) {
    throw new CommandPolicyError("failed-precondition", "This auction has ended.");
  }
  const current = requireMoney(listing.currentBid, "Leading bid");
  const reserve = requireMoney(listing.reservePrice, "Reserve price");
  const bidderUid = String(listing.highBidderUid || "");
  if (!bidderUid) {
    throw new CommandPolicyError(
        "failed-precondition",
        "There is no leading bid to accept.",
    );
  }
  if (current >= reserve) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The leading bid is not below the reserve.",
    );
  }
  return {amount: current, bidderUid};
}

function validateLeadingBidRecord(listingId, listing, bid) {
  if (
    !bid ||
    String(bid.listingId || "") !== listingId ||
    bid.status !== "leading" ||
    String(bid.bidderUid || "") !== String(listing.highBidderUid || "") ||
    Number(bid.amount || 0) !== Number(listing.currentBid || -1)
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The leading bid record is inconsistent. Refresh and try again.",
    );
  }
}

function validateWithdrawal(listingId, listing, bid, actorUid, now) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  if (
    listing.status !== "active" ||
    TERMINAL_AUCTION_STATUSES.has(listing.auctionStatus)
  ) {
    throw new CommandPolicyError("failed-precondition", "This auction has ended.");
  }
  if (
    !bid ||
    String(bid.listingId || "") !== listingId ||
    bid.bidderUid !== actorUid ||
    bid.status === "withdrawn"
  ) {
    throw new CommandPolicyError(
        "permission-denied",
        "This bid cannot be withdrawn.",
    );
  }
  const startMillis = timestampMillis(listing.auctionStartAt);
  const endMillis = timestampMillis(listing.auctionEndAt);
  const nowMillis = timestampMillis(now);
  const withdrawalAt = startMillis == null ?
    null :
    startMillis + 32 * 24 * 60 * 60 * 1000;
  if (
    listing.customAuction !== true ||
    withdrawalAt == null ||
    nowMillis < withdrawalAt
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Bid withdrawal is available after day 32 of a custom auction.",
    );
  }
  if (!endMillis || nowMillis >= endMillis) {
    throw new CommandPolicyError("failed-precondition", "This auction has ended.");
  }
}

function validateOfferAcceptance(offer, actorUid, listing) {
  if (!offer) {
    throw new CommandPolicyError("not-found", "This offer is unavailable.");
  }
  if (offer.sellerUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the seller can accept this offer.",
    );
  }
  if (offer.status !== "pending") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only a pending offer can be accepted.",
    );
  }
  if (!String(offer.listingId || "") || !String(offer.buyerUid || "")) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The offer is missing a listing or buyer.",
    );
  }
  if (
    !listing ||
    listing.sellerUid !== actorUid ||
    listing.sellerUid !== offer.sellerUid
  ) {
    throw new CommandPolicyError(
        "permission-denied",
        "The offer does not belong to this listing seller.",
    );
  }
  if (listing.transactionType === "Auction") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Auction listings use bids, not marketplace offers.",
    );
  }
  if (listing.status !== "active") {
    throw new CommandPolicyError(
        "failed-precondition",
        "The listing is not active.",
    );
  }
}

function optionalOfferDate(value, fieldName, now) {
  if (value == null) return null;
  const milliseconds = Number(value);
  if (!Number.isInteger(milliseconds)) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} is invalid.`,
    );
  }
  const nowMillis = timestampMillis(now);
  const earliest = nowMillis - 24 * 60 * 60 * 1000;
  const latest = nowMillis + 730 * 24 * 60 * 60 * 1000;
  if (milliseconds < earliest || milliseconds > latest) {
    throw new CommandPolicyError(
        "invalid-argument",
        `${fieldName} must be within the next two years.`,
    );
  }
  return milliseconds;
}

function validateDispatchDelivery(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Choose a Dispatch delivery destination.",
    );
  }
  const latitude = Number(raw.latitude);
  const longitude = Number(raw.longitude);
  if (
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The Dispatch delivery pin is invalid.",
    );
  }
  const text = {};
  for (const field of [
    "label",
    "address",
    "nearestTown",
    "region",
    "postalCode",
    "country",
    "accessNotes",
  ]) {
    const value = String(raw[field] || "").trim();
    if (value.length > (field === "accessNotes" ? 1000 : 250)) {
      throw new CommandPolicyError(
          "invalid-argument",
          `The delivery ${field} is too long.`,
      );
    }
    text[field] = value;
  }
  if (!text.label) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Name the Dispatch delivery destination.",
    );
  }
  return {latitude, longitude, ...text};
}

function validateOfferProposal({
  listing,
  conversation,
  actorUid,
  data,
  now,
}) {
  if (!listing || listing.status !== "active") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This listing is not accepting offers.",
    );
  }
  if (listing.transactionType === "Auction") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Auction listings use bids, not marketplace offers.",
    );
  }
  const sellerUid = String(listing.sellerUid || "");
  if (!sellerUid) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The listing seller is missing.",
    );
  }

  let buyerUid = actorUid;
  if (conversation) {
    const members = Array.isArray(conversation.memberUids) ?
      conversation.memberUids.map(String) :
      [];
    if (
      members.length !== 2 ||
      new Set(members).size !== 2 ||
      String(conversation.listingId || "") !== String(data.listingId || "") ||
      String(conversation.sellerUid || "") !== sellerUid ||
      !members.includes(actorUid) ||
      !members.includes(sellerUid)
    ) {
      throw new CommandPolicyError(
          "permission-denied",
          "This conversation does not belong to the listing participants.",
      );
    }
    buyerUid = members.find((member) => member !== sellerUid) || "";
  } else if (actorUid === sellerUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Sellers cannot submit an offer to their own listing.",
    );
  }
  if (!buyerUid || buyerUid === sellerUid) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The offer buyer is missing.",
    );
  }

  const offeredUnitPrice = requireMoney(
      data.offeredUnitPrice,
      "Offer price",
  );
  const requestedQuantity = Number(data.requestedQuantity);
  const availableQuantity = Number(listing.quantity || 0);
  if (
    !Number.isInteger(requestedQuantity) ||
    requestedQuantity <= 0 ||
    requestedQuantity > 1_000_000 ||
    (availableQuantity > 0 && requestedQuantity > availableQuantity)
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The requested quantity is unavailable.",
    );
  }
  const offeredTotal = requireMoney(
      offeredUnitPrice * requestedQuantity,
      "Offer total",
  );
  const note = String(data.note || "").trim();
  if (note.length > 2000) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Offer conditions must be 2,000 characters or fewer.",
    );
  }
  const truckingPlan = String(data.truckingPlan || "");
  if (!TRUCKING_PLANS.has(truckingPlan)) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Choose how trucking will be handled.",
    );
  }
  const purchaseDate = optionalOfferDate(
      data.purchaseDate,
      "Purchase date",
      now,
  );
  const moneyTransferDate = optionalOfferDate(
      data.moneyTransferDate,
      "Money transfer date",
      now,
  );
  const truckingDate = optionalOfferDate(
      data.truckingDate,
      "Trucking date",
      now,
  );
  let dispatchDelivery = null;
  if (truckingPlan === "request_dispatch") {
    if (truckingDate == null) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Choose a trucking date for the Dispatch request.",
      );
    }
    dispatchDelivery = validateDispatchDelivery(data.dispatchDelivery);
  }

  return {
    sellerUid,
    buyerUid,
    offeredUnitPrice,
    offeredTotal,
    requestedQuantity,
    note,
    truckingPlan,
    purchaseDate,
    moneyTransferDate,
    truckingDate,
    dispatchDelivery,
  };
}

function validateOfferFrequency(offers, buyerUid, now) {
  const buyerOffers = offers.filter(
      (offer) => String(offer.buyerUid || "") === buyerUid,
  );
  if (buyerOffers.length >= 50) {
    throw new CommandPolicyError(
        "resource-exhausted",
        "The offer revision limit has been reached for this listing.",
    );
  }
  const nowMillis = timestampMillis(now);
  if (buyerOffers.some((offer) => {
    const createdAt = timestampMillis(offer.createdAt);
    return createdAt != null && nowMillis - createdAt < 5000;
  })) {
    throw new CommandPolicyError(
        "resource-exhausted",
        "Wait a few seconds before sending another offer revision.",
    );
  }
  return buyerOffers.length + 1;
}

module.exports = {
  CommandPolicyError,
  TERMINAL_AUCTION_STATUSES,
  minimumAuctionBid,
  requireMoney,
  validateAcceptBelowReserve,
  validateBuyNow,
  validateLeadingBidRecord,
  validateOfferAcceptance,
  validateOfferFrequency,
  validateOfferProposal,
  validatePlaceBid,
  validateWithdrawal,
};
