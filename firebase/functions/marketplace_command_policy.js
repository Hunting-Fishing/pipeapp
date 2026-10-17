"use strict";

const {
  contactSharingSignals,
  listingContactSignals,
} = require("./marketplace_contact_policy");

const {
  approvedAccountVerification,
} = require("./account_verification_policy");
const {
  marketplacePriceBasis,
  marketplaceQuantity,
} = require("./marketplace_listing_policy");

const TERMINAL_AUCTION_STATUSES = new Set([
  "bought_now",
  "accepted_below_reserve",
  "won",
  "ended",
  "cancelled",
]);
const AUCTION_PENDING_SALE_STATUSES = new Set([
  "bought_now",
  "accepted_below_reserve",
  "won",
]);
const TRUCKING_PLANS = new Set([
  "buyer_arranged",
  "request_dispatch",
  "seller_pickup",
]);
const MARKETPLACE_SALE_TRANSACTION_TYPES = new Set([
  "For Sale",
  // Compatibility for records created before the current listing vocabulary.
  "Marketplace",
]);
const MARKETPLACE_TRANSACTION_CURRENCIES = new Set(["CAD", "USD"]);

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

function auctionListingLifecycleStatus(auctionStatus) {
  const normalized = String(auctionStatus || "").trim();
  if (AUCTION_PENDING_SALE_STATUSES.has(normalized)) return "pending_sale";
  if (normalized === "ended" || normalized === "cancelled") return "archived";
  throw new CommandPolicyError(
      "internal",
      "The terminal auction lifecycle state is invalid.",
  );
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

function isTotalPriceBasis(value) {
  const basis = marketplacePriceBasis(value);
  return Boolean(basis && basis.kind === "total");
}

function requireMarketplaceSaleTerms(listing, {
  quantityField = "quantity",
  allowTotalQuantityDefault = true,
} = {}) {
  const basis = marketplacePriceBasis(listing && listing.priceBasis);
  if (!basis) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This listing uses a price basis that cannot be settled safely. Choose " +
        "a total price or supported count-based price before selling.",
    );
  }
  const quantity = marketplaceQuantity(listing && listing[quantityField], {
    allowMissingTotal: allowTotalQuantityDefault,
    priceBasis: basis.canonical,
  });
  if (quantity == null) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The listing quantity is invalid and must be a whole number between 1 " +
        "and 1,000,000 before selling.",
    );
  }
  return {
    priceBasis: basis.canonical,
    priceBasisKind: basis.kind,
    quantity,
  };
}

function validateAuctionSaleTerms(listing) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  const hasAuctionQuantity = Object.prototype.hasOwnProperty.call(
      listing,
      "auctionQuantity",
  );
  const hasAuctionPriceBasis = Object.prototype.hasOwnProperty.call(
      listing,
      "auctionPricingBasis",
  );
  return requireMarketplaceSaleTerms({
    quantity: hasAuctionQuantity ? listing.auctionQuantity : listing.quantity,
    priceBasis: hasAuctionPriceBasis ?
      listing.auctionPricingBasis : listing.priceBasis,
  });
}

function isMarketplaceSaleListing(listing) {
  return MARKETPLACE_SALE_TRANSACTION_TYPES.has(
      String(listing && listing.transactionType || "").trim(),
  );
}

function marketplaceTransactionCurrency(value) {
  const currency = String(value || "").trim().toUpperCase();
  if (!MARKETPLACE_TRANSACTION_CURRENCIES.has(currency)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This listing has no supported transaction currency. It must be reviewed " +
        "before a new offer, bid, or sale can be recorded.",
    );
  }
  return currency;
}

function listingUsesFirmPrice(listing) {
  return listing && (
    listing.openToOffers === false ||
    String(listing.priceFlexibility || "").trim().toLowerCase() === "firm"
  );
}

function expectedOfferTotalAtAsk(listing, requestedQuantity) {
  const askingPrice = requireMoney(listing && listing.price, "Listing price");
  const terms = requireMarketplaceSaleTerms(listing);
  const rawTotal = terms.priceBasisKind === "total" ?
    askingPrice * requestedQuantity / terms.quantity :
    askingPrice * requestedQuantity;
  return Math.round((rawTotal + Number.EPSILON) * 100) / 100;
}

function requireFirmPriceMatch(listing, requestedQuantity, offeredTotal) {
  if (!listingUsesFirmPrice(listing)) return;
  const expectedTotal = expectedOfferTotalAtAsk(listing, requestedQuantity);
  const offeredMinor = Math.round(Number(offeredTotal) * 100);
  const expectedMinor = Math.round(expectedTotal * 100);
  if (!Number.isSafeInteger(offeredMinor) || offeredMinor !== expectedMinor) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This is a firm-price listing. Submit the seller's asking price for the " +
        "quantity requested.",
    );
  }
}

function minimumAuctionBid(listing) {
  const current = Number(listing.currentBid || 0);
  const starting = Number(listing.startingBid || listing.price || 0);
  const increment = Number(listing.minimumBidIncrement || 1);
  return current > 0 ? current + increment : starting;
}

