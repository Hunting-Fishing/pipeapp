const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
admin.initializeApp();

exports.monitorTimedAuctions = onSchedule("every 15 minutes", async () => {
  const now = admin.firestore.Timestamp.now();
  const endingCutoff = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + 24 * 60 * 60 * 1000,
  );
  const auctions = await admin.firestore().collection("public_listings")
    .where("transactionType", "==", "Auction").get();
  const writer = admin.firestore().bulkWriter();

  for (const document of auctions.docs) {
    const auction = document.data();
    const end = auction.auctionEndAt;
    if (!end || auction.auctionStatus === "bought_now" ||
        auction.auctionStatus === "accepted_below_reserve") continue;

    if (end.toMillis() <= now.toMillis() && auction.finalizedAt == null) {
      const current = Number(auction.currentBid || 0);
      const reserve = Number(auction.reservePrice || 0);
      const reserveMet = reserve <= 0 || current >= reserve;
      const won = current > 0 && reserveMet && auction.highBidderUid;
      writer.update(document.ref, {
        auctionStatus: won ? "won" : "ended",
        reserveMet,
        finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      writer.set(admin.firestore().collection("users").doc(auction.sellerUid)
        .collection("notifications").doc(), {
        type: "offer",
        title: won ? "Your auction has a winning bidder" :
          (current > 0 ? "Auction ended below reserve" : "Auction ended with no bids"),
        listingId: document.id,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (won) {
        writer.set(admin.firestore().collection("users").doc(auction.highBidderUid)
          .collection("notifications").doc(), {
          type: "offer",
          title: "You won the auction",
          listingId: document.id,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else if (auction.notifyAuctionEnding !== false &&
        auction.endingNotificationSentAt == null &&
        end.toMillis() <= endingCutoff.toMillis()) {
      writer.update(document.ref, {
        endingNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      writer.set(admin.firestore().collection("users").doc(auction.sellerUid)
        .collection("notifications").doc(), {
        type: "offer",
        title: "Your auction ends within 24 hours",
        listingId: document.id,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
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

exports.onDispatchBidCreated = onDocumentCreated(
  "dispatch_bids/{bidId}",
  async (event) => {
    const bid = event.data.data();
    const job = await admin.firestore().collection("dispatch_jobs")
      .doc(bid.jobId).get();
    if (!job.exists) return null;
    const ownerUid = job.data().createdByUid;
    await admin.firestore().collection("users").doc(ownerUid)
      .collection("notifications").add({
        type: "dispatch_bid",
        title: "New carrier bid",
        body: `${bid.carrierName || "A carrier"} bid ` +
          `$${Number(bid.amount || 0).toLocaleString("en-CA",
            { minimumFractionDigits: 2 })} on your dispatch job.`,
        dispatchJobId: bid.jobId,
        dispatchBidId: event.params.bidId,
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

exports.onDispatchJobAwarded = onDocumentWritten(
  "dispatch_jobs/{jobId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    if (before.status === "awarded" || after.status !== "awarded" ||
        !after.awardedCarrierUid) return null;
    await admin.firestore().collection("users").doc(after.awardedCarrierUid)
      .collection("notifications").add({
        type: "dispatch_award",
        title: "Your trucking bid was selected",
        body: `You were selected for ${after.title || "a dispatch job"}.`,
        dispatchJobId: event.params.jobId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
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
