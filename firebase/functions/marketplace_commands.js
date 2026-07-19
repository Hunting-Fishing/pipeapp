"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  CommandPolicyError,
  validateAcceptBelowReserve,
  validateBuyNow,
  validateLeadingBidRecord,
  validateOfferAcceptance,
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

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;

      const listingSnapshot = await transaction.get(listingRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
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

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
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

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
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
          .limit(450);
      const competing = await transaction.get(competingQuery);
      if (competing.size >= 450) {
        throw new CommandPolicyError(
            "resource-exhausted",
            "This listing has too many open offers for automatic acceptance.",
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
    placeAuctionBid,
    withdrawAuctionBid,
  };
}

module.exports = {createMarketplaceCommands};