function optionalMoney(value, fieldName) {
  if (value == null || value === "") return null;
  return requireMoney(value, fieldName);
}

function validateAuctionConversion({
  listing,
  actorUid,
  user,
  administrator,
  data,
  paidFeaturesEnabled,
  now,
}) {
  if (!listing || listing.sellerUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the listing owner can move this item to Auctions.",
    );
  }
  if (listing.status !== "active") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only an active listing can be moved to Auctions.",
    );
  }
  if (listing.transactionType === "Auction") {
    throw new CommandPolicyError(
        "failed-precondition",
        "This listing is already a timed auction.",
    );
  }
  if (listing.transactionType === "Wanted / Seeking") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Wanted ads cannot be converted to timed auctions.",
    );
  }
  if (!isMarketplaceSaleListing(listing)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only a For Sale Marketplace listing can be moved to Timed Buying.",
    );
  }
  if (!administrator && (
    Number(user && user.userScore || 70) <= 80 ||
    Number(user && user.profileCompletion || 0) !== 100 ||
    !approvedAccountVerification(user)
  )) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Auction listings require a User Score above 80, a complete " +
        "profile, and verified account status.",
    );
  }

  const startingBid = requireMoney(data && data.startingBid, "Starting bid");
  const minimumBidIncrement = requireMoney(
      data && data.minimumBidIncrement,
      "Minimum bid increase",
  );
  if (minimumBidIncrement < 0.5 || minimumBidIncrement > 1000) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Minimum bid increase must be between 0.50 and 1,000.00.",
    );
  }
  const reservePrice = optionalMoney(
      data && data.reservePrice,
      "Reserve price",
  );
  const buyItNowPrice = optionalMoney(
      data && data.buyItNowPrice,
      "Buy It Now price",
  );
  if (reservePrice != null && reservePrice < startingBid) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Reserve price must be at least the starting bid.",
    );
  }
  if (
    buyItNowPrice != null &&
    (buyItNowPrice < startingBid ||
      (reservePrice != null && buyItNowPrice < reservePrice))
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Buy It Now must be at least the starting bid and reserve price.",
    );
  }

  const durationDays = Number(data && data.durationDays);
  const customAuction = data && data.customAuction === true;
  const standardDurations = new Set([1, 3, 5, 7, 10, 14, 30]);
  if (
    !Number.isInteger(durationDays) ||
    durationDays < 1 ||
    durationDays > 360 ||
    (!customAuction && !standardDurations.has(durationDays))
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Choose a supported auction duration from 1 to 360 days.",
    );
  }
  if (customAuction && paidFeaturesEnabled !== true) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Custom-duration auctions are not currently available.",
    );
  }
  const nowMillis = timestampMillis(now);
  if (!Number.isFinite(nowMillis)) {
    throw new CommandPolicyError(
        "internal",
        "Auction timing could not be established.",
    );
  }
  const saleTerms = requireMarketplaceSaleTerms(listing);
  const askingPrice = Number(listing.price || 0);
  const askingTotal = Number.isFinite(askingPrice) && askingPrice > 0 ?
    (saleTerms.priceBasisKind === "total" ?
      askingPrice :
      askingPrice * saleTerms.quantity) :
    0;

  return {
    startingBid,
    minimumBidIncrement,
    reservePrice,
    buyItNowPrice,
    durationDays,
    customAuction,
    auctionStartAt: nowMillis,
    auctionEndAt: nowMillis + durationDays * 24 * 60 * 60 * 1000,
    priceBasis: saleTerms.priceBasis,
    quantity: saleTerms.quantity,
    askingPrice: Number.isFinite(askingPrice) ? askingPrice : 0,
    askingTotal,
  };
}

const LISTING_EDITABLE_FIELDS = new Set([
  "title",
  "price",
  "priceBasis",
  "priceFlexibility",
  "openToOffers",
  "quantity",
  "condition",
  "description",
  "inspectionStatus",
  "inspectionDetails",
]);

