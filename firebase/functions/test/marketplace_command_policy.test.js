"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  auctionListingLifecycleStatus,
  CommandPolicyError,
  isTotalPriceBasis,
  marketplaceOfferInventoryCompletion,
  marketplaceOfferInventoryReservation,
  marketplaceTransactionCurrency,
  minimumAuctionBid,
  validateAuctionConversion,
  validateAuctionFinalization,
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
} = require("../marketplace_command_policy");

const now = new Date("2026-07-19T12:00:00.000Z");

test("terminal auction outcomes leave the active scheduler population", () => {
  for (const status of ["won", "bought_now", "accepted_below_reserve"]) {
    assert.equal(auctionListingLifecycleStatus(status), "pending_sale");
  }
  for (const status of ["ended", "cancelled"]) {
    assert.equal(auctionListingLifecycleStatus(status), "archived");
  }
  assert.throws(
      () => auctionListingLifecycleStatus("live"),
      (error) => error instanceof CommandPolicyError && error.code === "internal",
  );
});

function marketplaceListing(overrides = {}) {
  return {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    price: 73,
    priceBasis: "Per piece",
    quantity: 54,
    currency: "USD",
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
    quantity: 1,
    priceBasis: "Per item",
    currency: "USD",
  };
  assert.deepEqual(
      validateAuctionFinalization({
        listing,
        privateAuction: {ownerUid: "seller", reservePrice: 90},
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
        privateAuction: {ownerUid: "seller", reservePrice: 110},
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
  assert.throws(
      () => validateAuctionTransactionAction({
        sale,
        listing,
        actorUid: "buyer",
        action: "confirm_completion",
        paymentProviderStatus: "checkout_created",
      }),
      (error) => error.code === "failed-precondition",
  );
  const buyer = validateAuctionTransactionAction({
    sale,
    listing,
    actorUid: "buyer",
    action: "confirm_completion",
    paymentProviderStatus: "paid",
    marketplaceFeeStatus: "collected",
  });
  assert.equal(buyer.status, "awaiting_seller_confirmation");
  const seller = validateAuctionTransactionAction({
    sale: {...sale, ...buyer},
    listing,
    actorUid: "seller",
    action: "confirm_completion",
    paymentProviderStatus: "paid",
    marketplaceFeeStatus: "collected",
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

test("auction administrator cancellation is blocked after payment begins", () => {
  const listing = {id: "auction", sellerUid: "seller"};
  const sale = {
    listingId: "auction",
    buyerUid: "buyer",
    sellerUid: "seller",
    status: "pending_completion",
    buyerConfirmed: false,
    sellerConfirmed: false,
  };
  const cancellation = validateAuctionTransactionAction({
    sale,
    listing,
    actorUid: "administrator",
    action: "admin_cancel",
    reason: "Administrator verified that both parties withdrew before payment.",
    administrator: true,
  });
  assert.equal(cancellation.status, "cancelled");

  for (const overrides of [
    {
      paymentProviderStatus: "paid",
      paymentState: {paymentProviderStatus: "paid"},
    },
    {
      paymentProviderStatus: "checkout_created",
      paymentState: {
        paymentProviderStatus: "checkout_created",
        stripeCheckoutSessionId: "cs_auction",
      },
    },
    {
      sale: {...sale, buyerConfirmed: true},
    },
  ]) {
    assert.throws(
        () => validateAuctionTransactionAction({
          sale: overrides.sale || sale,
          listing,
          actorUid: "administrator",
          action: "admin_cancel",
          reason: "Administrator attempted cancellation after payment began.",
          administrator: true,
          ...overrides,
        }),
        (error) => error.code === "failed-precondition" &&
          /cancellation is unavailable/u.test(error.message),
    );
  }
});

function liveAuction(overrides = {}) {
  return {
    transactionType: "Auction",
    sellerUid: "seller",
    ownerUid: "seller",
    status: "active",
    auctionStatus: "live",
    auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
    auctionEndAt: new Date("2026-08-31T00:00:00.000Z"),
    startingBid: 100,
    currentBid: 0,
    minimumBidIncrement: 5,
    buyItNowPrice: 200,
    quantity: 1,
    priceBasis: "Per item",
    currency: "USD",
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

test("timed-auction administration extends the authoritative close time", () => {
  const listing = liveAuction({
    auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
    auctionEndAt: new Date("2026-07-20T12:00:00.000Z"),
    currentBid: 145,
    highBidderUid: "buyer",
    bidCount: 4,
  });
  const result = validateTimedAuctionAdministration({
    listing,
    sale: null,
    payment: null,
    action: "extend_24h",
    now,
  });
  assert.equal(
      result.auctionEndAt,
      listing.auctionEndAt.getTime() + 24 * 60 * 60 * 1000,
  );
  assert.equal(listing.currentBid, 145);
  assert.equal(listing.highBidderUid, "buyer");
  assert.equal(listing.bidCount, 4);
});

test("timed-auction administration enforces expiry and duration bounds", () => {
  assert.throws(
      () => validateTimedAuctionAdministration({
        listing: liveAuction({
          auctionStartAt: new Date("2026-07-01T00:00:00.000Z"),
          auctionEndAt: new Date(now.getTime() - 1),
        }),
        action: "extend_24h",
        now,
      }),
      (error) => error.code === "failed-precondition" &&
        /cannot be reopened/u.test(error.message),
  );
  assert.throws(
      () => validateTimedAuctionAdministration({
        listing: liveAuction({
          auctionStartAt: new Date("2025-07-25T12:00:00.000Z"),
          auctionEndAt: new Date("2026-07-20T12:00:00.000Z"),
        }),
        action: "extend_24h",
        now,
      }),
      (error) => error.code === "failed-precondition" &&
        /360-day/u.test(error.message),
  );
});

test("timed-auction administration blocks sale and payment outcomes", () => {
  for (const state of [
    {
      listing: liveAuction({status: "pending_sale", auctionStatus: "won"}),
    },
    {
      listing: liveAuction(),
      sale: {status: "pending_completion", buyerUid: "buyer"},
    },
    {
      listing: liveAuction(),
      payment: {paymentProviderStatus: "paid"},
    },
  ]) {
    assert.throws(
        () => validateTimedAuctionAdministration({
          ...state,
          action: "cancel",
          now,
        }),
        (error) => error.code === "failed-precondition" &&
          /sale or payment outcome/u.test(error.message),
    );
  }
});

test("force end and pre-sale cancellation are server-planned states", () => {
  const listing = liveAuction({currentBid: 145, highBidderUid: "buyer"});
  const forceEnd = validateTimedAuctionAdministration({
    listing,
    action: "force_end",
    now,
  });
  assert.equal(forceEnd.auctionEndAt, now.getTime());
  assert.equal(forceEnd.auctionStatus, "live");

  const cancellation = validateTimedAuctionAdministration({
    listing,
    action: "cancel",
    now,
  });
  assert.equal(cancellation.status, "archived");
  assert.equal(cancellation.auctionStatus, "cancelled");
  assert.equal(listing.currentBid, 145);
  assert.equal(listing.highBidderUid, "buyer");
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
  for (const transactionType of ["For Rent", "Request for Quote"]) {
    assert.throws(
        () => validateAuctionConversion({
          listing: marketplaceListing({transactionType}),
          actorUid: "seller",
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
        (error) => error.code === "failed-precondition" &&
          /Only a For Sale Marketplace listing/u.test(error.message),
    );
  }
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

test("listing edits reject contact details but allow industrial identifiers", () => {
  const base = {...marketplaceListing(), revision: 4};
  for (const patch of [
    {title: "Call 780-555-1212"},
    {description: "Email sales (at) example (dot) com"},
  ]) {
    assert.throws(
        () => validateListingDetailsUpdate({
          listing: base,
          actorUid: "seller",
          data: {expectedRevision: 4, patch},
        }),
        (error) => error.code === "invalid-argument",
    );
  }
  assert.doesNotThrow(() => validateListingDetailsUpdate({
    listing: base,
    actorUid: "seller",
    data: {
      expectedRevision: 4,
      patch: {
        title: "CAT-320-2026 API 5CT pipe",
        description: "5-1/2 pipe, $100,000, inspected 2026-10-16.",
      },
    },
  }));
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
        listing: marketplaceListing(),
        actorUid: "seller",
        action: "mark_sold",
      }),
      (error) => error.code === "failed-precondition" &&
        /accepted offer/u.test(error.message),
  );
  assert.throws(
      () => validateListingTransition({
        listing: marketplaceListing({status: "pending_sale"}),
        actorUid: "seller",
        action: "mark_sold",
      }),
      (error) => error.code === "failed-precondition",
  );
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
  assert.throws(
      () => validatePlaceBid(
          liveAuction({currentBid: 190, minimumBidIncrement: 10}),
          "buyer",
          200,
          now,
      ),
      (error) => error.code === "failed-precondition" &&
        /Buy It Now/u.test(error.message),
  );
  assert.throws(
      () => validateBuyNow(liveAuction({currentBid: 200}), "buyer", now),
      (error) => error.code === "failed-precondition" &&
        /no longer available/u.test(error.message),
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
    currency: "USD",
  };
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    currency: "USD",
    quantity: 1,
    priceBasis: "Per item",
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

test("offer acceptance rechecks listing type, currency, and firm price", () => {
  const listing = marketplaceListing({
    openToOffers: false,
    priceFlexibility: "Firm",
    price: 73,
    quantity: 10,
  });
  const offer = {
    sellerUid: "seller",
    buyerUid: "buyer",
    listingId: "listing",
    status: "pending",
    requestedQuantity: 4,
    offeredTotal: 292,
    currency: "USD",
  };
  assert.doesNotThrow(() => validateOfferAcceptance(offer, "seller", listing));
  assert.throws(
      () => validateOfferAcceptance(
          {...offer, offeredTotal: 291.99},
          "seller",
          listing,
      ),
      (error) => error.code === "failed-precondition" && /firm-price/u.test(error.message),
  );
  assert.throws(
      () => validateOfferAcceptance(
          {...offer, currency: "CAD"},
          "seller",
          listing,
      ),
      (error) => error.code === "failed-precondition" && /currency/u.test(error.message),
  );
  for (const transactionType of [
    "Auction",
    "For Rent",
    "Request for Quote",
    "Wanted / Seeking",
  ]) {
    assert.throws(
        () => validateOfferAcceptance(
            offer,
            "seller",
            {...listing, transactionType},
        ),
        (error) => error.code === "failed-precondition",
    );
  }
});

test("listing offers use authoritative participants and quantity", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 54,
    priceBasis: "Per piece",
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

test("firm listings accept only the authoritative asking price", () => {
  const base = {
    conversation: null,
    actorUid: "buyer",
    now,
  };
  const perUnit = marketplaceListing({
    openToOffers: false,
    priceFlexibility: "Firm",
    price: 73,
    quantity: 54,
  });
  assert.equal(validateOfferProposal({
    ...base,
    listing: perUnit,
    data: {
      listingId: "listing",
      offeredUnitPrice: 73,
      requestedQuantity: 25,
      truckingPlan: "buyer_arranged",
    },
  }).offeredTotal, 1825);
  assert.throws(
      () => validateOfferProposal({
        ...base,
        listing: perUnit,
        data: {
          listingId: "listing",
          offeredUnitPrice: 72.99,
          requestedQuantity: 25,
          truckingPlan: "buyer_arranged",
        },
      }),
      (error) => error.code === "failed-precondition" && /firm-price/u.test(error.message),
  );

  const totalBasis = marketplaceListing({
    openToOffers: false,
    priceFlexibility: "Firm",
    price: 1200,
    priceBasis: "Total for all",
    quantity: 4,
  });
  assert.equal(validateOfferProposal({
    ...base,
    listing: totalBasis,
    data: {
      listingId: "listing",
      offeredUnitPrice: 900,
      requestedQuantity: 3,
      truckingPlan: "buyer_arranged",
    },
  }).offeredTotal, 900);
  assert.throws(
      () => validateOfferProposal({
        ...base,
        listing: totalBasis,
        data: {
          listingId: "listing",
          offeredUnitPrice: 899.99,
          requestedQuantity: 3,
          truckingPlan: "buyer_arranged",
        },
      }),
      (error) => error.code === "failed-precondition",
  );
});

test("non-sale listing models cannot enter the Marketplace offer workflow", () => {
  for (const transactionType of [
    "Auction",
    "For Rent",
    "Request for Quote",
    "Wanted / Seeking",
  ]) {
    assert.throws(
        () => validateOfferProposal({
          listing: marketplaceListing({transactionType}),
          conversation: null,
          actorUid: "buyer",
          data: {
            listingId: "listing",
            offeredUnitPrice: 73,
            requestedQuantity: 1,
            truckingPlan: "buyer_arranged",
          },
          now,
        }),
        (error) => error.code === "failed-precondition",
    );
  }
});

test("new transaction records require an explicit supported currency", () => {
  assert.equal(marketplaceTransactionCurrency("usd"), "USD");
  assert.equal(marketplaceTransactionCurrency("CAD"), "CAD");
  for (const value of [null, "", "EUR", "US"] ) {
    assert.throws(
        () => marketplaceTransactionCurrency(value),
        (error) => error.code === "failed-precondition",
    );
  }
});

test("total-basis offer input is a total and basis comes from listing", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 4,
    priceBasis: "Total for all",
  };
  const proposal = validateOfferProposal({
    listing,
    conversation: null,
    actorUid: "buyer",
    data: {
      listingId: "listing",
      offeredUnitPrice: 900,
      requestedQuantity: 3,
      priceBasis: "Per piece",
      truckingPlan: "buyer_arranged",
    },
    now,
  });
  assert.equal(isTotalPriceBasis("Total asking price"), true);
  assert.equal(isTotalPriceBasis("Total for all"), true);
  assert.equal(isTotalPriceBasis("Per piece"), false);
  assert.equal(proposal.priceBasis, "Total for all");
  assert.equal(proposal.totalPriceBasis, true);
  assert.equal(proposal.enteredOfferAmount, 900);
  assert.equal(proposal.offeredTotal, 900);
  assert.equal(proposal.offeredUnitPrice, 300);
});

test("partial offer inventory is reserved and reopened with the remainder", () => {
  const reservation = marketplaceOfferInventoryReservation(
      {requestedQuantity: 25},
      {quantity: 54, price: 73, priceBasis: "Per piece"},
  );
  assert.deepEqual(reservation, {
    inventoryQuantityAtAcceptance: 54,
    inventoryPriceAtAcceptance: 73,
    inventoryPriceBasisAtAcceptance: "Per piece",
    reservedQuantity: 25,
    remainingQuantityAfterAcceptance: 29,
    partialQuantitySale: true,
  });
  assert.deepEqual(marketplaceOfferInventoryCompletion(
      reservation,
      {quantity: 54, price: 73, priceBasis: "Per piece"},
  ), {
    partialQuantitySale: true,
    remainingQuantity: 29,
    remainingTotalPrice: null,
  });
  assert.throws(
      () => marketplaceOfferInventoryReservation(
          {requestedQuantity: 55},
          {quantity: 54, price: 73, priceBasis: "Per piece"},
      ),
      (error) => error.code === "failed-precondition",
  );
});

test("partial total-basis inventory keeps a truthful remaining lot price", () => {
  const reservation = marketplaceOfferInventoryReservation(
      {requestedQuantity: 3},
      {quantity: 4, price: 1200, priceBasis: "Total for all"},
  );
  assert.deepEqual(marketplaceOfferInventoryCompletion(
      reservation,
      {quantity: 4, price: 1200, priceBasis: "Total for all"},
  ), {
    partialQuantitySale: true,
    remainingQuantity: 1,
    remainingTotalPrice: 300,
  });
  const fullReservation = marketplaceOfferInventoryReservation(
      {requestedQuantity: 4},
      {quantity: 4, price: 1200, priceBasis: "Total for all"},
  );
  assert.deepEqual(marketplaceOfferInventoryCompletion(
      fullReservation,
      {quantity: 4, price: 1200, priceBasis: "Total for all"},
  ), {
    partialQuantitySale: false,
    remainingQuantity: 0,
    remainingTotalPrice: null,
  });
});

test("offer notes and Dispatch access notes reject contact details", () => {
  const listing = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Marketplace",
    quantity: 54,
    priceBasis: "Per piece",
  };
  const base = {
    listing,
    conversation: null,
    actorUid: "buyer",
    now,
  };
  assert.throws(
      () => validateOfferProposal({
        ...base,
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 54,
          note: "Email buyer@example.com",
          truckingPlan: "buyer_arranged",
        },
      }),
      (error) => error.code === "invalid-argument",
  );
  assert.throws(
      () => validateOfferProposal({
        ...base,
        data: {
          listingId: "listing",
          offeredUnitPrice: 70,
          requestedQuantity: 54,
          truckingPlan: "request_dispatch",
          truckingDate: now.getTime() + 7 * 24 * 60 * 60 * 1000,
          dispatchDelivery: {
            label: "Dawson Creek yard",
            latitude: 55.7596,
            longitude: -120.2377,
            accessNotes: "Telegram @yard_contact",
          },
        },
      }),
      (error) => error.code === "invalid-argument",
  );
  assert.doesNotThrow(() => validateOfferProposal({
    ...base,
    data: {
      listingId: "listing",
      offeredUnitPrice: 70,
      requestedQuantity: 54,
      note: "API 5CT, 5-1/2 pipe, inspected 2026-10-16.",
      truckingPlan: "buyer_arranged",
    },
  }));
});

test("marketplace transaction completes only after both parties confirm", () => {
  const offer = {
    id: "offer",
    status: "accepted",
    buyerUid: "buyer",
    sellerUid: "seller",
  };
  assert.throws(
      () => validateMarketplaceTransactionAction({
        sale: {
          offerId: "offer",
          buyerUid: "buyer",
          sellerUid: "seller",
          status: "pending_completion",
          paymentProviderStatus: "checkout_created",
        },
        offer,
        actorUid: "buyer",
        action: "confirm_completion",
      }),
      (error) => error.code === "failed-precondition",
  );
  const buyerResult = validateMarketplaceTransactionAction({
    sale: {
      offerId: "offer",
      buyerUid: "buyer",
      sellerUid: "seller",
      status: "pending_completion",
      buyerConfirmed: false,
      sellerConfirmed: false,
      paymentProviderStatus: "paid",
      marketplaceFeeStatus: "collected",
    },
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
      paymentProviderStatus: "paid",
      marketplaceFeeStatus: "collected",
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
  for (const paymentProviderStatus of [
    "checkout_created",
    "processing",
    "paid",
    "external_agreed",
    "refunded",
    "unknown_provider_state",
  ]) {
    assert.throws(
        () => validateMarketplaceTransactionAction({
          sale: {
            offerId: "offer",
            buyerUid: "buyer",
            sellerUid: "seller",
            status: "pending_completion",
            paymentProviderStatus,
          },
          offer,
          actorUid: "buyer",
          action: "cancel",
          reason: "The parties mutually agreed not to proceed.",
        }),
        (error) => error.code === "failed-precondition" &&
          /dispute or request refund review/u.test(error.message),
    );
  }
  for (const paymentMarker of [
    {stripeCheckoutSessionId: "cs_checkout"},
    {stripePaymentIntentId: "pi_paid"},
    {stripeChargeId: "ch_paid"},
    {externalSettlementBuyerConfirmed: true},
    {externalSettlementSellerConfirmed: true},
  ]) {
    assert.throws(
        () => validateMarketplaceTransactionAction({
          sale: {
            offerId: "offer",
            buyerUid: "buyer",
            sellerUid: "seller",
            status: "pending_completion",
            paymentProviderStatus: "not_started",
            ...paymentMarker,
          },
          offer,
          actorUid: "seller",
          action: "cancel",
          reason: "The parties mutually agreed not to proceed.",
        }),
        (error) => error.code === "failed-precondition",
    );
  }
  const failedCheckoutCancellation = validateMarketplaceTransactionAction({
    sale: {
      offerId: "offer",
      buyerUid: "buyer",
      sellerUid: "seller",
      status: "pending_completion",
      paymentProviderStatus: "failed",
    },
    offer,
    actorUid: "seller",
    action: "cancel",
    reason: "The payment failed before Stripe created a checkout session.",
  });
  assert.equal(failedCheckoutCancellation.status, "cancelled");
  for (const failedCheckoutMarker of [
    {stripeCheckoutSessionId: "cs_failed"},
    {stripeCheckoutAttemptId: "attempt_failed"},
  ]) {
    assert.throws(
        () => validateMarketplaceTransactionAction({
          sale: {
            offerId: "offer",
            buyerUid: "buyer",
            sellerUid: "seller",
            status: "pending_completion",
            paymentProviderStatus: "failed",
            ...failedCheckoutMarker,
          },
          offer,
          actorUid: "seller",
          action: "cancel",
          reason: "A late Stripe result could still settle this checkout.",
        }),
        (error) => error.code === "failed-precondition",
    );
  }
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
      priceBasis: "Per piece",
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
          priceBasis: "Per piece",
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
    priceBasis: "Per piece",
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
