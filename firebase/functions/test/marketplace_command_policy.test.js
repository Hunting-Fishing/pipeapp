"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildOfferNotification,
  CommandPolicyError,
  minimumAuctionBid,
  validateAuctionConversion,
  validateAuctionFinalization,
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
} = require("../marketplace_command_policy");

const now = new Date("2026-07-19T12:00:00.000Z");

function marketplaceListing(overrides = {}) {
  return {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    price: 73,
    priceBasis: "Per piece",
    quantity: 54,
    ...overrides,
  };
}

function verifiedSeller(overrides = {}) {
  return {
    userScore: 90,
    profileCompletion: 100,
    accountVerified: true,
    accountVerificationReviewVersion: 1,
    ...overrides,
  };
}

test("expired auctions finalize to a winner only when reserve is met", () => {
  const listing = {
    id: "auction",
    sellerUid: "seller",
    status: "active",
    transactionType: "Auction",
    auctionStatus: "live",
    auctionEndAt: new Date(now.getTime() - 1000),
    currentBid: 100,
    highBidderUid: "buyer",
  };
  assert.deepEqual(
      validateAuctionFinalization({
        listing,
        privateAuction: {reservePrice: 90},
        now,
      }),
      {
        amount: 100,
        auctionStatus: "won",
        reserveMet: true,
        winnerUid: "buyer",
      },
  );
  assert.equal(
      validateAuctionFinalization({
        listing,
        privateAuction: {reservePrice: 110},
        now,
      }).auctionStatus,
      "ended",
  );
});

test("auction settlements require both confirmations and control defaults", () => {
  const listing = {id: "auction", sellerUid: "seller"};
  const sale = {
    listingId: "auction",
    buyerUid: "buyer",
    sellerUid: "seller",
    status: "pending_completion",
    buyerConfirmed: false,
    sellerConfirmed: false,
  };
  const buyer = validateAuctionTransactionAction({
    sale,
    listing,
    actorUid: "buyer",
    action: "confirm_completion",
  });
  assert.equal(buyer.status, "awaiting_seller_confirmation");
  const seller = validateAuctionTransactionAction({
    sale: {...sale, ...buyer},
    listing,
    actorUid: "seller",
    action: "confirm_completion",
  });
  assert.equal(seller.status, "completed");
  assert.equal(seller.buyerConfirmed, true);
  assert.equal(seller.sellerConfirmed, true);
  assert.equal(
      validateAuctionTransactionAction({
        sale,
        listing,
        actorUid: "seller",
        action: "report_buyer_default",
        reason: "Winning bidder did not complete the agreed purchase.",
      }).status,
      "buyer_default_reported",
  );
  assert.throws(
      () => validateAuctionTransactionAction({
        sale,
        listing,
        actorUid: "buyer",
        action: "report_buyer_default",
        reason: "Trying to report the wrong participant as in default.",
      }),
      (error) => error.code === "permission-denied",
  );
});

function liveAuction(overrides = {}) {
  return {
    transactionType: "Auction",
    sellerUid: "seller",
    status: "active",
    auctionStatus: "live",
    auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
    auctionEndAt: new Date("2026-08-31T00:00:00.000Z"),
    startingBid: 100,
    currentBid: 0,
    minimumBidIncrement: 5,
    buyItNowPrice: 200,
    ...overrides,
  };
}

test("minimum bid follows starting price then current plus increment", () => {
  assert.equal(minimumAuctionBid(liveAuction()), 100);
  assert.equal(
      minimumAuctionBid(liveAuction({currentBid: 125})),
      130,
  );
});

test("marketplace conversion derives authoritative auction analytics", () => {
  const conversion = validateAuctionConversion({
    listing: marketplaceListing(),
    actorUid: "seller",
    user: verifiedSeller(),
    administrator: false,
    data: {
      startingBid: 73,
      minimumBidIncrement: 0.5,
      reservePrice: 80,
      buyItNowPrice: 100,
      durationDays: 30,
      customAuction: false,
    },
    paidFeaturesEnabled: false,
    now,
  });
  assert.equal(conversion.askingTotal, 3942);
  assert.equal(conversion.quantity, 54);
  assert.equal(conversion.priceBasis, "Per piece");
  assert.equal(
      conversion.auctionEndAt - conversion.auctionStartAt,
      30 * 24 * 60 * 60 * 1000,
  );
});