function validateListingDetailsUpdate({listing, actorUid, data}) {
  if (!listing || listing.sellerUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the listing owner can edit this listing.",
    );
  }
  if (listing.transactionType === "Auction") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Live auctions cannot be edited as Marketplace listings.",
    );
  }
  if (!["active", "paused"].includes(listing.status)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only active or paused listings can be edited.",
    );
  }
  const expectedRevision = Number(data && data.expectedRevision);
  const currentRevision = Number(listing.revision || 1);
  if (!Number.isInteger(expectedRevision) || expectedRevision !== currentRevision) {
    throw new CommandPolicyError(
        "aborted",
        "This listing changed on another device. Refresh it before editing.",
    );
  }
  const patch = data && data.patch;
  if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
    throw new CommandPolicyError("invalid-argument", "Listing changes are missing.");
  }
  const keys = Object.keys(patch);
  if (keys.length === 0 || keys.length > LISTING_EDITABLE_FIELDS.size ||
      keys.some((key) => !LISTING_EDITABLE_FIELDS.has(key))) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The listing contains unsupported changes.",
    );
  }
  const changes = {};
  for (const key of keys) {
    const value = patch[key];
    if (["title", "priceFlexibility", "condition"].includes(key)) {
      const text = String(value || "").trim();
      if (!text || text.length > 240) {
        throw new CommandPolicyError("invalid-argument", `${key} is invalid.`);
      }
      changes[key] = text;
    } else if (key === "priceBasis") {
      const basis = marketplacePriceBasis(value);
      if (!basis) {
        throw new CommandPolicyError(
            "invalid-argument",
            "Choose a total price or a supported count-based price.",
        );
      }
      changes[key] = basis.canonical;
    } else if (["description", "inspectionDetails"].includes(key)) {
      const text = String(value || "").trim();
      if (text.length > 12000) {
        throw new CommandPolicyError("invalid-argument", `${key} is too long.`);
      }
      changes[key] = text;
    } else if (key === "inspectionStatus") {
      changes[key] = String(value || "").trim().slice(0, 240);
    } else if (key === "price") {
      changes[key] = requireMoney(value, "Price");
    } else if (key === "quantity") {
      if (typeof value !== "number" ||
          !Number.isSafeInteger(value) ||
          value < 1 ||
          value > 1_000_000) {
        throw new CommandPolicyError(
            "invalid-argument",
            "Quantity must be a whole number between 1 and 1,000,000.",
        );
      }
      changes[key] = value;
    } else if (key === "openToOffers") {
      if (typeof value !== "boolean") {
        throw new CommandPolicyError(
            "invalid-argument",
            "Offer availability must be true or false.",
        );
      }
      changes[key] = value;
    }
  }
  if (isMarketplaceSaleListing(listing) &&
      (Object.hasOwn(changes, "priceBasis") ||
       Object.hasOwn(changes, "quantity"))) {
    requireMarketplaceSaleTerms({...listing, ...changes});
  }
  if (listingContactSignals(changes).length > 0) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Remove phone numbers, email addresses, websites, and contact handles. " +
        "Keep buyer and seller communication in secure marketplace messages.",
    );
  }
  return {changes, currentRevision, nextRevision: currentRevision + 1};
}

function validateListingTransition({listing, actorUid, action}) {
  if (!listing || listing.sellerUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the listing owner can change this listing.",
    );
  }
  if (listing.transactionType === "Auction") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Auction status is controlled by the auction lifecycle.",
    );
  }
  if (action === "mark_sold") {
    throw new CommandPolicyError(
        "failed-precondition",
        "Marketplace sales must be completed from an accepted offer through the " +
        "authoritative payment or external-settlement workflow.",
    );
  }
  const transitions = {
    pause: {from: ["active"], to: "paused"},
    activate: {from: ["paused"], to: "active"},
    mark_fulfilled: {from: ["active", "paused"], to: "fulfilled"},
    archive: {
      from: ["active", "paused", "sold", "fulfilled"],
      to: "archived",
    },
  };
  const wanted = listing.transactionType === "Wanted / Seeking";
  if (action === "mark_fulfilled" && !wanted) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only wanted ads can be marked fulfilled.",
    );
  }
  const transition = transitions[action];
  if (!transition || !transition.from.includes(listing.status)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This listing status change is not available.",
    );
  }
  return {
    action,
    previousStatus: listing.status,
    status: transition.to,
    nextRevision: Number(listing.revision || 1) + 1,
  };
}

function validateListingRelist({listing, actorUid, newListingId}) {
  if (!listing || listing.sellerUid !== actorUid) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the listing owner can relist this item.",
    );
  }
  if (listing.transactionType === "Auction" ||
      !["sold", "fulfilled", "archived"].includes(listing.status)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only sold, fulfilled, or archived Marketplace listings can be relisted.",
    );
  }
  if (!newListingId || newListingId === listing.id) {
    throw new CommandPolicyError(
        "invalid-argument",
        "A new listing identifier is required for relisting.",
    );
  }
  return {newListingId};
}

function requireLiveAuction(listing, actorUid, now) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  validateAuctionSaleTerms(listing);
  if (listing.ownerUid != null &&
      String(listing.ownerUid || "") !== String(listing.sellerUid || "")) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The private auction terms do not match the seller and require review.",
    );
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
  const buyItNowPrice = optionalMoney(
      listing.buyItNowPrice,
      "Buy It Now price",
  );
  if (buyItNowPrice != null && amount >= buyItNowPrice) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Use Buy It Now to purchase at or above the fixed closing price.",
    );
  }
  return {amount, minimum};
}

function validateBuyNow(listing, actorUid, now) {
  requireLiveAuction(listing, actorUid, now);
  const price = requireMoney(listing.buyItNowPrice, "Buy It Now price");
  const current = Number(listing.currentBid || 0);
  if (Number.isFinite(current) && current >= price) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Buy It Now is no longer available after bidding reaches that price.",
    );
  }
  return price;
}

