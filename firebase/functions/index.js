const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall } = require("firebase-functions/v2/https");
const { createAdminRuntime } = require("./admin_runtime");
const { createAccountCommands } = require("./account_commands");
const { cleanupExpiredRateLimits } = require("./abuse_rate_limit");
const { protectedCallableOptions } = require("./app_check_config");
const { createDispatchCommands } = require("./dispatch_commands");
const { createMarketplaceCommands } = require("./marketplace_commands");
const admin = createAdminRuntime();

const accountCommands = createAccountCommands(admin);
const dispatchCommands = createDispatchCommands(admin);
const marketplaceCommands = createMarketplaceCommands(admin);
exports.syncAccountVerification = onCall(
  protectedCallableOptions,
  accountCommands.syncAccountVerification,
);
exports.cleanupExpiredSecurityRateLimits = onSchedule(
  "every 24 hours",
  async () => cleanupExpiredRateLimits(admin),
);
exports.createDispatchJob = onCall(
  protectedCallableOptions,
  dispatchCommands.createDispatchJob,
);
exports.updateDispatchJob = onCall(
  protectedCallableOptions,
  dispatchCommands.updateDispatchJob,
);
exports.publishDispatchJob = onCall(
  protectedCallableOptions,
  dispatchCommands.publishDispatchJob,
);
exports.submitDispatchQuote = onCall(
  protectedCallableOptions,
  dispatchCommands.submitDispatchQuote,
);
exports.awardDispatchQuote = onCall(
  protectedCallableOptions,
  dispatchCommands.awardDispatchQuote,
);
exports.updateDispatchTransaction = onCall(
  protectedCallableOptions,
  dispatchCommands.updateDispatchTransaction,
);
exports.placeAuctionBid = onCall(
  protectedCallableOptions,
  marketplaceCommands.placeAuctionBid,
);
exports.buyAuctionNow = onCall(
  protectedCallableOptions,
  marketplaceCommands.buyAuctionNow,
);
exports.acceptAuctionBidBelowReserve = onCall(
  protectedCallableOptions,
  marketplaceCommands.acceptAuctionBidBelowReserve,
);
exports.withdrawAuctionBid = onCall(
  protectedCallableOptions,
  marketplaceCommands.withdrawAuctionBid,
);
exports.createMarketplaceOffer = onCall(
  protectedCallableOptions,
  marketplaceCommands.createMarketplaceOffer,
);
exports.acceptMarketplaceOffer = onCall(
  protectedCallableOptions,
  marketplaceCommands.acceptMarketplaceOffer,
);
exports.createMarketplaceListing = onCall(
  protectedCallableOptions,
  marketplaceCommands.createMarketplaceListing,
);
exports.convertMarketplaceListingToAuction = onCall(
  protectedCallableOptions,
  marketplaceCommands.convertMarketplaceListingToAuction,
);
exports.updateMarketplaceListingMedia = onCall(
  protectedCallableOptions,
  marketplaceCommands.updateMarketplaceListingMedia,
);
exports.updateMarketplaceListingDetails = onCall(
  protectedCallableOptions,
  marketplaceCommands.updateMarketplaceListingDetails,
);
exports.transitionMarketplaceListing = onCall(
  protectedCallableOptions,
  marketplaceCommands.transitionMarketplaceListing,
);
exports.relistMarketplaceListing = onCall(
  protectedCallableOptions,
  marketplaceCommands.relistMarketplaceListing,
);
exports.setMarketplaceListingSaved = onCall(
  protectedCallableOptions,
  marketplaceCommands.setMarketplaceListingSaved,
);
exports.updateMarketplaceTransaction = onCall(
  protectedCallableOptions,
  marketplaceCommands.updateMarketplaceTransaction,
);
exports.finalizeAuction = onCall(
  protectedCallableOptions,
  marketplaceCommands.finalizeAuction,
);
exports.updateAuctionTransaction = onCall(
  protectedCallableOptions,
  marketplaceCommands.updateAuctionTransaction,
);

