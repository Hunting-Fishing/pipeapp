"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  CommandPolicyError,
  validateAcceptBelowReserve,
  validateBuyNow,
  validateLeadingBidRecord,
  validateOfferAcceptance,
  validateOfferFrequency,
  validateOfferProposal,
  validatePlaceBid,
  validateWithdrawal,
} = require("./marketplace_command_policy");

function requiredId(data, fieldName) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
  }
  return value;
}

function requireAuth(request) {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  return uid;
}

function isAdministrator(request) {
  const token = request.auth && request.auth.token || {};
  return token.admin === true || token.email === "jordilwbailey@gmail.com";
}

function receiptReference(db, uid, command, identity) {
  const digest = crypto.createHash("sha256")
      .update(`${uid}|${command}|${JSON.stringify(identity)}`)
      .digest("hex");
  return db.collection("marketplace_command_receipts").doc(digest);
}

function policyError(error) {
  if (error instanceof HttpsError) return error;
  if (error instanceof CommandPolicyError) {
    return new HttpsError(error.code, error.message);
  }
  console.error("Marketplace command failed", error);
  return new HttpsError(
      "internal",
      "The marketplace action could not be completed.",
  );
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      throw policyError(error);
    }
  };
}

function receiptData(uid, commandName, result, FieldValue) {
  return {
    actorUid: uid,
    command: commandName,
    result,
    createdAt: FieldValue.serverTimestamp(),
  };
}

function routeDistanceKm(origin, destination) {
  if (
    !origin ||
    !Number.isFinite(Number(origin.latitude)) ||
    !Number.isFinite(Number(origin.longitude))
  ) {
    return null;
  }
  const radians = (degrees) => degrees * Math.PI / 180;
  const latitudeDelta = radians(
      Number(destination.latitude) - Number(origin.latitude),
  );
  const longitudeDelta = radians(
      Number(destination.longitude) - Number(origin.longitude),
  );
  const startLatitude = radians(Number(origin.latitude));
  const endLatitude = radians(Number(destination.latitude));
  const haversine =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(startLatitude) *
      Math.cos(endLatitude) *
      Math.sin(longitudeDelta / 2) ** 2;
  const bounded = Math.min(1, Math.max(0, haversine));
  return Math.round(
      6371 * 2 * Math.atan2(Math.sqrt(bounded), Math.sqrt(1 - bounded)) *
      10,
  ) / 10;
}

function createMarketplaceCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  async function requireEligibleBidder(transaction, uid, administrator) {
    if (administrator) return;
    const userSnapshot = await transaction.get(db.collection("users").doc(uid));
    const score = Number(userSnapshot.data() && userSnapshot.data().userScore);
    if (!userSnapshot.exists || !Number.isFinite(score) || score <= 50) {
      throw new CommandPolicyError(
          "permission-denied",
          "More account verification is required before bidding.",
      );
    }
  }

  async function offerDisplayName(
      transaction,
      buyerUid,
      request,
  ) {
    const userSnapshot = await transaction.get(
        db.collection("users").doc(buyerUid),
    );
    const user = userSnapshot.data() || {};
    if (user.accountType === "business") {
      const businessSnapshot = await transaction.get(
          db.collection("public_business_profiles").doc(buyerUid),
      );
      const businessName =
        String(businessSnapshot.data() && businessSnapshot.data().publicName ||
          "").trim();
      if (businessName) return businessName.slice(0, 160);
    }
    const personalName = String(
        user.display_name ||
        user.displayName ||
        (buyerUid === request.auth.uid &&
          request.auth.token &&
          request.auth.token.name) ||
        "",
    ).trim();
    return personalName ? personalName.slice(0, 160) : "Marketplace buyer";
  }

  const placeAuctionBid = command(async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const amount = Number(request.data && request.data.amount);
    const receiptRef = receiptReference(
        db,
        uid,
        "placeAuctionBid",
        {listingId, amount},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateAuctionRef = db.collection("auction_private").doc(listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;

      const listingSnapshot = await transaction.get(listingRef);
      const privateAuctionSnapshot =
        await transaction.get(privateAuctionRef);
      const publicListing =
        listingSnapshot.exists ? listingSnapshot.data() : null;
      const listing = publicListing ? {
        ...publicListing,
        ...(privateAuctionSnapshot.data() || {}),
      } : null;
      const now = Timestamp.now();
      const validated = validatePlaceBid(listing, uid, amount, now);
      await requireEligibleBidder(transaction, uid, isAdministrator(request));

      let previousBidRef = null;
      let previousBidSnapshot = null;
      if (listing.currentBidId) {
        previousBidRef = db.collection("auction_bids")
            .doc(String(listing.currentBidId));
        previousBidSnapshot = await transaction.get(previousBidRef);
      }

      const bidRef = db.collection("auction_bids").doc();
      const result = {
        listingId,
        bidId: bidRef.id,
        amount: validated.amount,
      };
      if (
        previousBidSnapshot &&
        previousBidSnapshot.exists &&
        previousBidSnapshot.data().status === "leading"
      ) {
        transaction.update(previousBidRef, {
          status: "outbid",
          outbidAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.set(bidRef, {
        listingId,
        sellerUid: listing.sellerUid,
        bidderUid: uid,
        amount: validated.amount,
        currency: listing.currency || "CAD",
        status: "leading",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(listingRef, {
        currentBid: validated.amount,
        currentBidId: bidRef.id,
        highBidderUid: uid,
        bidCount: FieldValue.increment(1),
        lastBidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (listing.notifyNewBids !== false) {
        const reserve = Number(listing.reservePrice);
        transaction.set(
            db.collection("users")
                .doc(listing.sellerUid)
                .collection("notifications")
                .doc(receiptRef.id),
            {
              recipientUid: listing.sellerUid,
              actorUid: uid,
              type: "offer",
              listingId,
              title: Number.isFinite(reserve) && validated.amount >= reserve ?
                "Auction reserve reached" :
                "New auction bid",
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.set(
          receiptRef,
          receiptData(uid, "placeAuctionBid", result, FieldValue),
      );
      return result;
    });
  });

  const buyAuctionNow = command(async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const receiptRef = receiptReference(
        db,
        uid,
        "buyAuctionNow",
        {listingId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateAuctionRef = db.collection("auction_private").doc(listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const privateAuctionSnapshot =
        await transaction.get(privateAuctionRef);
      const publicListing =
        listingSnapshot.exists ? listingSnapshot.data() : null;
      const listing = publicListing ? {
        ...publicListing,
        ...(privateAuctionSnapshot.data() || {}),
      } : null;
      const now = Timestamp.now();
      const price = validateBuyNow(listing, uid, now);
      await requireEligibleBidder(transaction, uid, isAdministrator(request));
      let previousBidRef = null;
      let previousBidSnapshot = null;
      if (listing.currentBidId) {
        previousBidRef = db.collection("auction_bids")
            .doc(String(listing.currentBidId));
        previousBidSnapshot = await transaction.get(previousBidRef);
      }
      const bidRef = db.collection("auction_bids").doc();
      const result = {listingId, bidId: bidRef.id, amount: price};

      if (
        previousBidSnapshot &&
        previousBidSnapshot.exists &&
        previousBidSnapshot.data().status === "leading"
      ) {
        transaction.update(previousBidRef, {
          status: "outbid",
          outbidAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.set(bidRef, {
        listingId,
        sellerUid: listing.sellerUid,
        bidderUid: uid,
        amount: price,
        currency: listing.currency || "CAD",
        status: "buy_now",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(listingRef, {
        currentBid: price,
        currentBidId: bidRef.id,
        highBidderUid: uid,
        buyNowBuyerUid: uid,
        acceptedBidAmount: price,
        auctionStatus: "bought_now",
        auctionEndAt: now,
        bidCount: FieldValue.increment(1),
        lastBidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
          db.collection("users")
              .doc(listing.sellerUid)
              .collection("notifications")
              .doc(receiptRef.id),
          {
            recipientUid: listing.sellerUid,
            actorUid: uid,
            type: "offer",
            listingId,
            title: "Auction purchased with Buy It Now",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          receiptRef,
          receiptData(uid, "buyAuctionNow", result, FieldValue),
      );
      return result;
    });
  });

  const acceptAuctionBidBelowReserve = command(async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const receiptRef = receiptReference(
        db,
        uid,
        "acceptAuctionBidBelowReserve",
        {listingId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateAuctionRef = db.collection("auction_private").doc(listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const privateAuctionSnapshot =
        await transaction.get(privateAuctionRef);
      const publicListing =
        listingSnapshot.exists ? listingSnapshot.data() : null;
      const listing = publicListing ? {
        ...publicListing,
        ...(privateAuctionSnapshot.data() || {}),
      } : null;
      const now = Timestamp.now();
      const accepted = validateAcceptBelowReserve(listing, uid, now);
      let bidSnapshot = null;
      if (listing.currentBidId) {
        const bidRef = db.collection("auction_bids")
            .doc(String(listing.currentBidId));
        bidSnapshot = await transaction.get(bidRef);
      } else {
        const legacyBids = await transaction.get(
            db.collection("auction_bids")
                .where("listingId", "==", listingId),
        );
        bidSnapshot = legacyBids.docs.find((candidate) => {
          const data = candidate.data();
          return data.status === "leading" &&
            String(data.bidderUid || "") === accepted.bidderUid &&
            Number(data.amount || 0) === accepted.amount;
        }) || null;
      }
      const bid = bidSnapshot && bidSnapshot.exists ?
        bidSnapshot.data() :
        null;
      validateLeadingBidRecord(listingId, listing, bid);
      const bidRef = bidSnapshot.ref;
      const result = {
        listingId,
        bidderUid: accepted.bidderUid,
        amount: accepted.amount,
      };

      transaction.update(bidRef, {
        status: "accepted",
        acceptedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(listingRef, {
        auctionStatus: "accepted_below_reserve",
        acceptedBidAmount: accepted.amount,
        acceptedBidderUid: accepted.bidderUid,
        auctionEndAt: now,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
          db.collection("users")
              .doc(accepted.bidderUid)
              .collection("notifications")
              .doc(receiptRef.id),
          {
            recipientUid: accepted.bidderUid,
            actorUid: uid,
            type: "offer",
            listingId,
            title: "Your auction bid was accepted",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          receiptRef,
          receiptData(
              uid,
              "acceptAuctionBidBelowReserve",
              result,
              FieldValue,
          ),
      );
      return result;
    });
  });

  const withdrawAuctionBid = command(async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const bidId = requiredId(request.data, "bidId");
    const receiptRef = receiptReference(
        db,
        uid,
        "withdrawAuctionBid",
        {listingId, bidId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const bidRef = db.collection("auction_bids").doc(bidId);
    const bidQuery = db.collection("auction_bids")
        .where("listingId", "==", listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const bidSnapshot = await transaction.get(bidRef);
      const candidates = await transaction.get(bidQuery);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
      const bid = bidSnapshot.exists ? bidSnapshot.data() : null;
      const now = Timestamp.now();
      validateWithdrawal(listingId, listing, bid, uid, now);

      const isLeader = listing.highBidderUid === uid &&
        Number(listing.currentBid || 0) === Number(bid.amount || -1);
      const eligible = candidates.docs
          .filter((candidate) => {
            const data = candidate.data();
            return candidate.id !== bidId &&
              !["withdrawn", "buy_now", "accepted"].includes(data.status);
          })
          .sort((left, right) =>
            Number(right.data().amount || 0) -
            Number(left.data().amount || 0),
          );
      const next = isLeader && eligible.length > 0 ? eligible[0] : null;
      const result = {
        listingId,
        bidId,
        wasLeading: isLeader,
        nextBidId: next ? next.id : null,
      };

      transaction.update(bidRef, {
        status: "withdrawn",
        withdrawnByUid: uid,
        withdrawnAt: FieldValue.serverTimestamp(),
      });
      if (next) {
        transaction.update(next.ref, {
          status: "leading",
          promotedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.update(listingRef, {
        ...(isLeader ? {
          currentBid: next ? Number(next.data().amount || 0) : 0,
          currentBidId: next ? next.id : null,
          highBidderUid: next ? String(next.data().bidderUid || "") : "",
        } : {}),
        withdrawnBidCount: FieldValue.increment(1),
        lastWithdrawalBidId: bidId,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
          receiptRef,
          receiptData(uid, "withdrawAuctionBid", result, FieldValue),
      );
      return result;
    });
  });

  const createMarketplaceOffer = command(async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const conversationId = String(
        request.data && request.data.conversationId || "",
    ).trim();
    if (conversationId) requiredId({conversationId}, "conversationId");
    const receiptRef = receiptReference(
        db,
        uid,
        "createMarketplaceOffer",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const offerRef = db.collection("offers").doc(requestId);
    const conversationRef = conversationId ?
      db.collection("conversations").doc(conversationId) :
      null;

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
      const conversationSnapshot = conversationRef ?
        await transaction.get(conversationRef) :
        null;
      const conversation =
        conversationSnapshot && conversationSnapshot.exists ?
          conversationSnapshot.data() :
          null;
      if (conversationId && !conversation) {
        throw new CommandPolicyError(
            "not-found",
            "This offer conversation is unavailable.",
        );
      }
      const now = Timestamp.now();
      const proposal = validateOfferProposal({
        listing,
        conversation,
        actorUid: uid,
        data: {...request.data, listingId},
        now,
      });
      const buyerDisplayName = await offerDisplayName(
          transaction,
          proposal.buyerUid,
          request,
      );
      const history = await transaction.get(
          db.collection("offers")
              .where("listingId", "==", listingId)
              .limit(450),
      );
      if (history.size >= 450) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This listing has too many offers for another revision.",
        );
      }
      const version = validateOfferFrequency(
          history.docs.map((candidate) => candidate.data()),
          proposal.buyerUid,
          now,
      );
      const askingUnitPriceValue = Number(listing.price);
      const askingUnitPrice =
        Number.isFinite(askingUnitPriceValue) && askingUnitPriceValue > 0 ?
          askingUnitPriceValue :
          null;
      const askingTotal =
        askingUnitPrice == null ?
          0 :
          askingUnitPrice * proposal.requestedQuantity;
      const differenceAmount = proposal.offeredTotal - askingTotal;
      const differencePercent =
        askingTotal === 0 ? null : differenceAmount / askingTotal * 100;
      const recipientUid =
        uid === proposal.sellerUid ? proposal.buyerUid : proposal.sellerUid;
      const result = {
        offerId: offerRef.id,
        listingId,
        conversationId: conversationId || null,
        version,
      };
      const offer = {
        listingId,
        ...(conversationId ? {conversationId} : {}),
        sellerUid: proposal.sellerUid,
        buyerUid: proposal.buyerUid,
        buyerDisplayName,
        proposedByUid: uid,
        askingUnitPrice,
        offeredUnitPrice: proposal.offeredUnitPrice,
        requestedQuantity: proposal.requestedQuantity,
        availableQuantityAtOffer:
          Number.isFinite(Number(listing.quantity)) ?
            Number(listing.quantity) :
            null,
        askingTotal,
        offeredTotal: proposal.offeredTotal,
        differenceAmount,
        differencePercent,
        currency: listing.currency || "CAD",
        priceBasis: listing.priceBasis || "",
        note: proposal.note,
        purchaseDate: proposal.purchaseDate == null ?
          null :
          Timestamp.fromMillis(proposal.purchaseDate),
        moneyTransferDate: proposal.moneyTransferDate == null ?
          null :
          Timestamp.fromMillis(proposal.moneyTransferDate),
        truckingDate: proposal.truckingDate == null ?
          null :
          Timestamp.fromMillis(proposal.truckingDate),
        truckingPlan: proposal.truckingPlan,
        dispatchRequested: proposal.truckingPlan === "request_dispatch",
        ...(proposal.truckingPlan === "request_dispatch" ? {
          dispatchRequestStatus: "accepting_carrier_bids",
          dispatchDeliveryLabel: proposal.dispatchDelivery.label,
          dispatchDelivery: {
            label: proposal.dispatchDelivery.label,
            address: proposal.dispatchDelivery.address,
            nearestTown: proposal.dispatchDelivery.nearestTown,
            region: proposal.dispatchDelivery.region,
            postalCode: proposal.dispatchDelivery.postalCode,
            country: proposal.dispatchDelivery.country,
            point: new admin.firestore.GeoPoint(
                proposal.dispatchDelivery.latitude,
                proposal.dispatchDelivery.longitude,
            ),
            accessNotes: proposal.dispatchDelivery.accessNotes,
            privacy: "offer_participants_and_awarded_carrier",
          },
        } : {}),
        status: "pending",
        version,
        source: conversationId ? "conversation" : "listing",
        createdAt: FieldValue.serverTimestamp(),
      };

      transaction.create(offerRef, offer);
      if (conversationRef) {
        transaction.set(conversationRef, {
          latestNegotiation: {
            unitPrice: proposal.offeredUnitPrice,
            quantity: proposal.requestedQuantity,
            total: proposal.offeredTotal,
            proposedByUid: uid,
            status: "proposed",
            updatedAt: FieldValue.serverTimestamp(),
          },
        }, {merge: true});
      }
      transaction.set(
          db.collection("users")
              .doc(recipientUid)
              .collection("notifications")
              .doc(receiptRef.id),
          {
            recipientUid,
            actorUid: uid,
            type: "offer",
            listingId,
            offerId: offerRef.id,
            ...(conversationId ? {conversationId} : {}),
            title: uid === proposal.sellerUid ?
              "Seller sent a counter-offer" :
              "New offer received",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );

      if (proposal.truckingPlan === "request_dispatch") {
        const delivery = proposal.dispatchDelivery;
        const deliveryPoint = new admin.firestore.GeoPoint(
            delivery.latitude,
            delivery.longitude,
        );
        const distance = routeDistanceKm(
            listing.publicGeoPoint,
            delivery,
        );
        const dispatchRef = db.collection("dispatch_jobs").doc(offerRef.id);
        const jobValues = {
          createdByUid: uid,
          title: String(listing.title || "Offer trucking request").slice(0, 180),
          listingId,
          offerId: offerRef.id,
          pickupLabel: String(
              listing.publicLocationName ||
              listing.nearestTown ||
              "Pickup location to confirm",
          ).slice(0, 250),
          deliveryLabel: delivery.label,
          ...(listing.publicGeoPoint ? {
            pickupPoint: listing.publicGeoPoint,
          } : {}),
          deliveryPoint,
          deliveryAddress: delivery.address,
          deliveryTown: delivery.nearestTown,
          deliveryRegion: delivery.region,
          deliveryPostalCode: delivery.postalCode,
          deliveryCountry: delivery.country,
          deliveryAccessNotes: delivery.accessNotes,
          ...(distance == null ? {} : {
            distanceKm: distance,
            distanceSource: "coordinate_estimate",
          }),
          loadDetails:
            `${String(listing.title || "Marketplace load").slice(0, 180)} • ` +
            `${proposal.requestedQuantity} units`,
          truckingDate: Timestamp.fromMillis(proposal.truckingDate),
          status: "open",
          bidCount: 0,
          revision: 1,
          source: "offer",
          sourceType: "offer",
          activationTrigger: "user_requested",
          dispatchRequestStatus: "accepting_carrier_bids",
          publishedAt: FieldValue.serverTimestamp(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        transaction.create(dispatchRef, jobValues);
        transaction.create(dispatchRef.collection("revisions").doc("1"), {
          ...jobValues,
          event: "request_created",
          actorUid: uid,
        });
      }
      transaction.set(
          receiptRef,
          receiptData(uid, "createMarketplaceOffer", result, FieldValue),
      );
      return result;
    });
  });

  const acceptMarketplaceOffer = command(async (request) => {
    const uid = requireAuth(request);
    const offerId = requiredId(request.data, "offerId");
    const receiptRef = receiptReference(
        db,
        uid,
        "acceptMarketplaceOffer",
        {offerId},
    );
    const offerRef = db.collection("offers").doc(offerId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const offerSnapshot = await transaction.get(offerRef);
      const offer = offerSnapshot.exists ? offerSnapshot.data() : null;
      if (
        offer &&
        offer.status === "accepted" &&
        offer.acceptedByUid === uid
      ) {
        const result = {
          offerId,
          listingId: String(offer.listingId || ""),
          buyerUid: String(offer.buyerUid || ""),
        };
        transaction.set(
            receiptRef,
            receiptData(uid, "acceptMarketplaceOffer", result, FieldValue),
        );
        return result;
      }
      const listingRef = db.collection("public_listings")
          .doc(String(offer && offer.listingId || "missing"));
      const listingSnapshot = await transaction.get(listingRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
      validateOfferAcceptance(offer, uid, listing);
      const competingQuery = db.collection("offers")
          .where("listingId", "==", offer.listingId)
          .limit(300);
      const competing = await transaction.get(competingQuery);
      const dispatchJobs = await transaction.get(
          db.collection("dispatch_jobs")
              .where("listingId", "==", offer.listingId)
              .limit(95),
      );
      if (competing.size >= 300) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This listing has too many open offers for automatic acceptance.",
        );
      }
      if (dispatchJobs.size >= 95) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This listing has too many Dispatch requests for automatic archival.",
        );
      }
      const result = {
        offerId,
        listingId: offer.listingId,
        buyerUid: offer.buyerUid,
      };

      transaction.update(offerRef, {
        status: "accepted",
        acceptedByUid: uid,
        acceptedAt: FieldValue.serverTimestamp(),
        ...(offer.dispatchRequested === true ? {
          dispatchRequestStatus: "accepting_carrier_bids",
        } : {}),
      });
      transaction.update(listingRef, {
        status: "pending_sale",
        acceptedOfferId: offerId,
        acceptedBuyerUid: offer.buyerUid,
        offerAcceptedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      for (const candidate of competing.docs) {
        if (
          candidate.id === offerId ||
          candidate.data().status !== "pending"
        ) {
          continue;
        }
        transaction.update(candidate.ref, {
          status: "archived",
          archivedReason: "another_offer_accepted",
          acceptedOfferId: offerId,
          archivedAt: FieldValue.serverTimestamp(),
        });
      }
      for (const dispatchJob of dispatchJobs.docs) {
        const job = dispatchJob.data();
        if (
          job.offerId === offerId ||
          job.sourceType !== "offer" ||
          !["draft", "open"].includes(job.status)
        ) {
          continue;
        }
        const revision = Number(job.revision || 1) + 1;
        transaction.update(dispatchJob.ref, {
          status: "archived",
          archivedReason: "another_offer_accepted",
          acceptedOfferId: offerId,
          revision,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(
            dispatchJob.ref.collection("revisions").doc(String(revision)),
            {
              ...job,
              status: "archived",
              archivedReason: "another_offer_accepted",
              acceptedOfferId: offerId,
              revision,
              event: "request_archived",
              actorUid: uid,
              updatedAt: FieldValue.serverTimestamp(),
            },
        );
      }
      transaction.set(
          db.collection("users")
              .doc(offer.buyerUid)
              .collection("notifications")
              .doc(receiptRef.id),
          {
            recipientUid: offer.buyerUid,
            actorUid: uid,
            type: "offer",
            offerId,
            listingId: offer.listingId,
            conversationId: offer.conversationId || null,
            title: offer.dispatchRequested === true ?
              "Offer accepted — trucking request remains live" :
              "Your offer was accepted",
            ...(offer.dispatchRequested === true ? {
              body: "Open Dispatch → Jobs to review carrier quotes.",
            } : {}),
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.set(
          receiptRef,
          receiptData(uid, "acceptMarketplaceOffer", result, FieldValue),
      );
      return result;
    });
  });

  return {
    acceptAuctionBidBelowReserve,
    acceptMarketplaceOffer,
    buyAuctionNow,
    createMarketplaceOffer,
    placeAuctionBid,
    withdrawAuctionBid,
  };
}

module.exports = {createMarketplaceCommands};