function validateAcceptBelowReserve(listing, actorUid, now) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  validateAuctionSaleTerms(listing);
  if (typeof listing.ownerUid !== "string" ||
      listing.ownerUid.trim() !== String(listing.sellerUid || "")) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The private auction terms do not match the seller and require review.",
    );
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

function validateAuctionFinalization({listing, privateAuction, now}) {
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  const saleTerms = validateAuctionSaleTerms(listing);
  const sellerUid = typeof listing.sellerUid === "string" ?
    listing.sellerUid.trim() : "";
  if (!sellerUid) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The auction seller is missing and requires review.",
    );
  }
  if (listing.status !== "active" ||
      TERMINAL_AUCTION_STATUSES.has(listing.auctionStatus)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction has already been finalized.",
    );
  }
  const nowMillis = timestampMillis(now);
  const endMillis = timestampMillis(listing.auctionEndAt);
  if (!endMillis || !nowMillis || nowMillis < endMillis) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction is still accepting bids.",
    );
  }
  const rawAmount = listing.currentBid;
  let amount = 0;
  if (rawAmount != null && rawAmount !== 0) {
    if (typeof rawAmount !== "number") {
      throw new CommandPolicyError(
          "failed-precondition",
          "The leading bid amount is invalid and requires review.",
      );
    }
    try {
      amount = requireMoney(rawAmount, "Leading bid");
    } catch (_) {
      throw new CommandPolicyError(
          "failed-precondition",
          "The leading bid amount is invalid and requires review.",
      );
    }
  }
  const winnerUid = typeof listing.highBidderUid === "string" ?
    listing.highBidderUid.trim() : "";
  if ((amount > 0) !== Boolean(winnerUid)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The leading bid and bidder do not match and require review.",
    );
  }
  if (
    Object.prototype.hasOwnProperty.call(listing, "reservePrice") ||
    Object.prototype.hasOwnProperty.call(listing, "reserveTotal")
  ) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction has legacy public reserve data that must be moved to the " +
        "private reserve record before finalization.",
    );
  }
  let reserve = null;
  if (privateAuction != null) {
    if (typeof privateAuction !== "object" || Array.isArray(privateAuction) ||
        typeof privateAuction.ownerUid !== "string" ||
        privateAuction.ownerUid.trim() !== sellerUid ||
        !Object.prototype.hasOwnProperty.call(privateAuction, "reservePrice")) {
      throw new CommandPolicyError(
          "failed-precondition",
          "The private auction reserve record is incomplete or belongs to a " +
          "different seller.",
      );
    }
    try {
      reserve = requireMoney(privateAuction.reservePrice, "Reserve price");
      if (Object.prototype.hasOwnProperty.call(privateAuction, "reserveTotal")) {
        const reserveTotal = requireMoney(
            privateAuction.reserveTotal,
            "Reserve total",
        );
        const expectedReserveTotal = saleTerms.priceBasisKind === "total" ?
          reserve :
          Math.round((reserve * saleTerms.quantity + Number.EPSILON) * 100) / 100;
        if (Math.round(reserveTotal * 100) !==
            Math.round(expectedReserveTotal * 100)) {
          throw new Error("reserve-total-mismatch");
        }
      }
    } catch (_) {
      throw new CommandPolicyError(
          "failed-precondition",
          "The private auction reserve amount is invalid and requires review.",
      );
    }
  }
  const reserveMet = reserve == null || amount >= reserve;
  const won = Number.isFinite(amount) && amount > 0 && !!winnerUid && reserveMet;
  return {
    amount: Number.isFinite(amount) ? amount : 0,
    auctionStatus: won ? "won" : "ended",
    reserveMet,
    winnerUid: won ? winnerUid : "",
  };
}

function paymentStatusAllowsCompletion(
    value,
    marketplaceFeeStatus,
    paymentState = {},
) {
  const state = paymentState && typeof paymentState === "object" ?
    paymentState : {};
  const providerStatus = String(value || "");
  const feeStatus = String(
      marketplaceFeeStatus || state.marketplaceFeeStatus || "",
  );
  if (!["paid", "external_agreed"].includes(providerStatus) ||
      feeStatus !== "collected" || state.financialHold === true ||
      String(state.stripeSettlementReconciliationId || "").trim()) {
    return false;
  }
  const blockingStatuses = new Set([
    "charged_back",
    "disputed",
    "partially_refunded",
    "refund_pending",
    "refund_processing",
    "refund_requested",
    "refunded",
  ]);
  if (blockingStatuses.has(String(state.financialStatus || "")) ||
      blockingStatuses.has(String(state.marketplaceFeeFinancialStatus || "")) ||
      new Set(["open", "lost"]).has(String(state.disputeStatus || "")) ||
      new Set(["open", "lost"]).has(
          String(state.marketplaceFeeDisputeStatus || ""),
      ) || String(state.activeDisputeId || "").trim()) {
    return false;
  }
  for (const field of ["refundedMinor", "marketplaceFeeRefundedMinor"]) {
    if (state[field] == null) continue;
    const amount = Number(state[field]);
    if (!Number.isSafeInteger(amount) || amount !== 0) return false;
  }
  for (const field of [
    "activeDisputeIds",
    "lostDisputeIds",
    "activeMarketplaceFeeDisputeIds",
    "lostMarketplaceFeeDisputeIds",
  ]) {
    if (state[field] == null) continue;
    if (!Array.isArray(state[field]) || state[field].length > 0) return false;
  }
  return true;
}

