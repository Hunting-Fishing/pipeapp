"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {isAdministrator} = require("./administrator_authorization");
const {
  CommandPolicyError,
  TERMINAL_AUCTION_STATUSES,
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
} = require("./marketplace_command_policy");
const {
  ListingPolicyError,
  buildMarketplaceSearchTokens,
  listingMediaObjectPath,
  searchIndexVersion,
  validateLocation,
  validateListingMediaManifest,
  validateMarketplaceListingInput,
  validateReserve,
} = require("./marketplace_listing_policy");
const {
  approvedAccountVerification,
} = require("./account_verification_policy");
const {
  FeatureFlagError,
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {buildDispatchRouteState} = require("./dispatch_routing_policy");
const {
  DAY_MS,
  MARKETPLACE_LISTING_ACTIVE_DAYS,
} = require("./marketplace_listing_lifecycle");
const {
  WantedMatchingPolicyError,
  validateWantedMatchAction,
} = require("./wanted_matching_policy");

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

function requireAuth(request, options) {
  return requireAuthenticatedIdentity(request, options).uid;
}

function receiptReference(db, uid, command, identity) {
  const digest = crypto.createHash("sha256")
      .update(`${uid}|${command}|${JSON.stringify(identity)}`)
      .digest("hex");
  return db.collection("marketplace_command_receipts").doc(digest);
}

function policyError(error) {
  if (error instanceof HttpsError) return error;
  if (
    error instanceof AccountSecurityError ||
    error instanceof CommandPolicyError ||
    error instanceof ListingPolicyError ||
    error instanceof WantedMatchingPolicyError ||
    error instanceof FeatureFlagError
  ) {
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
  const featureCommand = (feature, handler) => command(async (request) => {
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, feature);
    await enforceUserRateLimit({db, admin, request, scope: feature});
    return handler(request, flags);
  });

  async function loadListingPublisher(transaction, uid, request, listing) {
    const userSnapshot = await transaction.get(
        db.collection("users").doc(uid),
    );
    const businessSnapshot = await transaction.get(
        db.collection("public_business_profiles").doc(uid),
    );
    const user = userSnapshot.data() || {};
    const business = businessSnapshot.data() || {};
    if (listing.transactionType === "Auction" &&
        !isAdministrator(request) &&
        (
          Number(user.userScore || 70) <= 80 ||
          Number(user.profileCompletion || 0) !== 100 ||
          !approvedAccountVerification(user)
        )) {
      throw new HttpsError(
          "failed-precondition",
          "Auction listings require a User Score above 80, a complete " +
          "profile, and verified account status.",
      );
    }
    const sellerName = String(
        user.accountType === "business" ?
          business.publicName || user.businessName || "" :
          user.display_name || user.displayName || user.fullName || "",
    ).trim() || String(
        request.auth.token.name || request.auth.token.email ||
        "Marketplace seller",
    ).trim();
    const sellerPhotoUrl = String(
        business.photoUrl || user.photoUrl || user.photo_url ||
        request.auth.token.picture || "",
    ).trim();
    return {
      sellerName: sellerName.slice(0, 160),
      sellerPhotoUrl: sellerPhotoUrl.slice(0, 2000),
      sellerVerified: approvedAccountVerification(user),
    };
  }

  function publicationValues(uid, listing, location, publisher) {
    const exactPoint = new admin.firestore.GeoPoint(
        location.point.latitude,
        location.point.longitude,
    );
    const publicPoint = location.visibility === "hidden" ?
      null :
      location.visibility === "exact" ?
        exactPoint :
        new admin.firestore.GeoPoint(
            Math.round(location.point.latitude * 20) / 20,
            Math.round(location.point.longitude * 20) / 20,
        );
    const searchableListing = {
      ...listing,
      publicLocationName: location.publicName,
      nearestTown: location.nearestTown,
      region: location.region,
      country: location.country,
    };
    return {
      publicListing: {
        ...listing,
        searchTokens: buildMarketplaceSearchTokens(searchableListing),
        searchIndexVersion,
        ...(listing.auctionStartAt ? {
          auctionStartAt: Timestamp.fromMillis(listing.auctionStartAt),
        } : {}),
        ...(listing.auctionEndAt ? {
          auctionEndAt: Timestamp.fromMillis(listing.auctionEndAt),
        } : {}),
        locationVisibility: location.visibility,
        publicLocationName: location.publicName,
        nearestTown: location.nearestTown,
        region: location.region,
        country: location.country,
        approximateRadiusKm: location.visibility === "exact" ? 0 : 10,
        ...(publicPoint ? {publicGeoPoint: publicPoint} : {}),
        sellerUid: uid,
        ...publisher,
        ...(typeof listing.price === "number" ? {
          initialPrice: listing.price,
        } : {}),
        publishedAt: Timestamp.now(),
        expiresAt: Timestamp.fromMillis(
          Date.now() + MARKETPLACE_LISTING_ACTIVE_DAYS * DAY_MS,
        ),
        listingDurationDays: MARKETPLACE_LISTING_ACTIVE_DAYS,
        renewalCount: 0,
        lifecycleVersion: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        source: "marketplace_callable",
        status: "active",
      },
      privateLocation: {
        ownerUid: uid,
        exactGeoPoint: exactPoint,
        fullAddress: location.address,
        nearestTown: location.nearestTown,
        region: location.region,
        postalCode: location.postalCode,
        country: location.country,
        accessNotes: location.accessNotes,
        visibility: location.visibility,
        publicName: location.publicName,
        updatedAt: FieldValue.serverTimestamp(),
      },
    };
  }

  async function verifyDraftMediaObjects(media) {
    const bucket = admin.storage().bucket();
    const imagePaths = media.imageUrls.map(listingMediaObjectPath);
    const videoPaths = media.videoUrl ?
      [listingMediaObjectPath(media.videoUrl)] : [];
    try {
      const trustedImageHashes = await Promise.all(
          imagePaths.map(async (path) => {
          const file = bucket.file(path);
          const [metadata] = await file.getMetadata();
          if (!String(metadata.contentType || "").startsWith("image/") ||
              Number(metadata.size || 0) <= 0 ||
              Number(metadata.size || 0) > 5 * 1024 * 1024) {
            throw new Error("invalid-photo");
          }
          const digest = crypto.createHash("sha256");
          await new Promise((resolve, reject) => {
            file.createReadStream()
                .on("data", (chunk) => digest.update(chunk))
                .on("error", reject)
                .on("end", resolve);
          });
          return digest.digest("hex");
          }),
      );
      await Promise.all(videoPaths.map(async (path) => {
          const [metadata] = await bucket.file(path).getMetadata();
          if (!String(metadata.contentType || "").startsWith("video/") ||
              Number(metadata.size || 0) <= 0 ||
              Number(metadata.size || 0) > 25 * 1024 * 1024) {
            throw new Error("invalid-video");
          }
      }));
      if (trustedImageHashes.some(
          (hash, index) => hash !== media.imageHashes[index])) {
        throw new Error("photo-integrity-mismatch");
      }
      return {...media, imageHashes: trustedImageHashes};
    } catch (error) {
      console.warn("Listing draft media verification failed", error);
      throw new HttpsError(
          "failed-precondition",
          "One or more selected media files are missing or invalid. Retry the upload.",
      );
    }
  }

  function auctionSettlementValues(listingId, listing, buyerUid, amount, source) {
    const quantity = Number(listing.auctionQuantity || listing.quantity || 1);
    const totalBasis = String(
        listing.auctionPricingBasis || listing.priceBasis || "",
    ).toLowerCase().includes("total");
    return {
      listingId,
      buyerUid,
      sellerUid: listing.sellerUid,
      status: "pending_completion",
      buyerConfirmed: false,
      sellerConfirmed: false,
      agreedUnitPrice: amount,
      agreedQuantity: Number.isFinite(quantity) && quantity > 0 ? quantity : 1,
      agreedTotal: totalBasis ? amount : amount * quantity,
      currency: listing.currency || "CAD",
      priceBasis: listing.auctionPricingBasis || listing.priceBasis || "",
      source,
      revision: 1,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
  }

  const finalizeAuctionRecord = async (
      listingId,
      actorUid = "auction_scheduler",
      receiptRef = null,
  ) => db.runTransaction(async (transaction) => {
    if (receiptRef) {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
    }
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateRef = db.collection("auction_private").doc(listingId);
    const saleRef = db.collection("auction_transactions").doc(listingId);
    const listingSnapshot = await transaction.get(listingRef);
    const privateSnapshot = await transaction.get(privateRef);
    const saleSnapshot = await transaction.get(saleRef);
    const listingData = listingSnapshot.exists ? listingSnapshot.data() : null;
    const listing = listingData ? {...listingData, id: listingId} : null;
    if (listing && TERMINAL_AUCTION_STATUSES.has(listing.auctionStatus) &&
        listing.finalizedAt) {
      const result = {
        listingId,
        auctionStatus: listing.auctionStatus,
        winnerUid: String(
            listing.acceptedBidderUid || listing.highBidderUid || "",
        ),
        amount: Number(listing.acceptedBidAmount || listing.currentBid || 0),
      };
      if (receiptRef) {
        transaction.create(
            receiptRef,
            receiptData(actorUid, "finalizeAuction", result, FieldValue),
        );
      }
      return result;
    }
    const outcome = validateAuctionFinalization({
      listing,
      privateAuction: privateSnapshot.data() || {},
      now: Timestamp.now(),
    });
    let leadingBidRef = null;
    let leadingBidSnapshot = null;
    if (outcome.winnerUid) {
      leadingBidRef = db.collection("auction_bids")
          .doc(String(listing.currentBidId || "missing"));
      leadingBidSnapshot = await transaction.get(leadingBidRef);
      validateLeadingBidRecord(
          listingId,
          listing,
          leadingBidSnapshot.exists ? leadingBidSnapshot.data() : null,
      );
    }
    const result = {listingId, ...outcome};
    transaction.update(listingRef, {
      auctionStatus: outcome.auctionStatus,
      reserveMet: outcome.reserveMet,
      ...(outcome.winnerUid ? {
        acceptedBidAmount: outcome.amount,
        acceptedBidderUid: outcome.winnerUid,
        saleStatus: "pending_completion",
      } : {}),
      finalizedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (leadingBidRef) {
      transaction.update(leadingBidRef, {
        status: "won",
        wonAt: FieldValue.serverTimestamp(),
      });
    }
    if (outcome.winnerUid && !saleSnapshot.exists) {
      const values = auctionSettlementValues(
          listingId,
          listing,
          outcome.winnerUid,
          outcome.amount,
          "auction_expiry",
      );
      transaction.create(saleRef, values);
      transaction.create(saleRef.collection("revisions").doc("1"), {
        ...values,
        event: "auction_won",
        actorUid,
      });
    }
    transaction.set(
        db.collection("users").doc(listing.sellerUid)
            .collection("notifications").doc(),
        {
          recipientUid: listing.sellerUid,
          actorUid,
          type: "auction",
          listingId,
          title: outcome.winnerUid ?
            "Your auction has a winning bidder" :
            outcome.amount > 0 ?
              "Auction ended below reserve" : "Auction ended with no bids",
          read: false,
          createdAt: FieldValue.serverTimestamp(),
        },
    );
    if (outcome.winnerUid) {
      transaction.set(
          db.collection("users").doc(outcome.winnerUid)
              .collection("notifications").doc(),
          {
            recipientUid: outcome.winnerUid,
            actorUid,
            type: "auction",
            listingId,
            title: "You won the auction",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
    }
    if (receiptRef) {
      transaction.create(
          receiptRef,
          receiptData(actorUid, "finalizeAuction", result, FieldValue),
      );
    }
    return result;
  });

  const createMarketplaceListingDraft = featureCommand(
      "marketplace",
      async (request, flags) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const rawListing = request.data && request.data.listing || {};
    const requestedTransaction = String(
        rawListing.transactionType || "For Sale",
    );
    if (requestedTransaction === "Auction") {
      requirePhase1Feature(flags, "auctions");
    }
    if (requestedTransaction === "Wanted / Seeking") {
      requirePhase1Feature(flags, "wantedAds");
    }
    if (rawListing.category === "Site & Property") {
      requirePhase1Feature(flags, "regulatedListings");
    }
    if (rawListing.boostRequested === true ||
        Number(rawListing.boostPrice || 0) > 0) {
      requirePhase1Feature(flags, "paidFeatures");
    }
    const expectedPhotoCount = Number(rawListing.mediaPhotoCount || 0);
    const expectsVideo = rawListing.hasVideo === true;
    if (!Number.isInteger(expectedPhotoCount) || expectedPhotoCount < 0 ||
        expectedPhotoCount > 12) {
      throw new HttpsError(
          "invalid-argument",
          "A listing can contain up to 12 selected photos.",
      );
    }
    const listing = validateMarketplaceListingInput(
        rawListing,
        new Date(),
        {regulatedListingsEnabled: flags.regulatedListings},
    );
    Object.assign(listing, {
      imageUrls: [],
      imageHashes: [],
      thumbnailUrl: null,
      videoUrl: null,
      mediaPhotoCount: expectedPhotoCount,
      hasVideo: expectsVideo,
      mediaUploadStatus: expectedPhotoCount > 0 || expectsVideo ?
        "queued" : "none",
    });
    const location = validateLocation(request.data && request.data.location);
    const reserve = validateReserve(rawListing, listing.transactionType);
    const draftRef = db.collection("marketplace_listing_drafts").doc(listingId);
    const listingRef = db.collection("public_listings").doc(listingId);
    const receiptRef = receiptReference(
        db,
        uid,
        "createMarketplaceListingDraft",
        {listingId},
    );
    return db.runTransaction(async (transaction) => {
      const draftSnapshot = await transaction.get(draftRef);
      const listingSnapshot = await transaction.get(listingRef);
      const receipt = await transaction.get(receiptRef);
      if (listingSnapshot.exists) {
        if (listingSnapshot.data().sellerUid !== uid) {
          throw new HttpsError(
              "already-exists",
              "This listing identifier is already in use.",
          );
        }
        return {listingId, status: "published", alreadyPublished: true};
      }
      if (draftSnapshot.exists) {
        if (draftSnapshot.data().sellerUid !== uid) {
          throw new HttpsError(
              "already-exists",
              "This listing identifier is already in use.",
          );
        }
        return receipt.exists ? receipt.data().result : {
          listingId,
          status: String(draftSnapshot.data().status || "awaiting_media"),
          alreadyPublished: false,
        };
      }
      await loadListingPublisher(transaction, uid, request, listing);
      const status = expectedPhotoCount > 0 || expectsVideo ?
        "awaiting_media" : "ready_to_publish";
      const result = {listingId, status, alreadyPublished: false};
      transaction.create(draftRef, {
        sellerUid: uid,
        listing,
        location,
        reserve,
        expectedPhotoCount,
        expectsVideo,
        media: {
          status: expectedPhotoCount > 0 || expectsVideo ? "uploading" : "none",
          imageUrls: [],
          imageHashes: [],
          thumbnailUrl: "",
          videoUrl: "",
        },
        status,
        revision: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(Date.now() + 30 * 24 * 60 * 60 * 1000),
      });
      transaction.create(
          receiptRef,
          receiptData(uid, "createMarketplaceListingDraft", result, FieldValue),
      );
      return result;
    });
      },
  );

  const updateMarketplaceListingDraftMedia = featureCommand(
      "marketplace",
      async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const draftRef = db.collection("marketplace_listing_drafts").doc(listingId);
    const initialSnapshot = await draftRef.get();
    if (!initialSnapshot.exists) {
      throw new HttpsError("not-found", "Listing draft not found.");
    }
    const initialDraft = initialSnapshot.data();
    if (initialDraft.sellerUid !== uid) {
      throw new HttpsError(
          "permission-denied",
          "Only the draft owner can update its media.",
      );
    }
    let submittedMedia = validateListingMediaManifest(request.data, {
      ownerUid: uid,
      listingId,
      expectedPhotoCount: Number(initialDraft.expectedPhotoCount || 0),
      expectsVideo: initialDraft.expectsVideo === true,
    });
    if (submittedMedia.status === "complete") {
      submittedMedia = await verifyDraftMediaObjects(submittedMedia);
    }
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(draftRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Listing draft not found.");
      }
      const draft = snapshot.data();
      if (draft.sellerUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the draft owner can update its media.",
        );
      }
      if (draft.status === "publishing" || draft.status === "published") {
        throw new HttpsError(
            "failed-precondition",
            "This draft is already being published.",
        );
      }
      const media = validateListingMediaManifest(submittedMedia, {
        ownerUid: uid,
        listingId,
        expectedPhotoCount: Number(draft.expectedPhotoCount || 0),
        expectsVideo: draft.expectsVideo === true,
      });
      const status = media.status === "complete" ?
        "ready_to_publish" : "awaiting_media";
      transaction.update(draftRef, {
        media,
        status,
        revision: Number(draft.revision || 1) + 1,
        ...(media.status === "failed" ? {
          mediaUploadError: String(request.data.error || "").slice(0, 800),
        } : {mediaUploadError: FieldValue.delete()}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {listingId, status, mediaStatus: media.status};
    });
      },
  );

  const publishMarketplaceListingDraft = featureCommand(
      "marketplace",
      async (request, flags) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const draftRef = db.collection("marketplace_listing_drafts").doc(listingId);
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateLocationRef = db.collection("listing_private_locations")
        .doc(listingId);
    const privateAuctionRef = db.collection("auction_private").doc(listingId);
    const receiptRef = receiptReference(
        db,
        uid,
        "publishMarketplaceListingDraft",
        {requestId, listingId},
    );
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const draftSnapshot = await transaction.get(draftRef);
      const listingSnapshot = await transaction.get(listingRef);
      if (listingSnapshot.exists) {
        if (listingSnapshot.data().sellerUid !== uid) {
          throw new HttpsError(
              "already-exists",
              "This listing identifier is already in use.",
          );
        }
        const result = {listingId, alreadyPublished: true};
        transaction.create(
            receiptRef,
            receiptData(
                uid,
                "publishMarketplaceListingDraft",
                result,
                FieldValue,
            ),
        );
        return result;
      }
      if (!draftSnapshot.exists) {
        throw new HttpsError("not-found", "Listing draft not found.");
      }
      const draft = draftSnapshot.data();
      if (draft.sellerUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the draft owner can publish this listing.",
        );
      }
      const listing = validateMarketplaceListingInput(
          draft.listing,
          new Date(),
          {regulatedListingsEnabled: flags.regulatedListings},
      );
      if (listing.transactionType === "Auction") {
        requirePhase1Feature(flags, "auctions");
      }
      if (listing.transactionType === "Wanted / Seeking") {
        requirePhase1Feature(flags, "wantedAds");
      }
      if (listing.category === "Site & Property") {
        requirePhase1Feature(flags, "regulatedListings");
      }
      if (listing.boostRequested === true || Number(listing.boostPrice || 0) > 0) {
        requirePhase1Feature(flags, "paidFeatures");
      }
      const location = validateLocation(draft.location);
      const hasExpectedMedia = Number(draft.expectedPhotoCount || 0) > 0 ||
        draft.expectsVideo === true;
      const media = hasExpectedMedia ?
        validateListingMediaManifest(draft.media, {
          ownerUid: uid,
          listingId,
          expectedPhotoCount: Number(draft.expectedPhotoCount || 0),
          expectsVideo: draft.expectsVideo === true,
          requireComplete: true,
        }) : {
          status: "none",
          imageUrls: [],
          imageHashes: [],
          thumbnailUrl: "",
          videoUrl: "",
        };
      Object.assign(listing, {
        imageUrls: media.imageUrls,
        imageHashes: media.imageHashes,
        thumbnailUrl: media.thumbnailUrl || null,
        videoUrl: media.videoUrl || null,
        mediaPhotoCount: media.imageUrls.length,
        hasVideo: Boolean(media.videoUrl),
        mediaUploadStatus: hasExpectedMedia ? "complete" : "none",
      });
      const publisher = await loadListingPublisher(
          transaction,
          uid,
          request,
          listing,
      );
      const values = publicationValues(uid, listing, location, publisher);
      const result = {listingId, alreadyPublished: false};
      transaction.create(listingRef, values.publicListing);
      transaction.create(privateLocationRef, values.privateLocation);
      if (draft.reserve) {
        transaction.create(privateAuctionRef, {
          ownerUid: uid,
          ...draft.reserve,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.delete(draftRef);
      transaction.create(
          receiptRef,
          receiptData(
              uid,
              "publishMarketplaceListingDraft",
              result,
              FieldValue,
          ),
      );
      return result;
    });
      },
  );

  const createMarketplaceListing = featureCommand(
      "marketplace",
      async (request, flags) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const rawListing = request.data && request.data.listing || {};
    const requestedTransaction = String(
        rawListing.transactionType || "For Sale",
    );
    if (requestedTransaction === "Auction") {
      requirePhase1Feature(flags, "auctions");
    }
    if (requestedTransaction === "Wanted / Seeking") {
      requirePhase1Feature(flags, "wantedAds");
    }
    if (rawListing.category === "Site & Property") {
      requirePhase1Feature(flags, "regulatedListings");
    }
    if (
      rawListing.boostRequested === true ||
      Number(rawListing.boostPrice || 0) > 0
    ) {
      requirePhase1Feature(flags, "paidFeatures");
    }
    if (Number(rawListing.mediaPhotoCount || 0) > 0 ||
        rawListing.hasVideo === true ||
        Array.isArray(rawListing.imageUrls) && rawListing.imageUrls.length > 0 ||
        Array.isArray(rawListing.imageHashes) &&
          rawListing.imageHashes.length > 0 ||
        String(rawListing.thumbnailUrl || "").trim() ||
        String(rawListing.videoUrl || "").trim()) {
      throw new HttpsError(
          "failed-precondition",
          "Listings with selected media must use the draft upload workflow.",
      );
    }
    const listing = validateMarketplaceListingInput(
        rawListing,
        new Date(),
        {regulatedListingsEnabled: flags.regulatedListings},
    );
    const location = validateLocation(request.data && request.data.location);
    const reserve = validateReserve(
        request.data && request.data.listing,
        listing.transactionType,
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateLocationRef = db.collection("listing_private_locations")
        .doc(listingId);
    const privateAuctionRef = db.collection("auction_private").doc(listingId);
    const receiptRef = receiptReference(
        db,
        uid,
        "createMarketplaceListing",
        {listingId},
    );

    return db.runTransaction(async (transaction) => {
      const existing = await transaction.get(listingRef);
      const receipt = await transaction.get(receiptRef);
      if (existing.exists) {
        if (existing.data().sellerUid !== uid) {
          throw new HttpsError(
              "already-exists",
              "This listing identifier is already in use.",
          );
        }
        return receipt.exists ?
          receipt.data().result :
          {listingId, alreadyPublished: true};
      }

      const publisher = await loadListingPublisher(
          transaction,
          uid,
          request,
          listing,
      );
      const values = publicationValues(uid, listing, location, publisher);
      const result = {listingId, alreadyPublished: false};

      transaction.create(listingRef, values.publicListing);
      transaction.create(privateLocationRef, values.privateLocation);
      if (reserve) {
        transaction.create(privateAuctionRef, {
          ownerUid: uid,
          ...reserve,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.set(
          receiptRef,
          receiptData(
              uid,
              "createMarketplaceListing",
              result,
              FieldValue,
          ),
      );
      return result;
    });
      },
  );

  const setMarketplaceListingSaved = featureCommand(
      "marketplace",
      async (request) => {
    const uid = requireAuth(request, {requirePhone: false});
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const saved = request.data && request.data.saved;
    if (typeof saved !== "boolean") {
      throw new HttpsError(
          "invalid-argument",
          "The saved state must be true or false.",
      );
    }
    const receiptRef = receiptReference(
        db,
        uid,
        "setMarketplaceListingSaved",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const savedRef = db.collection("users").doc(uid)
        .collection("saved_listings").doc(listingId);
    const eventRef = db.collection("listing_events").doc();
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const savedSnapshot = await transaction.get(savedRef);
      if (!listingSnapshot.exists) {
        throw new HttpsError("not-found", "This listing is unavailable.");
      }
      const wasSaved = savedSnapshot.exists;
      const changed = wasSaved !== saved;
      if (changed && saved) {
        transaction.create(savedRef, {
          listingId,
          savedAt: FieldValue.serverTimestamp(),
        });
      } else if (changed) {
        transaction.delete(savedRef);
      }
      if (changed) {
        transaction.create(eventRef, {
          listingId,
          actorUid: uid,
          type: saved ? "save" : "unsave",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
      const result = {listingId, saved, changed};
      transaction.create(
          receiptRef,
          receiptData(uid, "setMarketplaceListingSaved", result, FieldValue),
      );
      return result;
    });
      },
  );

  const updateMarketplaceListingMedia = featureCommand(
      "marketplace",
      async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const imageUrls = Array.isArray(request.data && request.data.imageUrls) ?
      request.data.imageUrls.map((value) => String(value || "").trim()) : [];
    const imageHashes =
      Array.isArray(request.data && request.data.imageHashes) ?
        request.data.imageHashes.map((value) => String(value || "").trim()) :
        [];
    const thumbnailUrl =
      String(request.data && request.data.thumbnailUrl || "").trim();
    const videoUrl = String(request.data && request.data.videoUrl || "").trim();
    const status = String(request.data && request.data.status || "").trim();
    const errorMessage = String(request.data && request.data.error || "").trim();
    if (
      imageUrls.length > 30 ||
      imageHashes.length > 30 ||
      imageUrls.some((value) => !value.startsWith("https://")) ||
      thumbnailUrl && !imageUrls.includes(thumbnailUrl) ||
      videoUrl && !videoUrl.startsWith("https://") ||
      !["none", "queued", "uploading", "complete", "failed"].includes(status)
    ) {
      throw new HttpsError(
          "invalid-argument",
          "Listing media update is invalid.",
      );
    }
    const listingRef = db.collection("public_listings").doc(listingId);
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(listingRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Listing not found.");
      }
      if (snapshot.data().sellerUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the listing owner can update its media.",
        );
      }
      transaction.update(listingRef, {
        imageUrls,
        imageHashes,
        thumbnailUrl: thumbnailUrl || null,
        videoUrl: videoUrl || null,
        mediaPhotoCount: imageUrls.length,
        hasVideo: Boolean(videoUrl),
        mediaUploadStatus: status,
        ...(errorMessage ? {mediaUploadError: errorMessage.slice(0, 800)} : {}),
        mediaUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {listingId, status};
    });
      },
  );

  async function cleanupExpiredMarketplaceListingDrafts(batchLimit = 50) {
    const expired = await db.collection("marketplace_listing_drafts")
        .where("expiresAt", "<=", Timestamp.now())
        .limit(batchLimit)
        .get();
    let removed = 0;
    for (const snapshot of expired.docs) {
      const listingSnapshot = await db.collection("public_listings")
          .doc(snapshot.id)
          .get();
      if (!listingSnapshot.exists) {
        const ownerUid = String(snapshot.data().sellerUid || "").trim();
        if (ownerUid) {
          await admin.storage().bucket().deleteFiles({
            prefix: `listing_media/${ownerUid}/${snapshot.id}/`,
          });
        }
      }
      await db.recursiveDelete(snapshot.ref);
      removed++;
    }
    return removed;
  }

  const updateMarketplaceListingDetails = featureCommand(
      "marketplace",
      async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const receiptRef = receiptReference(
        db,
        uid,
        "updateMarketplaceListingDetails",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const snapshot = await transaction.get(listingRef);
      const listing = snapshot.exists ? snapshot.data() : null;
      const update = validateListingDetailsUpdate({
        listing,
        actorUid: uid,
        data: request.data,
      });
      const searchableListing = {...listing, ...update.changes};
      const result = {listingId, revision: update.nextRevision};
      transaction.update(listingRef, {
        ...update.changes,
        searchTokens: buildMarketplaceSearchTokens(searchableListing),
        searchIndexVersion,
        revision: update.nextRevision,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          listingRef.collection("revisions").doc(String(update.nextRevision)),
          {
            actorUid: uid,
            event: "details_updated",
            previousRevision: update.currentRevision,
            revision: update.nextRevision,
            changes: update.changes,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(
          receiptRef,
          receiptData(uid, "updateMarketplaceListingDetails", result, FieldValue),
      );
      return result;
    });
      },
  );

  const transitionMarketplaceListing = featureCommand(
      "marketplace",
      async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const action = String(request.data && request.data.action || "").trim();
    const receiptRef = receiptReference(
        db,
        uid,
        "transitionMarketplaceListing",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const snapshot = await transaction.get(listingRef);
      const listing = snapshot.exists ? snapshot.data() : null;
      const transition = validateListingTransition({listing, actorUid: uid, action});
      const wantedStatus = listing &&
        listing.transactionType === "Wanted / Seeking" ? {
          pause: "paused",
          activate: "open",
          mark_fulfilled: "fulfilled",
          archive: "archived",
        }[action] : null;
      const result = {
        listingId,
        status: transition.status,
        revision: transition.nextRevision,
      };
      transaction.update(listingRef, {
        status: transition.status,
        revision: transition.nextRevision,
        statusChangedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(wantedStatus ? {wantedStatus} : {}),
        ...(action === "mark_sold" ? {
          soldAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(action === "archive" ? {
          archivedAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(action === "mark_fulfilled" ? {
          fulfilledAt: FieldValue.serverTimestamp(),
        } : {}),
      });
      transaction.create(
          listingRef.collection("revisions").doc(String(transition.nextRevision)),
          {
            actorUid: uid,
            event: action,
            previousStatus: transition.previousStatus,
            status: transition.status,
            ...(wantedStatus ? {wantedStatus} : {}),
            revision: transition.nextRevision,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(
          receiptRef,
          receiptData(uid, "transitionMarketplaceListing", result, FieldValue),
      );
      return result;
    });
      },
  );

  const manageWantedMatch = command(async (request) => {
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "wantedAds");
    await enforceUserRateLimit({db, admin, request, scope: "marketplace"});
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const matchId = requiredId(request.data, "matchId");
    const action = String(request.data && request.data.action || "").trim();
    const receiptRef = receiptReference(
        db,
        uid,
        "manageWantedMatch",
        {requestId},
    );
    const matchRef = db.collection("wanted_matches").doc(matchId);
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const snapshot = await transaction.get(matchRef);
      const match = snapshot.exists ? snapshot.data() : null;
      const transition = validateWantedMatchAction({
        match,
        actorUid: uid,
        action,
      });
      const contactRecorded = match.contactRecorded === true ||
        action === "mark_contacted";
      const result = {
        matchId,
        action,
        role: transition.role,
        state: transition.nextState,
        status: transition.status,
        revision: transition.revision,
      };
      transaction.update(matchRef, {
        [transition.field]: transition.nextState,
        status: transition.status,
        revision: transition.revision,
        contactRecorded,
        [`${transition.role}UpdatedAt`]: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          matchRef.collection("events").doc(String(transition.revision)),
          {
            actorUid: uid,
            actorRole: transition.role,
            action,
            previousState: transition.previousState,
            state: transition.nextState,
            status: transition.status,
            revision: transition.revision,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      if (action === "mark_contacted") {
        const recipientUid = transition.role === "wantedOwner" ?
          match.sellerUid : match.wantedOwnerUid;
        const listingId = transition.role === "wantedOwner" ?
          match.wantedListingId : match.supplyListingId;
        transaction.set(
            db.collection("users").doc(recipientUid)
                .collection("notifications").doc(receiptRef.id),
            {
              recipientUid,
              actorUid: uid,
              type: "wanted_contact",
              title: "A Wanted match participant opened a conversation",
              listingId,
              wantedMatchId: matchId,
              read: false,
              createdAt: FieldValue.serverTimestamp(),
            },
        );
        if (match.contactRecorded !== true) {
          transaction.update(
              db.collection("public_listings").doc(match.wantedListingId),
              {
                responseCount: FieldValue.increment(1),
                updatedAt: FieldValue.serverTimestamp(),
              },
          );
        }
      }
      transaction.create(
          receiptRef,
          receiptData(uid, "manageWantedMatch", result, FieldValue),
      );
      return result;
    });
  });

  const relistMarketplaceListing = featureCommand(
      "marketplace",
      async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const newListingId = requiredId(request.data, "newListingId");
    const receiptRef = receiptReference(
        db,
        uid,
        "relistMarketplaceListing",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const newListingRef = db.collection("public_listings").doc(newListingId);
    const locationRef = db.collection("listing_private_locations").doc(listingId);
    const newLocationRef =
      db.collection("listing_private_locations").doc(newListingId);
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const newListingSnapshot = await transaction.get(newListingRef);
      const locationSnapshot = await transaction.get(locationRef);
      const listing = listingSnapshot.exists ?
        {...listingSnapshot.data(), id: listingId} :
        null;
      validateListingRelist({listing, actorUid: uid, newListingId});
      if (newListingSnapshot.exists) {
        throw new CommandPolicyError(
            "already-exists",
            "The new listing identifier is already in use.",
        );
      }
      const clone = {...listing};
      for (const field of [
        "id", "acceptedOfferId", "acceptedBuyerUid", "offerAcceptedAt",
        "soldAt", "archivedAt", "statusChangedAt", "currentBidId",
        "highBidderUid", "acceptedBidderUid", "lastBidAt", "buyNowBuyerUid",
        "acceptedBidAmount", "winningBidId", "winningBidderUid", "wonAt",
        "auctionStatus", "auctionStartAt", "auctionEndAt", "startingBid",
        "minimumBidIncrement", "currentBid", "bidCount", "reserveMet",
        "buyNowPrice", "convertedAt", "conversionSource", "fulfilledAt",
        "lastMatchedAt", "publishedAt", "expiresAt", "renewedAt",
        "expiredAt", "listingDurationDays", "renewalCount",
        "lifecycleVersion", "expiryWarningSentAt", "expiryWarningFor",
      ]) delete clone[field];
      Object.assign(clone, {
        status: "active",
        saleStatus: "available",
        source: "marketplace_relist_callable",
        relistedFromListingId: listingId,
        publishedAt: Timestamp.now(),
        expiresAt: Timestamp.fromMillis(
          Date.now() + MARKETPLACE_LISTING_ACTIVE_DAYS * DAY_MS,
        ),
        listingDurationDays: MARKETPLACE_LISTING_ACTIVE_DAYS,
        renewalCount: 0,
        lifecycleVersion: 1,
        initialPrice: Number(clone.price || 0),
        revision: 1,
        viewCount: 0,
        saveCount: 0,
        shareCount: 0,
        likeCount: 0,
        messageCount: 0,
        offerCount: 0,
        pendingOfferCount: 0,
        withdrawnBidCount: 0,
        ...(clone.transactionType === "Wanted / Seeking" ? {
          wantedStatus: "open",
          responseCount: 0,
          matchCount: 0,
        } : {}),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      const result = {listingId: newListingId, relistedFromListingId: listingId};
      transaction.create(newListingRef, clone);
      if (locationSnapshot.exists) {
        transaction.create(newLocationRef, {
          ...locationSnapshot.data(),
          ownerUid: uid,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      transaction.create(newListingRef.collection("revisions").doc("1"), {
        actorUid: uid,
        event: "relisted",
        relistedFromListingId: listingId,
        revision: 1,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          receiptRef,
          receiptData(uid, "relistMarketplaceListing", result, FieldValue),
      );
      return result;
    });
      },
  );

  const convertMarketplaceListingToAuction = featureCommand(
      "auctions",
      async (request, flags) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const listingId = requiredId(request.data, "listingId");
    const receiptRef = receiptReference(
        db,
        uid,
        "convertMarketplaceListingToAuction",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const privateAuctionRef = db.collection("auction_private").doc(listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const userSnapshot = await transaction.get(
          db.collection("users").doc(uid),
      );
      const privateAuctionSnapshot = await transaction.get(privateAuctionRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
      const user = userSnapshot.data() || {};
      const conversion = validateAuctionConversion({
        listing,
        actorUid: uid,
        user,
        administrator: isAdministrator(request),
        data: request.data,
        paidFeaturesEnabled: flags.paidFeatures,
        now: Timestamp.now(),
      });
      const reserveTotal = conversion.reservePrice == null ?
        null :
        (conversion.priceBasis.toLowerCase().includes("total") ||
          conversion.quantity == null ?
          conversion.reservePrice :
          conversion.reservePrice * conversion.quantity);
      const buyItNowTotal = conversion.buyItNowPrice == null ?
        null :
        (conversion.priceBasis.toLowerCase().includes("total") ||
          conversion.quantity == null ?
          conversion.buyItNowPrice :
          conversion.buyItNowPrice * conversion.quantity);
      const result = {
        listingId,
        status: "live",
        durationDays: conversion.durationDays,
        customAuction: conversion.customAuction,
      };

      transaction.update(listingRef, {
        transactionType: "Auction",
        startingBid: conversion.startingBid,
        currentBid: 0,
        minimumBidIncrement: conversion.minimumBidIncrement,
        bidIncrementPricingBasis: conversion.priceBasis,
        reservePrice: FieldValue.delete(),
        reserveTotal: FieldValue.delete(),
        buyItNowPrice: conversion.buyItNowPrice == null ?
          FieldValue.delete() :
          conversion.buyItNowPrice,
        buyItNowTotal: buyItNowTotal == null ?
          FieldValue.delete() :
          buyItNowTotal,
        auctionPricingBasis: conversion.priceBasis,
        auctionQuantity: conversion.quantity,
        askingPriceAtConversion: conversion.askingPrice,
        askingTotalAtConversion: conversion.askingTotal,
        auctionDurationDays: conversion.durationDays,
        customAuction: conversion.customAuction,
        bidWithdrawalAfterDays: conversion.customAuction ? 32 : null,
        customAuctionUpfrontFee: conversion.customAuction ? 29.99 : 0,
        customAuctionSaleFeePercent: conversion.customAuction ? 5 : 0,
        additionalAuctionFeesDisclosure: conversion.customAuction,
        auctionStartAt: Timestamp.fromMillis(conversion.auctionStartAt),
        auctionEndAt: Timestamp.fromMillis(conversion.auctionEndAt),
        auctionStatus: "live",
        bidCount: 0,
        notifyNewBids: true,
        notifyReserveReached: true,
        notifyAuctionEnding: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (conversion.reservePrice != null) {
        transaction.set(privateAuctionRef, {
          ownerUid: uid,
          reservePrice: conversion.reservePrice,
          ...(reserveTotal == null ? {} : {reserveTotal}),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (privateAuctionSnapshot.exists) {
        transaction.delete(privateAuctionRef);
      }
      transaction.set(
          receiptRef,
          receiptData(
              uid,
              "convertMarketplaceListingToAuction",
              result,
              FieldValue,
          ),
      );
      return result;
    });
      },
  );

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

  function maskedTimedOfferPersonalName(rawName) {
    const parts = String(rawName || "").trim().split(/\s+/).filter(Boolean);
    if (parts.length === 0) return "Authenticated buyer";
    if (parts.length === 1) return parts[0].slice(0, 40);
    const last = parts[parts.length - 1];
    return (parts[0] + " " + last.slice(0, 1).toUpperCase() + ".").slice(0, 80);
  }

  async function timedOfferPublicIdentity(transaction, buyerUid, request) {
    const userSnapshot = await transaction.get(db.collection("users").doc(buyerUid));
    const user = userSnapshot.data() || {};
    const accountType = String(user.accountType || "personal").trim() || "personal";
    let publicName = "";
    if (accountType === "business") {
      const businessSnapshot = await transaction.get(
          db.collection("public_business_profiles").doc(buyerUid),
      );
      publicName = String(
          businessSnapshot.data() && businessSnapshot.data().publicName ||
          user.businessName || user.displayName || user.display_name || "",
      ).trim();
    } else {
      const personalName = String(
          user.display_name || user.displayName ||
          (buyerUid === request.auth.uid && request.auth.token && request.auth.token.name) ||
          "",
      ).trim();
      publicName = maskedTimedOfferPersonalName(personalName);
    }
    return {
      bidderPublicName: (publicName || "Authenticated buyer").slice(0, 160),
      bidderVerified: approvedAccountVerification(user),
      bidderAccountType: accountType.slice(0, 40),
      bidderIdentityVersion: 1,
    };
  }

  const placeAuctionBid = featureCommand("auctions", async (request) => {
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
      const bidderIdentity = await timedOfferPublicIdentity(
          transaction, uid, request,
      );
      const sequenceNumber = Number(listing.bidCount || 0) + 1;

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
        ...bidderIdentity,
        sequenceNumber,
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

  const finalizeAuction = featureCommand("auctions", async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const requestId = requiredId(request.data, "requestId");
    return finalizeAuctionRecord(
        listingId,
        uid,
        receiptReference(db, uid, "finalizeAuction", {requestId}),
    );
  });

  const buyAuctionNow = featureCommand("auctions", async (request) => {
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
    const saleRef = db.collection("auction_transactions").doc(listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const privateAuctionSnapshot =
        await transaction.get(privateAuctionRef);
      const saleSnapshot = await transaction.get(saleRef);
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
      if (!saleSnapshot.exists) {
        const values = auctionSettlementValues(
            listingId,
            listing,
            uid,
            price,
            "buy_now",
        );
        transaction.create(saleRef, values);
        transaction.create(saleRef.collection("revisions").doc("1"), {
          ...values,
          event: "auction_bought_now",
          actorUid: uid,
        });
      }
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

  const acceptAuctionBidBelowReserve =
    featureCommand("auctions", async (request) => {
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
    const saleRef = db.collection("auction_transactions").doc(listingId);

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const privateAuctionSnapshot =
        await transaction.get(privateAuctionRef);
      const saleSnapshot = await transaction.get(saleRef);
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
      if (!saleSnapshot.exists) {
        const values = auctionSettlementValues(
            listingId,
            listing,
            accepted.bidderUid,
            accepted.amount,
            "accepted_below_reserve",
        );
        transaction.create(saleRef, values);
        transaction.create(saleRef.collection("revisions").doc("1"), {
          ...values,
          event: "bid_accepted_below_reserve",
          actorUid: uid,
        });
      }
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

  const updateAuctionTransaction = featureCommand(
      "auctions",
      async (request) => {
    const uid = requireAuth(request);
    const listingId = requiredId(request.data, "listingId");
    const requestId = requiredId(request.data, "requestId");
    const action = requiredId(request.data, "action");
    const reason = String(request.data && request.data.reason || "").trim();
    const receiptRef = receiptReference(
        db,
        uid,
        "updateAuctionTransaction",
        {requestId},
    );
    const listingRef = db.collection("public_listings").doc(listingId);
    const saleRef = db.collection("auction_transactions").doc(listingId);
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const saleSnapshot = await transaction.get(saleRef);
      const listing = listingSnapshot.exists ?
        {...listingSnapshot.data(), id: listingId} : null;
      const sale = saleSnapshot.exists ? saleSnapshot.data() : null;
      const transition = validateAuctionTransactionAction({
        sale,
        listing,
        actorUid: uid,
        action,
        reason,
        administrator: isAdministrator(request),
      });
      const currentRevision = Number(sale.revision || 1);
      const result = {
        listingId,
        status: transition.status,
        buyerConfirmed: transition.buyerConfirmed,
        sellerConfirmed: transition.sellerConfirmed,
        revision: transition.alreadyApplied ?
          currentRevision : currentRevision + 1,
      };
      if (transition.alreadyApplied) {
        transaction.create(
            receiptRef,
            receiptData(uid, "updateAuctionTransaction", result, FieldValue),
        );
        return result;
      }
      const revision = currentRevision + 1;
      transaction.update(saleRef, {
        status: transition.status,
        buyerConfirmed: transition.buyerConfirmed,
        sellerConfirmed: transition.sellerConfirmed,
        revision,
        lastAction: action,
        lastActionByUid: uid,
        ...(transition.reason ? {reason: transition.reason} : {}),
        ...(action === "confirm_completion" ? {
          [`${transition.actorRole}ConfirmedAt`]:
            FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.status === "completed" ? {
          completedAt: FieldValue.serverTimestamp(),
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(
          saleRef.collection("revisions").doc(String(revision)),
          {
            event: action,
            actorUid: uid,
            status: transition.status,
            buyerConfirmed: transition.buyerConfirmed,
            sellerConfirmed: transition.sellerConfirmed,
            ...(transition.reason ? {reason: transition.reason} : {}),
            revision,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      if (transition.status === "completed") {
        transaction.update(listingRef, {
          status: "sold",
          saleStatus: "completed",
          soldAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (transition.status === "cancelled") {
        transaction.update(listingRef, {
          status: "archived",
          auctionStatus: "cancelled",
          saleStatus: "cancelled",
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(listingRef, {
          saleStatus: transition.status,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      if (["disputed", "buyer_default_reported", "seller_default_reported"]
          .includes(transition.status)) {
        transaction.set(db.collection("auction_disputes").doc(listingId), {
          listingId,
          buyerUid: sale.buyerUid,
          sellerUid: sale.sellerUid,
          openedByUid: uid,
          reason: transition.reason,
          type: transition.status,
          status: "open",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      const recipientUid = uid === sale.buyerUid ? sale.sellerUid : sale.buyerUid;
      transaction.set(
          db.collection("users").doc(recipientUid)
              .collection("notifications").doc(receiptRef.id),
          {
            recipientUid,
            actorUid: uid,
            type: "auction",
            listingId,
            title: transition.status === "completed" ?
              "Auction purchase completed" :
              transition.status === "disputed" ?
                "Auction settlement disputed" :
                transition.status.includes("default") ?
                  "Auction default reported" :
                  transition.status === "cancelled" ?
                    "Auction settlement cancelled" :
                    "Auction confirmation updated",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(
          receiptRef,
          receiptData(uid, "updateAuctionTransaction", result, FieldValue),
      );
      return result;
    });
      },
  );

  const withdrawAuctionBid = featureCommand("auctions", async (request) => {
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

  const createMarketplaceOffer = featureCommand("offers", async (request) => {
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
    const privateListingLocationRef = db
        .collection("listing_private_locations").doc(listingId);
    const offerRef = db.collection("offers").doc(requestId);
    const conversationRef = conversationId ?
      db.collection("conversations").doc(conversationId) :
      null;

    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const listingSnapshot = await transaction.get(listingRef);
      const listing = listingSnapshot.exists ? listingSnapshot.data() : null;
      const privateListingLocationSnapshot =
        request.data.truckingPlan === "request_dispatch" ?
          await transaction.get(privateListingLocationRef) :
          null;
      const privateListingLocation =
        privateListingLocationSnapshot &&
        privateListingLocationSnapshot.exists ?
          privateListingLocationSnapshot.data() : {};
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
        const pickupPoint = privateListingLocation.exactGeoPoint ||
          listing.publicGeoPoint || null;
        const routeState = buildDispatchRouteState(
            pickupPoint,
            deliveryPoint,
            {providerConfigured: false},
        );
        const dispatchRef = db.collection("dispatch_jobs").doc(offerRef.id);
        const privateDispatchRef = db
            .collection("dispatch_job_private").doc(offerRef.id);
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
          deliveryTown: delivery.nearestTown,
          deliveryRegion: delivery.region,
          deliveryCountry: delivery.country,
          ...routeState,
          locationPrivacyVersion: 1,
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
        const privateJobValues = {
          createdByUid: uid,
          ...(pickupPoint ? {pickupPoint} : {}),
          deliveryPoint,
          deliveryAddress: delivery.address,
          deliveryPostalCode: delivery.postalCode,
          deliveryAccessNotes: delivery.accessNotes,
          locationPrivacyVersion: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        transaction.create(dispatchRef, jobValues);
        transaction.create(privateDispatchRef, privateJobValues);
        transaction.create(dispatchRef.collection("revisions").doc("1"), {
          ...jobValues,
          event: "request_created",
          actorUid: uid,
        });
        transaction.create(
            privateDispatchRef.collection("revisions").doc("1"),
            {
              ...privateJobValues,
              event: "request_created",
              actorUid: uid,
            },
        );
      }
      transaction.set(
          receiptRef,
          receiptData(uid, "createMarketplaceOffer", result, FieldValue),
      );
      return result;
    });
  });

  const acceptMarketplaceOffer = featureCommand("offers", async (request) => {
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
      const marketplaceTransactionRef = db.collection("marketplace_transactions")
          .doc(offerId);
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
      const marketplaceTransactionSnapshot =
        await transaction.get(marketplaceTransactionRef);
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
      if (!marketplaceTransactionSnapshot.exists) {
        const transactionValues = {
          offerId,
          listingId: offer.listingId,
          conversationId: offer.conversationId || null,
          buyerUid: offer.buyerUid,
          sellerUid: offer.sellerUid,
          status: "pending_completion",
          buyerConfirmed: false,
          sellerConfirmed: false,
          agreedUnitPrice: Number(offer.offeredUnitPrice || 0),
          agreedQuantity: Number(offer.requestedQuantity || 0),
          agreedTotal: Number(offer.offeredTotal || 0),
          currency: offer.currency || "CAD",
          priceBasis: offer.priceBasis || "",
          purchaseDate: offer.purchaseDate || null,
          moneyTransferDate: offer.moneyTransferDate || null,
          truckingDate: offer.truckingDate || null,
          truckingPlan: offer.truckingPlan || "not_specified",
          dispatchRequested: offer.dispatchRequested === true,
          revision: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };
        transaction.create(marketplaceTransactionRef, transactionValues);
        transaction.create(
            marketplaceTransactionRef.collection("revisions").doc("1"),
            {
              ...transactionValues,
              event: "offer_accepted",
              actorUid: uid,
            },
        );
      }
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

  const updateMarketplaceTransaction = featureCommand(
      "offers",
      async (request) => {
    const uid = requireAuth(request);
    const requestId = requiredId(request.data, "requestId");
    const offerId = requiredId(request.data, "offerId");
    const action = requiredId(request.data, "action");
    const reason = String(request.data && request.data.reason || "").trim();
    const receiptRef = receiptReference(
        db,
        uid,
        "updateMarketplaceTransaction",
        {requestId},
    );
    const offerRef = db.collection("offers").doc(offerId);
    const saleRef = db.collection("marketplace_transactions").doc(offerId);
    return db.runTransaction(async (transaction) => {
      const receipt = await transaction.get(receiptRef);
      if (receipt.exists) return receipt.data().result;
      const offerSnapshot = await transaction.get(offerRef);
      const offer = offerSnapshot.exists ?
        {...offerSnapshot.data(), id: offerId} :
        null;
      const listingRef = db.collection("public_listings")
          .doc(String(offer && offer.listingId || "missing"));
      const saleSnapshot = await transaction.get(saleRef);
      const listingSnapshot = await transaction.get(listingRef);
      const dispatchJobs = await transaction.get(
          db.collection("dispatch_jobs")
              .where("offerId", "==", offerId)
              .limit(5),
      );
      const sale = saleSnapshot.exists ? saleSnapshot.data() : null;
      const transition = validateMarketplaceTransactionAction({
        sale,
        offer,
        actorUid: uid,
        action,
        reason,
      });
      const currentRevision = Number(sale && sale.revision || 0);
      const result = {
        offerId,
        listingId: String(offer.listingId || ""),
        status: transition.status,
        buyerConfirmed: transition.buyerConfirmed,
        sellerConfirmed: transition.sellerConfirmed,
        revision: transition.alreadyApplied ?
          currentRevision :
          currentRevision + 1,
      };
      if (transition.alreadyApplied) {
        transaction.create(
            receiptRef,
            receiptData(
                uid,
                "updateMarketplaceTransaction",
                result,
                FieldValue,
            ),
        );
        return result;
      }
      if (!listingSnapshot.exists) {
        throw new CommandPolicyError(
            "not-found",
            "The transaction listing is unavailable.",
        );
      }
      if (action === "cancel") {
        const committedDispatch = dispatchJobs.docs.find((document) =>
          ["awarded", "accepted", "scheduled", "in_transit"]
              .includes(String(document.data().status || "")),
        );
        if (committedDispatch) {
          throw new CommandPolicyError(
              "failed-precondition",
              "Open a dispute because the associated Dispatch job is committed.",
          );
        }
      }
      const revision = currentRevision + 1;
      const baseValues = sale || {
        offerId,
        listingId: offer.listingId,
        conversationId: offer.conversationId || null,
        buyerUid: offer.buyerUid,
        sellerUid: offer.sellerUid,
        agreedUnitPrice: Number(offer.offeredUnitPrice || 0),
        agreedQuantity: Number(offer.requestedQuantity || 0),
        agreedTotal: Number(offer.offeredTotal || 0),
        currency: offer.currency || "CAD",
        priceBasis: offer.priceBasis || "",
        purchaseDate: offer.purchaseDate || null,
        moneyTransferDate: offer.moneyTransferDate || null,
        truckingDate: offer.truckingDate || null,
        truckingPlan: offer.truckingPlan || "not_specified",
        dispatchRequested: offer.dispatchRequested === true,
        createdAt: FieldValue.serverTimestamp(),
      };
      const updateValues = {
        ...baseValues,
        status: transition.status,
        buyerConfirmed: transition.buyerConfirmed,
        sellerConfirmed: transition.sellerConfirmed,
        revision,
        lastAction: action,
        lastActionByUid: uid,
        ...(transition.reason ? {reason: transition.reason} : {}),
        ...(action === "confirm_completion" ? {
          [`${transition.actorRole}ConfirmedAt`]:
            FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.status === "completed" ? {
          completedAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(transition.status === "cancelled" ? {
          cancelledAt: FieldValue.serverTimestamp(),
          cancelledByUid: uid,
        } : {}),
        ...(transition.status === "disputed" ? {
          disputedAt: FieldValue.serverTimestamp(),
          disputedByUid: uid,
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (saleSnapshot.exists) {
        transaction.update(saleRef, updateValues);
      } else {
        transaction.create(saleRef, updateValues);
      }
      transaction.create(
          saleRef.collection("revisions").doc(String(revision)),
          {
            status: transition.status,
            buyerConfirmed: transition.buyerConfirmed,
            sellerConfirmed: transition.sellerConfirmed,
            event: action,
            actorUid: uid,
            ...(transition.reason ? {reason: transition.reason} : {}),
            revision,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.update(offerRef, {
        status: transition.status === "completed" ?
          "completed" :
          transition.status === "cancelled" ?
            "cancelled" :
            transition.status === "disputed" ? "disputed" : "accepted",
        transactionStatus: transition.status,
        updatedAt: FieldValue.serverTimestamp(),
      });
      if (transition.status === "completed") {
        transaction.update(listingRef, {
          status: "sold",
          saleStatus: "completed",
          soldAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else if (transition.status === "cancelled") {
        transaction.update(listingRef, {
          status: "active",
          saleStatus: "available",
          acceptedOfferId: FieldValue.delete(),
          acceptedBuyerUid: FieldValue.delete(),
          offerAcceptedAt: FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        for (const dispatchJob of dispatchJobs.docs) {
          const job = dispatchJob.data();
          if (!["draft", "open"].includes(String(job.status || ""))) continue;
          const dispatchRevision = Number(job.revision || 1) + 1;
          transaction.update(dispatchJob.ref, {
            status: "cancelled",
            cancelledReason: "marketplace_transaction_cancelled",
            revision: dispatchRevision,
            updatedAt: FieldValue.serverTimestamp(),
          });
          transaction.create(
              dispatchJob.ref.collection("revisions")
                  .doc(String(dispatchRevision)),
              {
                event: "request_cancelled",
                actorUid: uid,
                status: "cancelled",
                reason: "marketplace_transaction_cancelled",
                revision: dispatchRevision,
                createdAt: FieldValue.serverTimestamp(),
              },
          );
        }
      } else if (transition.status === "disputed") {
        transaction.update(listingRef, {
          status: "pending_sale",
          saleStatus: "disputed",
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(db.collection("transaction_disputes").doc(offerId), {
          offerId,
          listingId: offer.listingId,
          buyerUid: offer.buyerUid,
          sellerUid: offer.sellerUid,
          openedByUid: uid,
          reason: transition.reason,
          status: "open",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      } else {
        transaction.update(listingRef, {
          saleStatus: transition.status,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      const recipientUid = uid === offer.buyerUid ?
        offer.sellerUid :
        offer.buyerUid;
      transaction.set(
          db.collection("users").doc(recipientUid)
              .collection("notifications").doc(receiptRef.id),
          {
            recipientUid,
            actorUid: uid,
            type: "transaction",
            offerId,
            listingId: offer.listingId,
            conversationId: offer.conversationId || null,
            title: transition.status === "completed" ?
              "Marketplace transaction completed" :
              transition.status === "cancelled" ?
                "Marketplace transaction cancelled" :
                transition.status === "disputed" ?
                  "Marketplace transaction disputed" :
                  "Transaction confirmation updated",
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(
          receiptRef,
          receiptData(
              uid,
              "updateMarketplaceTransaction",
              result,
              FieldValue,
          ),
      );
      return result;
    });
      },
  );

  return {
    acceptAuctionBidBelowReserve,
    acceptMarketplaceOffer,
    buyAuctionNow,
    cleanupExpiredMarketplaceListingDrafts,
    convertMarketplaceListingToAuction,
    createMarketplaceListingDraft,
    createMarketplaceListing,
    createMarketplaceOffer,
    finalizeAuction,
    manageWantedMatch,
    placeAuctionBid,
    relistMarketplaceListing,
    setMarketplaceListingSaved,
    publishMarketplaceListingDraft,
    transitionMarketplaceListing,
    updateAuctionTransaction,
    updateMarketplaceTransaction,
    updateMarketplaceListingDetails,
    updateMarketplaceListingDraftMedia,
    updateMarketplaceListingMedia,
    withdrawAuctionBid,
    finalizeAuctionRecord,
  };
}

module.exports = {createMarketplaceCommands};