test("marketplace conversion enforces ownership and seller eligibility", () => {
  assert.throws(
      () => validateAuctionConversion({
        listing: marketplaceListing(),
        actorUid: "buyer",
        user: verifiedSeller(),
        administrator: false,
        data: {
          startingBid: 73,
          minimumBidIncrement: 1,
          durationDays: 7,
        },
        paidFeaturesEnabled: false,
        now,
      }),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateAuctionConversion({
        listing: marketplaceListing(),
        actorUid: "seller",
        user: verifiedSeller({profileCompletion: 80}),
        administrator: false,
        data: {
          startingBid: 73,
          minimumBidIncrement: 1,
          durationDays: 7,
        },
        paidFeaturesEnabled: false,
        now,
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("custom auctions remain disabled until paid features are live", () => {
  const request = {
    listing: marketplaceListing(),
    actorUid: "seller",
    user: verifiedSeller(),
    administrator: false,
    data: {
      startingBid: 73,
      minimumBidIncrement: 1,
      durationDays: 45,
      customAuction: true,
    },
    now,
  };
  assert.throws(
      () => validateAuctionConversion({
        ...request,
        paidFeaturesEnabled: false,
      }),
      (error) => error.code === "failed-precondition",
  );
  assert.equal(
      validateAuctionConversion({
        ...request,
        paidFeaturesEnabled: true,
      }).durationDays,
      45,
  );
});

test("auction conversion rejects unsafe money and duration combinations", () => {
  const base = {
    listing: marketplaceListing(),
    actorUid: "seller",
    user: verifiedSeller(),
    administrator: false,
    paidFeaturesEnabled: false,
    now,
  };
  for (const data of [
    {startingBid: 73, minimumBidIncrement: 0.49, durationDays: 7},
    {startingBid: 73, minimumBidIncrement: 1, durationDays: 2},
    {
      startingBid: 73,
      minimumBidIncrement: 1,
      reservePrice: 70,
      durationDays: 7,
    },
    {
      startingBid: 73,
      minimumBidIncrement: 1,
      reservePrice: 90,
      buyItNowPrice: 80,
      durationDays: 7,
    },
  ]) {
    assert.throws(
        () => validateAuctionConversion({...base, data}),
        (error) => error.code === "invalid-argument",
    );
  }
});

test("listing edits are owner-only, revision-safe, and field-bounded", () => {
  const update = validateListingDetailsUpdate({
    listing: {...marketplaceListing(), revision: 4},
    actorUid: "seller",
    data: {
      expectedRevision: 4,
      patch: {title: "Updated pipe", price: 75, quantity: 50},
    },
  });
  assert.deepEqual(update.changes, {
    title: "Updated pipe",
    price: 75,
    quantity: 50,
  });
  assert.equal(update.nextRevision, 5);
  assert.throws(
      () => validateListingDetailsUpdate({
        listing: {...marketplaceListing(), revision: 4},
        actorUid: "seller",
        data: {expectedRevision: 3, patch: {title: "Stale"}},
      }),
      (error) => error.code === "aborted",
  );
  assert.throws(
      () => validateListingDetailsUpdate({
        listing: marketplaceListing(),
        actorUid: "seller",
        data: {expectedRevision: 1, patch: {sellerUid: "forged"}},
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("normal listing transitions enforce a finite lifecycle", () => {
  assert.equal(validateListingTransition({
    listing: marketplaceListing(),
    actorUid: "seller",
    action: "pause",
  }).status, "paused");
  assert.equal(validateListingTransition({
    listing: marketplaceListing({status: "paused"}),
    actorUid: "seller",
    action: "activate",
  }).status, "active");
  assert.throws(
      () => validateListingTransition({
        listing: marketplaceListing({status: "sold"}),
        actorUid: "seller",
        action: "activate",
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("wanted requests use fulfilled rather than sold lifecycle state", () => {
  const wanted = marketplaceListing({
    transactionType: "Wanted / Seeking",
    wantedStatus: "open",
  });
  assert.equal(validateListingTransition({
    listing: wanted,
    actorUid: "seller",
    action: "mark_fulfilled",
  }).status, "fulfilled");
  assert.throws(
      () => validateListingTransition({
        listing: wanted,
        actorUid: "seller",
        action: "mark_sold",
      }),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => validateListingTransition({
        listing: marketplaceListing(),
        actorUid: "seller",
        action: "mark_fulfilled",
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("relisting preserves history by requiring a new listing identifier", () => {
  assert.deepEqual(validateListingRelist({
    listing: {...marketplaceListing({status: "archived"}), id: "old"},
    actorUid: "seller",
    newListingId: "new",
  }), {newListingId: "new"});
  assert.throws(
      () => validateListingRelist({
        listing: {...marketplaceListing({status: "sold"}), id: "old"},
        actorUid: "seller",
        newListingId: "old",
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("bid must meet the server-calculated minimum", () => {
  assert.throws(
      () => validatePlaceBid(liveAuction(), "buyer", 99, now),
      (error) =>
        error instanceof CommandPolicyError &&
        error.code === "failed-precondition",
  );
  assert.deepEqual(
      validatePlaceBid(liveAuction(), "buyer", 100, now),
      {amount: 100, minimum: 100},
  );
});

test("money commands reject fractions smaller than a cent", () => {
  assert.throws(
      () => validatePlaceBid(liveAuction(), "buyer", 100.001, now),
      (error) =>
        error instanceof CommandPolicyError &&
        error.code === "invalid-argument",
  );
  assert.throws(
      () => validatePlaceBid(
          liveAuction({minimumBidIncrement: -5}),
          "buyer",
          100,
          now,
      ),
      (error) =>
        error instanceof CommandPolicyError &&
        error.code === "invalid-argument",
  );
});

test("seller cannot bid or use Buy It Now on their auction", () => {
  assert.throws(
      () => validatePlaceBid(liveAuction(), "seller", 100, now),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateBuyNow(liveAuction(), "seller", now),
      (error) => error.code === "permission-denied",
  );
});

test("seller may accept only a real leading bid below reserve", () => {
  const accepted = validateAcceptBelowReserve(
      liveAuction({
        currentBid: 150,
        reservePrice: 175,
        highBidderUid: "buyer",
      }),
      "seller",
      now,
  );
  assert.deepEqual(accepted, {amount: 150, bidderUid: "buyer"});
  assert.throws(
      () => validateAcceptBelowReserve(
          liveAuction({
            currentBid: 175,
            reservePrice: 175,
            highBidderUid: "buyer",
          }),
          "seller",
          now,
      ),
      (error) => error.code === "failed-precondition",
  );
});

test("custom auction withdrawal starts only after day 32", () => {
  const bid = {
    listingId: "auction-1",
    bidderUid: "buyer",
    status: "leading",
  };
  assert.throws(
      () => validateWithdrawal(
          "auction-1",
          liveAuction({
            customAuction: true,
            auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
          }),
          bid,
          "buyer",
          now,
      ),
      (error) => error.code === "failed-precondition",
  );
  assert.doesNotThrow(
      () => validateWithdrawal(
          "auction-1",
          liveAuction({
            customAuction: true,
            auctionStartAt: new Date("2026-06-01T00:00:00.000Z"),
          }),
          bid,
          "buyer",
          now,
      ),
  );
});

test("bid records must belong to the auction they change", () => {
  const listing = liveAuction({
    currentBid: 100,
    highBidderUid: "buyer",
  });
  assert.throws(
      () => validateLeadingBidRecord(
          "auction-1",
          listing,
          {
            listingId: "auction-2",
            bidderUid: "buyer",
            amount: 100,
            status: "leading",
          },
      ),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => validateWithdrawal(
          "auction-1",
          liveAuction({
            customAuction: true,
            auctionStartAt: new Date("2026-06-01T00:00:00.000Z"),
          }),
          {
            listingId: "auction-2",
            bidderUid: "buyer",
            status: "leading",
          },
          "buyer",
          now,
      ),
      (error) => error.code === "permission-denied",
  );
});

test("only the seller can accept a pending complete offer", () => {
  const offer = {
    sellerUid: "seller",
    buyerUid: "buyer",
    listingId: "listing",
    status: "pending",
  };
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
  };
  assert.doesNotThrow(
      () => validateOfferAcceptance(offer, "seller", listing),
  );
  assert.throws(
      () => validateOfferAcceptance(offer, "buyer", listing),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateOfferAcceptance(
          {...offer, status: "archived"},
          "seller",
          listing,
      ),
      (error) => error.code === "failed-precondition",
  );
  assert.throws(
      () => validateOfferAcceptance(
          offer,
          "seller",
          {...listing, transactionType: "Auction"},
      ),
      (error) => error.code === "failed-precondition",
  );
});

test("listing offers use authoritative participants and quantity", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 54,
  };
  const proposal = validateOfferProposal({
    listing,
    conversation: null,
    actorUid: "buyer",
    data: {
      listingId: "listing",
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      truckingPlan: "buyer_arranged",
    },
    now,
  });
  assert.equal(proposal.sellerUid, "seller");
  assert.equal(proposal.buyerUid, "buyer");
  assert.equal(proposal.offeredTotal, 3780);
  assert.throws(
      () => validateOfferProposal({
        listing,
        conversation: null,
        actorUid: "seller",
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 54,
          truckingPlan: "buyer_arranged",
        },
        now,
      }),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateOfferProposal({
        listing,
        conversation: null,
        actorUid: "buyer",
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 55,
          truckingPlan: "buyer_arranged",
        },
        now,
      }),
      (error) => error.code === "invalid-argument",
  );
});

test("offer creation builds an unread seller notification with safe push copy", () => {
  const notification = buildOfferNotification({
    actorUid: "buyer",
    listingId: "listing",
    offerId: "offer-1",
    proposal: {sellerUid: "seller", buyerUid: "buyer"},
  });
  assert.deepEqual(notification, {
    recipientUid: "seller",
    actorUid: "buyer",
    type: "offer",
    listingId: "listing",
    offerId: "offer-1",
    title: "New offer received",
    body: "Compare price, payment, pickup, and trucking before accepting.",
    pushTitle: "New offer received",
    pushBody: "Tap to compare price, payment, pickup, and trucking.",
    read: false,
  });
});

test("seller counter-offers notify the buyer instead of the seller", () => {
  const notification = buildOfferNotification({
    actorUid: "seller",
    listingId: "listing",
    offerId: "offer-2",
    conversationId: "conversation-1",
    proposal: {sellerUid: "seller", buyerUid: "buyer"},
  });
  assert.equal(notification.recipientUid, "buyer");
  assert.equal(notification.title, "Seller sent a counter-offer");
  assert.equal(notification.pushTitle, "Counter-offer received");
  assert.equal(notification.conversationId, "conversation-1");
});

test("marketplace transaction completes only after both parties confirm", () => {
  const offer = {
    id: "offer",
    status: "accepted",
    buyerUid: "buyer",
    sellerUid: "seller",
  };
  const buyerResult = validateMarketplaceTransactionAction({
    sale: null,
    offer,
    actorUid: "buyer",
    action: "confirm_completion",
  });
  assert.equal(buyerResult.status, "awaiting_seller_confirmation");
  assert.equal(buyerResult.buyerConfirmed, true);
  assert.equal(buyerResult.sellerConfirmed, false);
  const sellerResult = validateMarketplaceTransactionAction({
    sale: {
      offerId: "offer",
      buyerUid: "buyer",
      sellerUid: "seller",
      status: buyerResult.status,
      buyerConfirmed: true,
      sellerConfirmed: false,
    },
    offer,
    actorUid: "seller",
    action: "confirm_completion",
  });
  assert.equal(sellerResult.status, "completed");
  assert.equal(sellerResult.buyerConfirmed, true);
  assert.equal(sellerResult.sellerConfirmed, true);
});

test("transaction cancellation and disputes are participant controlled", () => {
  const offer = {
    id: "offer",
    status: "accepted",
    buyerUid: "buyer",
    sellerUid: "seller",
  };
  const cancelled = validateMarketplaceTransactionAction({
    sale: null,
    offer,
    actorUid: "buyer",
    action: "cancel",
    reason: "The parties mutually agreed not to proceed.",
  });
  assert.equal(cancelled.status, "cancelled");
  const disputed = validateMarketplaceTransactionAction({
    sale: {
      offerId: "offer",
      buyerUid: "buyer",
      sellerUid: "seller",
      status: "awaiting_buyer_confirmation",
      sellerConfirmed: true,
    },
    offer,
    actorUid: "buyer",
    action: "dispute",
    reason: "The delivered quantity does not match the agreement.",
  });
  assert.equal(disputed.status, "disputed");
  assert.throws(
      () => validateMarketplaceTransactionAction({
        sale: null,
        offer,
        actorUid: "stranger",
        action: "confirm_completion",
      }),
      (error) => error.code === "permission-denied",
  );
  assert.throws(
      () => validateMarketplaceTransactionAction({
        sale: {
          offerId: "offer",
          buyerUid: "buyer",
          sellerUid: "seller",
          status: "awaiting_seller_confirmation",
          buyerConfirmed: true,
        },
        offer,
        actorUid: "seller",
        action: "cancel",
        reason: "Attempting a late cancellation.",
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("seller counter-offers require the real listing conversation", () => {
  const proposal = validateOfferProposal({
    listing: {
      sellerUid: "seller",
      status: "active",
      transactionType: "Marketplace",
      quantity: 54,
    },
    conversation: {
      listingId: "listing",
      sellerUid: "seller",
      memberUids: ["seller", "buyer"],
    },
    actorUid: "seller",
    data: {
      listingId: "listing",
      offeredUnitPrice: 73,
      requestedQuantity: 54,
      truckingPlan: "seller_pickup",
    },
    now,
  });
  assert.equal(proposal.buyerUid, "buyer");
  assert.equal(proposal.sellerUid, "seller");
  assert.throws(
      () => validateOfferProposal({
        listing: {
          sellerUid: "seller",
          status: "active",
          transactionType: "Marketplace",
          quantity: 54,
        },
        conversation: {
          listingId: "listing",
          sellerUid: "seller",
          memberUids: ["seller", "buyer", "unrelated-user"],
        },
        actorUid: "seller",
        data: {
          listingId: "listing",
          offeredUnitPrice: 73,
          requestedQuantity: 54,
          truckingPlan: "seller_pickup",
        },
        now,
      }),
      (error) => error.code === "permission-denied",
  );
});

test("Dispatch offers require a dated mapped destination", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 54,
  };
  assert.throws(
      () => validateOfferProposal({
        listing,
        conversation: null,
        actorUid: "buyer",
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 54,
          truckingPlan: "request_dispatch",
        },
        now,
      }),
      (error) => error.code === "invalid-argument",
  );
  const proposal = validateOfferProposal({
    listing,
    conversation: null,
    actorUid: "buyer",
    data: {
      listingId: "listing",
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      truckingPlan: "request_dispatch",
      truckingDate: now.getTime() + 7 * 24 * 60 * 60 * 1000,
      dispatchDelivery: {
        label: "Dawson Creek yard",
        nearestTown: "Dawson Creek",
        latitude: 55.7596,
        longitude: -120.2377,
      },
    },
    now,
  });
  assert.equal(proposal.dispatchDelivery.nearestTown, "Dawson Creek");
});

test("offer revisions are rate limited per buyer and listing", () => {
  assert.equal(validateOfferFrequency([], "buyer", now), 1);
  assert.throws(
      () => validateOfferFrequency(
          [{
            buyerUid: "buyer",
            createdAt: new Date(now.getTime() - 1000),
          }],
          "buyer",
          now,
      ),
      (error) => error.code === "resource-exhausted",
  );
});