function paymentStateAllowsCancellation(sale) {
  if (!sale) return true;
  const providerStatus = String(sale.paymentProviderStatus || "").trim();
  const cancellableStatuses = new Set(["", "not_started", "failed"]);
  if (!cancellableStatuses.has(providerStatus)) return false;
  if (
    sale.stripeCheckoutSessionId ||
    sale.stripeCheckoutAttemptId ||
    sale.stripeCheckoutIdempotencyKey ||
    sale.stripeCheckoutRequestSnapshot ||
    sale.stripePaymentIntentId ||
    sale.stripeChargeId ||
    sale.stripeSellerTransferId ||
    sale.stripeMarketplaceFeePaymentIntentId ||
    sale.stripeMarketplaceFeeChargeId ||
    sale.externalSettlementBuyerConfirmed === true ||
    sale.externalSettlementSellerConfirmed === true ||
    String(sale.paymentProvider || "") === "external" ||
    String(sale.paymentMethod || "") === "external_settlement"
  ) {
    return false;
  }
  return true;
}

function validateTimedAuctionAdministration({
  listing,
  sale,
  payment,
  action,
  now,
}) {
  const normalizedAction = String(action || "").trim();
  if (![
    "extend_24h",
    "force_end",
    "cancel",
  ].includes(normalizedAction)) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The timed-auction administrator action is unsupported.",
    );
  }
  if (!listing || listing.transactionType !== "Auction") {
    throw new CommandPolicyError("not-found", "This auction is unavailable.");
  }
  if (!String(listing.sellerUid || "").trim()) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The auction seller is missing and requires review.",
    );
  }

  const auctionStatus = String(listing.auctionStatus || "").trim();
  const listingStatus = String(listing.status || "").trim();
  const saleStatus = String(listing.saleStatus || "").trim();
  const hasAcceptedOutcome =
    AUCTION_PENDING_SALE_STATUSES.has(auctionStatus) ||
    listingStatus === "pending_sale" ||
    !!String(listing.acceptedBidderUid || "").trim() ||
    !!String(listing.buyNowBuyerUid || "").trim() ||
    (saleStatus !== "" && saleStatus !== "not_started");
  if (hasAcceptedOutcome || sale || payment) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction already has a sale or payment outcome. Use the " +
        "settlement, dispute, or refund workflow instead.",
    );
  }
  if (listingStatus !== "active" ||
      !["live", "scheduled"].includes(auctionStatus)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only a live or scheduled auction can be administered.",
    );
  }

  const nowMillis = timestampMillis(now);
  const startMillis = timestampMillis(listing.auctionStartAt);
  const endMillis = timestampMillis(listing.auctionEndAt);
  if (!Number.isFinite(nowMillis) ||
      !Number.isFinite(startMillis) ||
      !Number.isFinite(endMillis) ||
      endMillis <= startMillis) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The auction timing is invalid and requires review.",
    );
  }

  if (normalizedAction === "extend_24h") {
    if (nowMillis >= endMillis) {
      throw new CommandPolicyError(
          "failed-precondition",
          "An expired auction cannot be reopened by extending it.",
      );
    }
    const extendedEndMillis = endMillis + 24 * 60 * 60 * 1000;
    if (extendedEndMillis - startMillis > 360 * 24 * 60 * 60 * 1000) {
      throw new CommandPolicyError(
          "failed-precondition",
          "The extension would exceed the 360-day auction limit.",
      );
    }
    return {
      action: normalizedAction,
      auctionEndAt: extendedEndMillis,
      auctionStatus,
      status: listingStatus,
    };
  }

  if (normalizedAction === "force_end") {
    return {
      action: normalizedAction,
      auctionEndAt: nowMillis,
      auctionStatus,
      status: listingStatus,
    };
  }

  return {
    action: normalizedAction,
    auctionEndAt: endMillis,
    auctionStatus: "cancelled",
    status: auctionListingLifecycleStatus("cancelled"),
  };
}

