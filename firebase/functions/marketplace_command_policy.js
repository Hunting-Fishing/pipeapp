"use strict";

const TERMINAL_AUCTION_STATUSES = new Set([
  "bought_now",
  "accepted_below_reserve",
  "won",
  "ended",
  "cancelled",
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

module.exports = {
  CommandPolicyError,
  TERMINAL_AUCTION_STATUSES,
  minimumAuctionBid,
  requireMoney,
  validateAcceptBelowReserve,
  validateBuyNow,
  validateLeadingBidRecord,
  validateOfferAcceptance,
  validatePlaceBid,
  validateWithdrawal,
};