exports.monitorTimedAuctions = onSchedule("every 15 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const endingCutoff = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 24 * 60 * 60 * 1000,
  );
  const base = admin.firestore().collection("public_listings")
    .where("transactionType", "==", "Auction")
    .where("status", "==", "active");
  const expired = await base.where("auctionEndAt", "<=", now).limit(100).get();
  for (const document of expired.docs) {
    if (!["live", "scheduled"].includes(document.data().auctionStatus)) continue;
    try {
      await marketplaceCommands.finalizeAuctionRecord(document.id);
    } catch (error) {
      console.error("Scheduled auction finalization failed", {
        listingId: document.id,
        error,
      });
    }
  }

  const endingSoon = await base
    .where("auctionEndAt", ">", now)
    .where("auctionEndAt", "<=", endingCutoff)
    .limit(100)
    .get();
  const writer = admin.firestore().bulkWriter();
  for (const document of endingSoon.docs) {
    const auction = document.data();
    if (auction.notifyAuctionEnding === false ||
        auction.endingNotificationSentAt != null ||
        !["live", "scheduled"].includes(auction.auctionStatus)) continue;
    writer.update(document.ref, {
      endingNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    writer.set(admin.firestore().collection("users").doc(auction.sellerUid)
      .collection("notifications").doc(), {
      recipientUid: auction.sellerUid,
      actorUid: "auction_scheduler",
      type: "auction",
      title: "Your auction ends within 24 hours",
      listingId: document.id,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  await writer.close();
});

// Creates in-app alerts for buyers who saved a seller profile and enabled
// new-listing notifications. Push/email delivery can be added later without
// changing the follow model used by the Flutter app.
exports.onPublicListingCreated = onDocumentCreated(
  "public_listings/{listingId}",
  async (event) => {
    const listing = event.data.data();
    const sellerUid = listing.sellerUid;
    if (!sellerUid) return null;

    const followers = await admin.firestore()
      .collectionGroup("followed_sellers")
      .where("sellerUid", "==", sellerUid)
      .where("notifyNewListings", "==", true)
      .get();

    const writer = admin.firestore().bulkWriter();
    followers.docs.forEach((follow) => {
      const userRef = follow.ref.parent.parent;
      if (!userRef) return;
      const notification = userRef.collection("notifications").doc();
      writer.set(notification, {
        type: "seller_new_listing",
        title: listing.title || "New marketplace listing",
        body: `${listing.sellerName || "A saved seller"} added a new listing.`,
        listingId: event.params.listingId,
        sellerUid,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const searchable = [
      listing.title,
      listing.category,
      listing.productType,
      listing.brand,
      listing.model,
      listing.pipeSize,
      listing.publicLocationName,
      listing.nearestTown,
    ].filter(Boolean).join(" ").toLowerCase();
    const tokens = [...new Set(searchable.split(/[^a-z0-9/]+/)
      .filter((word) => word.length > 1))].slice(0, 10);
    if (tokens.length) {
      const watches = await admin.firestore()
        .collectionGroup("watch_keywords")
        .where("keywords", "array-contains-any", tokens)
        .get();
      const notifiedUsers = new Set();
      watches.docs.forEach((watch) => {
        if (watch.data().enabled === false) return;
        const userRef = watch.ref.parent.parent;
        if (!userRef || userRef.id === sellerUid || notifiedUsers.has(userRef.id)) return;
        notifiedUsers.add(userRef.id);
        writer.set(userRef.collection("notifications").doc(), {
          type: "new_listing_match",
          title: listing.title || "New matching listing",
          body: `Matches your watch: ${watch.data().label || tokens.join(" ")}`,
          listingId: event.params.listingId,
          watchId: watch.id,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    }
    await writer.close();
    return null;
  },
);

// Reserve amounts are seller-only. This guard also cleans legacy clients that
// still attempt to place reserve fields in the publicly readable document.
exports.protectAuctionReserve = onDocumentWritten(
  "public_listings/{listingId}",
  async (event) => {
    if (!event.data.after.exists) return null;
    const listing = event.data.after.data();
    if (
      listing.transactionType !== "Auction" ||
      (!Object.prototype.hasOwnProperty.call(listing, "reservePrice") &&
       !Object.prototype.hasOwnProperty.call(listing, "reserveTotal"))
    ) {
      return null;
    }

    const listingRef = event.data.after.ref;
    const privateRef = admin.firestore()
      .collection("auction_private")
      .doc(event.params.listingId);
    await admin.firestore().runTransaction(async (transaction) => {
      const current = await transaction.get(listingRef);
      if (!current.exists) return;
      const data = current.data();
      if (
        data.transactionType !== "Auction" ||
        (!Object.prototype.hasOwnProperty.call(data, "reservePrice") &&
         !Object.prototype.hasOwnProperty.call(data, "reserveTotal"))
      ) {
        return;
      }
      const reservePrice = Number(data.reservePrice);
      if (Number.isFinite(reservePrice) && reservePrice > 0) {
        transaction.set(privateRef, {
          ownerUid: data.sellerUid,
          reservePrice,
          ...(Number.isFinite(Number(data.reserveTotal)) ? {
            reserveTotal: Number(data.reserveTotal),
          } : {}),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      transaction.update(listingRef, {
        reservePrice: admin.firestore.FieldValue.delete(),
        reserveTotal: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    return null;
  },
);

exports.onUserScoreEventCreated = onDocumentCreated(
  "user_score_events/{eventId}",
  async (event) => {
    const change = event.data.data();
    if (!change.userUid) return null;
    await admin.firestore().collection("users").doc(change.userUid)
      .collection("notifications").add({
        type: "score_change",
        title: `User Score ${Number(change.change || 0) >= 0 ? "increased" : "decreased"}`,
        body: change.reason || "A reviewed score decision was recorded.",
        scoreEventId: event.params.eventId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    return null;
  },
);

// Keeps Firebase Auth authorization claims aligned with the account type in
// Firestore. The Firestore field remains queryable for account and regional
// reporting; the signed claim can be trusted by backend security checks.
exports.syncUserAccountRole = onDocumentWritten("users/{uid}", async (event) => {
  if (!event.data.after.exists) return null;
  const after = event.data.after.data();
  const before = event.data.before.exists ? event.data.before.data() : {};
  const accountType = after.accountType;
  if (!["personal", "business"].includes(accountType)) return null;
  if (after.roleVersion === 1 && before.accountType === accountType) return null;

  const user = await admin.auth().getUser(event.params.uid);
  await admin.auth().setCustomUserClaims(event.params.uid, {
    ...(user.customClaims || {}),
    accountType,
    personal: accountType === "personal",
    business: accountType === "business",
    admin: (user.email || "").toLowerCase() === "jordilwbailey@gmail.com",
  });
  await event.data.after.ref.set({
    roleVersion: 1,
    roleSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  return null;
});

exports.onTagRequestCreated = onDocumentCreated(
  "tag_requests/{requestId}",
  async (event) => {
    const request = event.data.data();
    const developer = await admin.auth().getUserByEmail("jordilwbailey@gmail.com");
    await admin.firestore()
      .collection("users")
      .doc(developer.uid)
      .collection("notifications")
      .add({
        type: "tag_approval_request",
        title: "New marketplace tag request",
        body: `${request.requestedByEmail || "A user"} requested “${request.label || "Untitled tag"}”.`,
        tagRequestId: event.params.requestId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    return null;
  },
);

exports.onCatalogSuggestionCreated = onDocumentCreated(
  "catalog_suggestions/{suggestionId}",
  async (event) => {
    const suggestion = event.data.data();
    const developer = await admin.auth()
      .getUserByEmail("jordilwbailey@gmail.com");
    await admin.firestore()
      .collection("users")
      .doc(developer.uid)
      .collection("notifications")
      .add({
        type: "catalog_suggestion",
        title: "New marketplace catalog suggestion",
        body: `${suggestion.requestedByEmail || "A user"} suggested ` +
          `“${suggestion.value || "Untitled"}” for ` +
          `${suggestion.field || "the marketplace catalog"}.`,
        catalogSuggestionId: event.params.suggestionId,
        listingId: suggestion.listingId || null,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    return null;
  },
);

exports.onDispatchSignupCreated = onDocumentCreated(
  "dispatch_carriers/{userId}",
  async (event) => {
    const signup = event.data.data();
    const userId = event.params.userId;
    const notification = {
      type: "dispatch_signup",
      title: "Your Dispatch account is active",
      body: `Welcome ${signup.operatingName || "to Dispatch"}. Add your fleet vehicles to begin bidding on trucking work.`,
      dispatchAccountUid: userId,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const writes = [
      admin.firestore().collection("users").doc(userId)
        .collection("notifications").add(notification),
    ];
    try {
      const developer = await admin.auth()
        .getUserByEmail("jordilwbailey@gmail.com");
      writes.push(admin.firestore().collection("users").doc(developer.uid)
        .collection("notifications").add({
          type: "dispatch_signup",
          title: "New Dispatch provider signup",
          body: `${signup.operatingName || "A provider"} joined Dispatch in ${signup.serviceAreaLabel || "an unspecified service area"}.`,
          dispatchAccountUid: userId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }));
    } catch (error) {
      console.warn("Dispatch admin notification skipped", error);
    }
    await Promise.all(writes);
    return null;
  },
);

// Aggregates immutable marketplace events into fast counters displayed to the
// seller. The event collection remains the audit trail and can be re-counted.
exports.onListingEventCreated = onDocumentCreated(
  "listing_events/{eventId}",
  async (event) => {
    const data = event.data.data();
    const fields = {
      view: ["viewCount", 1],
      save: ["saveCount", 1],
      unsave: ["saveCount", -1],
      share: ["shareCount", 1],
      message_start: ["messageCount", 1],
      offer: ["offerCount", 1],
    };
    const target = fields[data.type];
    if (!data.listingId || !target) return null;
    await admin.firestore().collection("public_listings")
      .doc(data.listingId)
      .set({ [target[0]]: admin.firestore.FieldValue.increment(target[1]) },
        { merge: true });
    return null;
  },
);

exports.onConversationCreated = onDocumentCreated(
  "conversations/{conversationId}",
  async (event) => {
    const data = event.data.data();
    if (!data.listingId) return null;
    await admin.firestore().collection("public_listings")
      .doc(data.listingId)
      .set({ messageCount: admin.firestore.FieldValue.increment(1) },
        { merge: true });
    return null;
  },
);

exports.onOfferCreated = onDocumentCreated("offers/{offerId}", async (event) => {
  const data = event.data.data();
  if (!data.listingId) return null;
  const writes = [
    admin.firestore().collection("public_listings")
      .doc(data.listingId)
      .set({ offerCount: admin.firestore.FieldValue.increment(1) },
        { merge: true }),
  ];
  if (data.buyerUid) {
    const difference = Number(data.differenceAmount || 0);
    const requested = Number(data.requestedQuantity || 0);
    const available = Number(data.availableQuantityAtOffer || 0);
    writes.push(admin.firestore().collection("buyer_offer_profiles")
      .doc(data.buyerUid)
      .set({
        offerCount: admin.firestore.FieldValue.increment(1),
        offeredTotal: admin.firestore.FieldValue.increment(
          Number(data.offeredTotal || 0)),
        askingTotalCompared: admin.firestore.FieldValue.increment(
          Number(data.askingTotal || 0)),
        belowAskingCount: admin.firestore.FieldValue.increment(
          difference < 0 ? 1 : 0),
        atOrAboveAskingCount: admin.firestore.FieldValue.increment(
          difference >= 0 ? 1 : 0),
        partialQuantityCount: admin.firestore.FieldValue.increment(
          available > 0 && requested < available ? 1 : 0),
        lastOfferAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true }));
  }
  await Promise.all(writes);
  return null;
});

// Automated moderation creates review cases only. It never removes content or
// penalizes a user without an administrator's decision.
exports.onListingMediaModeration = onDocumentWritten(
  "public_listings/{listingId}",
  async (event) => {
    if (!event.data.after.exists) return null;
    const listing = event.data.after.data();
    const before = event.data.before.exists ? event.data.before.data() : {};
    const hashes = [...new Set(listing.imageHashes || [])].slice(0, 12);
    if (!listing.sellerUid || !hashes.length ||
        JSON.stringify(hashes) === JSON.stringify(before.imageHashes || [])) {
      return null;
    }
    const matches = await admin.firestore().collection("public_listings")
      .where("sellerUid", "==", listing.sellerUid)
      .where("imageHashes", "array-contains-any", hashes)
      .get();
    const duplicateIds = matches.docs
      .filter((doc) => doc.id !== event.params.listingId)
      .map((doc) => doc.id);
    if (!duplicateIds.length) return null;
    const caseId = `duplicate_media_${event.params.listingId}`;
    await admin.firestore().collection("trust_reports").doc(caseId).set({
      reporterUid: "automated-moderation",
      reportedUid: listing.sellerUid,
      targetType: "listing",
      listingId: event.params.listingId,
      relatedListingIds: duplicateIds,
      matchedImageHashes: hashes.filter((hash) => matches.docs.some((doc) =>
        doc.id !== event.params.listingId &&
        (doc.data().imageHashes || []).includes(hash))),
      reason: "duplicate_listing_media",
      reasonLabel: "Exact photo reused across this seller's listings",
      details: `Exact file matches were found in ${duplicateIds.length} other listing(s).`,
      attachments: [],
      attachmentCount: 0,
      source: "automated",
      detectionMethod: "sha256_exact_file_match",
      confidence: 1,
      priority: "high",
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return null;
  },
);

exports.onMessageModeration = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const text = String(message.text || "").trim();
    if (!message.senderUid || !text) return null;

    // This is a conservative pre-screen. Administrators see the signal and
    // context before taking action; ambiguous language is never auto-punished.
    const signals = [];
    const normalized = text.toLowerCase();
    if (/\b(wire|transfer|send)\b.{0,35}\b(crypto|bitcoin|gift card|western union)\b/i.test(text) ||
        /\bpay\b.{0,30}\boff[\s-]?platform\b/i.test(text)) {
      signals.push("possible_payment_fraud");
    }
    if (/\b(kill|hurt|attack|find you)\b.{0,30}\b(you|your|them)\b/i.test(text)) {
      signals.push("possible_threat");
    }
    if (/\b(race|racial|ethnic|ethnicity|religion|nationality)\b.{0,40}\b(inferior|filthy|vermin|hate|exclude|ban)\b/i.test(text) ||
        /\b(inferior|filthy|vermin|hate)\b.{0,40}\b(race|racial|ethnic|religion|nationality)\b/i.test(text)) {
      signals.push("possible_hate_or_racist_content");
    }
    const vulgarTerms = ["fuck", "cunt", "bitch", "piece of shit"];
    if (vulgarTerms.some((term) => normalized.includes(term))) {
      signals.push("vulgar_or_harassing_content");
    }
    if (!signals.length) return null;

    const conversation = await admin.firestore().collection("conversations")
      .doc(event.params.conversationId).get();
    const members = conversation.data()?.memberUids || [];
    const reportedUid = message.senderUid;
    await admin.firestore().collection("trust_reports")
      .doc(`message_signal_${event.params.messageId}`).set({
        reporterUid: "automated-moderation",
        reportedUid,
        targetType: "message",
        conversationId: event.params.conversationId,
        messageId: event.params.messageId,
        participantUids: members,
        reason: signals[0],
        reasonLabel: "Automated message safety signal",
        details: `The safety pre-screen detected: ${signals.join(", ")}.`,
        moderationSignals: signals,
        attachments: [],
        attachmentCount: 0,
        source: "automated",
        detectionMethod: "conservative_text_safety_prescreen",
        priority: signals.includes("possible_threat") ? "high" : "normal",
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    return null;
  },
);

exports.onWeightSuggestionCreated = onDocumentCreated(
  "weight_suggestions/{suggestionId}",
  async (event) => {
    const suggestion = event.data.data();
    const administrators = await admin.firestore().collection("users")
      .where("email", "==", "jordilwbailey@gmail.com").limit(1).get();
    if (administrators.empty) return null;
    const adminUser = administrators.docs[0];
    await adminUser.ref.collection("notifications").add({
      type: "catalog_suggestion",
      title: "New shipping-weight correction to review",
      body: `${suggestion.listingTitle || "Listing"} • ${suggestion.suggestedWeightKg} kg`,
      suggestionId: event.params.suggestionId,
      listingId: suggestion.listingId || null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  },
);