function validateAuctionTransactionAction({
  sale,
  listing,
  actorUid,
  action,
  reason,
  paymentProviderStatus,
  marketplaceFeeStatus,
  paymentState,
  administrator = false,
}) {
  if (!sale || !listing || sale.listingId !== listing.id) {
    throw new CommandPolicyError(
        "not-found",
        "This auction settlement is unavailable.",
    );
  }
  const buyerUid = String(sale.buyerUid || "");
  const sellerUid = String(sale.sellerUid || "");
  const actorRole = actorUid === buyerUid ?
    "buyer" : actorUid === sellerUid ? "seller" : null;
  if (!actorRole && !administrator) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the winning bidder or seller can update this settlement.",
    );
  }
  const status = String(sale.status || "pending_completion");
  const buyerConfirmed = sale.buyerConfirmed === true;
  const sellerConfirmed = sale.sellerConfirmed === true;
  if (action === "confirm_completion") {
    if (!actorRole) {
      throw new CommandPolicyError(
          "permission-denied",
          "An auction participant must confirm completion.",
      );
    }
    const alreadyConfirmed = actorRole === "buyer" ?
      buyerConfirmed : sellerConfirmed;
    if (status === "completed" && alreadyConfirmed) {
      return {
        actorRole,
        alreadyApplied: true,
        buyerConfirmed,
        sellerConfirmed,
        status,
      };
    }
    if (!paymentStatusAllowsCompletion(
        paymentProviderStatus,
        marketplaceFeeStatus,
        {
          ...(paymentState || {}),
          paymentProviderStatus,
          marketplaceFeeStatus,
        },
    )) {
      throw new CommandPolicyError(
          "failed-precondition",
          "The winning purchase and any Pipe Buyer marketplace fee must be paid " +
          "before completion can be confirmed.",
      );
    }
    if (!["pending_completion", "awaiting_buyer_confirmation",
      "awaiting_seller_confirmation"].includes(status)) {
      throw new CommandPolicyError(
          "failed-precondition",
          "This settlement cannot be confirmed in its current state.",
      );
    }
    const nextBuyer = buyerConfirmed || actorRole === "buyer";
    const nextSeller = sellerConfirmed || actorRole === "seller";
    return {
      actorRole,
      alreadyApplied: alreadyConfirmed,
      buyerConfirmed: nextBuyer,
      sellerConfirmed: nextSeller,
      status: nextBuyer && nextSeller ?
        "completed" : nextBuyer ?
          "awaiting_seller_confirmation" : "awaiting_buyer_confirmation",
    };
  }
  const normalizedReason = String(reason || "").trim();
  if (normalizedReason.length < 10 || normalizedReason.length > 2000) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Provide a reason between 10 and 2,000 characters.",
    );
  }
  if ([
    "completed",
    "cancelled",
    "disputed",
    "buyer_default_reported",
    "seller_default_reported",
  ].includes(status)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "This auction settlement is already closed.",
    );
  }
  if (action === "dispute" && actorRole) {
    return {
      actorRole,
      alreadyApplied: false,
      buyerConfirmed,
      sellerConfirmed,
      reason: normalizedReason,
      status: "disputed",
    };
  }
  if (action === "report_buyer_default" && actorRole === "seller") {
    return {
      actorRole,
      alreadyApplied: false,
      buyerConfirmed,
      sellerConfirmed,
      reason: normalizedReason,
      status: "buyer_default_reported",
    };
  }
  if (action === "report_seller_default" && actorRole === "buyer") {
    return {
      actorRole,
      alreadyApplied: false,
      buyerConfirmed,
      sellerConfirmed,
      reason: normalizedReason,
      status: "seller_default_reported",
    };
  }
  if (action === "admin_cancel" && administrator) {
    const cancellationState = {
      ...sale,
      ...(paymentState || {}),
      paymentProviderStatus: paymentProviderStatus ||
        paymentState && paymentState.paymentProviderStatus ||
        sale.paymentProviderStatus || "",
    };
    if (
      status !== "pending_completion" ||
      buyerConfirmed ||
      sellerConfirmed ||
      !paymentStateAllowsCancellation(cancellationState)
    ) {
      throw new CommandPolicyError(
          "failed-precondition",
          "Administrator cancellation is unavailable after payment, external " +
          "settlement, or completion begins. Use dispute or refund review.",
      );
    }
    return {
      actorRole: "administrator",
      alreadyApplied: false,
      buyerConfirmed,
      sellerConfirmed,
      reason: normalizedReason,
      status: "cancelled",
    };
  }
  throw new CommandPolicyError(
      "permission-denied",
      "This auction settlement action is not available.",
  );
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
  if (!isMarketplaceSaleListing(listing)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only For Sale Marketplace listings can accept purchase offers.",
    );
  }
  if (listing.status !== "active") {
    throw new CommandPolicyError(
        "failed-precondition",
        "The listing is not active.",
    );
  }
  requireMarketplaceSaleTerms(listing);
  const offerCurrency = marketplaceTransactionCurrency(offer.currency);
  const listingCurrency = marketplaceTransactionCurrency(listing.currency);
  if (offerCurrency !== listingCurrency) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The offer currency does not match the listing currency.",
    );
  }
  requireFirmPriceMatch(
      listing,
      Number(offer.requestedQuantity),
      Number(offer.offeredTotal),
  );
}

function marketplaceOfferInventoryReservation(offer, listing) {
  const availableQuantity = Number(listing && listing.quantity);
  const reservedQuantity = Number(offer && offer.requestedQuantity);
  if (!Number.isSafeInteger(availableQuantity) || availableQuantity <= 0 ||
      !Number.isSafeInteger(reservedQuantity) || reservedQuantity <= 0 ||
      reservedQuantity > availableQuantity) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The listing no longer has enough inventory for this offer.",
    );
  }
  return {
    inventoryQuantityAtAcceptance: availableQuantity,
    inventoryPriceAtAcceptance:
      Number.isFinite(Number(listing.price)) ? Number(listing.price) : null,
    inventoryPriceBasisAtAcceptance: String(listing.priceBasis || ""),
    reservedQuantity,
    remainingQuantityAfterAcceptance: availableQuantity - reservedQuantity,
    partialQuantitySale: reservedQuantity < availableQuantity,
  };
}

function marketplaceOfferInventoryCompletion(sale, listing) {
  const storedQuantityAtAcceptance = Number(
      sale && sale.inventoryQuantityAtAcceptance,
  );
  const reservedQuantity = Number(
      sale && (sale.reservedQuantity || sale.agreedQuantity),
  );
  const currentQuantity = Number(listing && listing.quantity);
  const quantityAtAcceptance =
    Number.isSafeInteger(storedQuantityAtAcceptance) &&
      storedQuantityAtAcceptance > 0 ?
      storedQuantityAtAcceptance :
      currentQuantity;
  if (!Number.isSafeInteger(quantityAtAcceptance) ||
      quantityAtAcceptance <= 0 ||
      !Number.isSafeInteger(reservedQuantity) || reservedQuantity <= 0 ||
      reservedQuantity > quantityAtAcceptance ||
      currentQuantity !== quantityAtAcceptance) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The reserved listing inventory changed before completion.",
    );
  }
  const remainingQuantity = quantityAtAcceptance - reservedQuantity;
  const partialQuantitySale = remainingQuantity > 0;
  const storedPriceAtAcceptance = Number(sale.inventoryPriceAtAcceptance);
  const priceAtAcceptance = Number.isFinite(storedPriceAtAcceptance) &&
      storedPriceAtAcceptance > 0 ?
    storedPriceAtAcceptance :
    Number(listing && listing.price);
  const priceBasis = String(
      sale.inventoryPriceBasisAtAcceptance || sale.priceBasis ||
      listing.priceBasis || "",
  );
  const remainingTotalPrice = partialQuantitySale &&
      isTotalPriceBasis(priceBasis) &&
      Number.isFinite(priceAtAcceptance) && priceAtAcceptance > 0 ?
    Math.round(
        priceAtAcceptance * remainingQuantity / quantityAtAcceptance * 100,
    ) / 100 :
    null;
  return {
    partialQuantitySale,
    remainingQuantity,
    remainingTotalPrice,
  };
}

function validateMarketplaceTransactionAction({
  sale,
  offer,
  actorUid,
  action,
  reason,
}) {
  if (!offer || offer.status !== "accepted") {
    throw new CommandPolicyError(
        "failed-precondition",
        "An accepted offer is required for this transaction.",
    );
  }
  const buyerUid = String(offer.buyerUid || "");
  const sellerUid = String(offer.sellerUid || "");
  const actorRole = actorUid === buyerUid ?
    "buyer" :
    actorUid === sellerUid ? "seller" : null;
  if (!actorRole) {
    throw new CommandPolicyError(
        "permission-denied",
        "Only the buyer or seller can update this transaction.",
    );
  }
  if (sale && (
    String(sale.offerId || "") !== String(offer.id || "") ||
    String(sale.buyerUid || "") !== buyerUid ||
    String(sale.sellerUid || "") !== sellerUid
  )) {
    throw new CommandPolicyError(
        "failed-precondition",
        "The transaction participants do not match the accepted offer.",
    );
  }
  const status = String(sale && sale.status || "pending_completion");
  const buyerConfirmed = sale && sale.buyerConfirmed === true;
  const sellerConfirmed = sale && sale.sellerConfirmed === true;
  if (action === "confirm_completion") {
    const alreadyConfirmed = actorRole === "buyer" ?
      buyerConfirmed :
      sellerConfirmed;
    if (status === "completed" && alreadyConfirmed) {
      return {
        actorRole,
        alreadyApplied: true,
        buyerConfirmed,
        sellerConfirmed,
        status,
      };
    }
    if (!paymentStatusAllowsCompletion(
        sale && sale.paymentProviderStatus,
        sale && sale.marketplaceFeeStatus,
        sale,
    )) {
      throw new CommandPolicyError(
          "failed-precondition",
          "Secure payment, including any Pipe Buyer marketplace fee for external " +
          "settlement, is required before completion.",
      );
    }
    if (![
      "pending_completion",
      "awaiting_buyer_confirmation",
      "awaiting_seller_confirmation",
    ].includes(status)) {
      throw new CommandPolicyError(
          "failed-precondition",
          "This transaction cannot be confirmed in its current state.",
      );
    }
    const nextBuyerConfirmed = buyerConfirmed || actorRole === "buyer";
    const nextSellerConfirmed = sellerConfirmed || actorRole === "seller";
    return {
      actorRole,
      alreadyApplied: alreadyConfirmed,
      buyerConfirmed: nextBuyerConfirmed,
      sellerConfirmed: nextSellerConfirmed,
      status: nextBuyerConfirmed && nextSellerConfirmed ?
        "completed" :
        nextBuyerConfirmed ?
          "awaiting_seller_confirmation" :
          "awaiting_buyer_confirmation",
    };
  }
  if (action === "cancel") {
    if (
      status !== "pending_completion" ||
      buyerConfirmed ||
      sellerConfirmed ||
      !paymentStateAllowsCancellation(sale)
    ) {
      throw new CommandPolicyError(
          "failed-precondition",
          "Cancellation is unavailable after payment, external settlement, or " +
          "completion begins. Open a dispute or request refund review instead.",
      );
    }
    const normalizedReason = String(reason || "").trim();
    if (normalizedReason.length < 10 || normalizedReason.length > 1000) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Provide a cancellation reason between 10 and 1,000 characters.",
      );
    }
    return {
      actorRole,
      alreadyApplied: false,
      buyerConfirmed,
      sellerConfirmed,
      status: "cancelled",
      reason: normalizedReason,
    };
  }
  if (action === "dispute") {
    if (["completed", "cancelled", "disputed"].includes(status)) {
      throw new CommandPolicyError(
          "failed-precondition",
          "This transaction cannot be disputed in its current state.",
      );
    }
    const normalizedReason = String(reason || "").trim();
    if (normalizedReason.length < 10 || normalizedReason.length > 2000) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Describe the dispute in 10 to 2,000 characters.",
      );
    }
    return {
      actorRole,
      alreadyApplied: false,
      buyerConfirmed,
      sellerConfirmed,
      status: "disputed",
      reason: normalizedReason,
    };
  }
  throw new CommandPolicyError(
      "invalid-argument",
      "The transaction action is unsupported.",
  );
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
  if (!isMarketplaceSaleListing(listing)) {
    throw new CommandPolicyError(
        "failed-precondition",
        "Only For Sale Marketplace listings accept purchase offers. Timed Buying " +
        "uses bids and Buy It Now.",
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

  const enteredOfferAmount = requireMoney(
      data.offeredUnitPrice,
      "Offer price",
  );
  const saleTerms = requireMarketplaceSaleTerms(listing);
  const requestedQuantity = data && data.requestedQuantity;
  const availableQuantity = saleTerms.quantity;
  if (
    typeof requestedQuantity !== "number" ||
    !Number.isSafeInteger(requestedQuantity) ||
    requestedQuantity <= 0 ||
    requestedQuantity > 1_000_000 ||
    requestedQuantity > availableQuantity
  ) {
    throw new CommandPolicyError(
        "invalid-argument",
        "The requested quantity is unavailable.",
    );
  }
  const priceBasis = saleTerms.priceBasis;
  const totalPriceBasis = saleTerms.priceBasisKind === "total";
  const offeredTotal = totalPriceBasis ?
    enteredOfferAmount :
    requireMoney(
        enteredOfferAmount * requestedQuantity,
        "Offer total",
    );
  const offeredUnitPrice = offeredTotal / requestedQuantity;
  requireFirmPriceMatch(listing, requestedQuantity, offeredTotal);
  const note = String(data.note || "").trim();
  if (note.length > 2000) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Offer conditions must be 2,000 characters or fewer.",
    );
  }
  if (contactSharingSignals(note).length > 0) {
    throw new CommandPolicyError(
        "invalid-argument",
        "Offer notes cannot include phone numbers, email addresses, websites, " +
        "or contact handles. Keep negotiation in secure messages.",
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
    if (contactSharingSignals(dispatchDelivery.accessNotes).length > 0) {
      throw new CommandPolicyError(
          "invalid-argument",
          "Dispatch access notes cannot include contact details.",
      );
    }
  }

  return {
    sellerUid,
    buyerUid,
    enteredOfferAmount,
    offeredUnitPrice,
    offeredTotal,
    priceBasis,
    totalPriceBasis,
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
  auctionListingLifecycleStatus,
  CommandPolicyError,
  TERMINAL_AUCTION_STATUSES,
  isTotalPriceBasis,
  marketplaceOfferInventoryCompletion,
  marketplaceOfferInventoryReservation,
  marketplaceTransactionCurrency,
  minimumAuctionBid,
  paymentStateAllowsCancellation,
  paymentStatusAllowsCompletion,
  requireMarketplaceSaleTerms,
  requireMoney,
  validateAuctionConversion,
  validateAuctionFinalization,
  validateAuctionSaleTerms,
  validateTimedAuctionAdministration,
  validateAuctionTransactionAction,
  validateAcceptBelowReserve,
  validateBuyNow,
  validateLeadingBidRecord,
  validateListingDetailsUpdate,
  validateListingRelist,
  validateListingTransition,
  validateMarketplaceTransactionAction,
  validateOfferAcceptance,
  validateOfferFrequency,
  validateOfferProposal,
  validatePlaceBid,
  validateWithdrawal,
};
