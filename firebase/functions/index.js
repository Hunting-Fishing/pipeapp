const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall } = require("firebase-functions/v2/https");
const { createAdminRuntime } = require("./admin_runtime");
const {
  createAdministratorRoleCommands,
} = require("./administrator_role_commands");
const { createAccountCommands } = require("./account_commands");
const {
  createAccountVerificationCommands,
} = require("./account_verification_commands");
const { createAccountPrivacyCommands } = require("./account_privacy_commands");
const { cleanupExpiredRateLimits } = require("./abuse_rate_limit");
const { protectedCallableOptions } = require("./app_check_config");
const {
  cleanupExpiredMediaUploadAuthorizations,
  createCommunicationCommands,
} = require("./communication_commands");
const { createDispatchCommands } = require("./dispatch_commands");
const { createDispatchDirectoryProjection } = require("./dispatch_directory_projection");
const {
  createDispatchCredentialMonitor,
} = require("./dispatch_credential_monitor");
const { createMarketplaceCommands } = require("./marketplace_commands");
const {
  createMarketplaceListingLifecycle,
} = require("./marketplace_listing_lifecycle");
const {
  createMarketplaceListingInsights,
} = require("./marketplace_listing_insights");
const { createNotificationDelivery } = require("./notification_delivery");
const { createModerationCommands } = require("./moderation_commands");
const {
  createMarketplaceUserBlockCommands,
} = require("./marketplace_user_block_commands");
const {
  classifyMessageSafety,
  duplicateListingMediaEvidence,
  duplicateListingMediaItems,
  messageContentEvidence,
  validImageHashes,
} = require("./moderation_signal_policy");
const {
  createPolicyAcceptanceCommands,
} = require("./policy_acceptance_commands");
const { createSupportCommands } = require("./support_commands");
const {createWantedMatching} = require("./wanted_matching");
const admin = createAdminRuntime();

async function notifyActiveAdministrators(notification) {
  const notificationId = String(notification.notificationId || "").trim();
  const payload = {...notification};
  delete payload.notificationId;
  const roles = await admin.firestore().collection("administrator_roles")
    .where("active", "==", true)
    .get();
  if (roles.empty) {
    console.warn("Administrator notification skipped: no active roles");
    return;
  }
  await Promise.all(roles.docs.map((role) => {
    const collection = admin.firestore().collection("users").doc(role.id)
      .collection("notifications");
    const reference = notificationId ?
      collection.doc(notificationId) : collection.doc();
    return reference.set({
      ...payload,
      recipientUid: role.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }));
}

async function createAutomatedReviewCase(reportId, report) {
  const reference = admin.firestore().collection("trust_reports").doc(reportId);
  return admin.firestore().runTransaction(async (transaction) => {
    const existing = await transaction.get(reference);
    if (existing.exists) return false;
    transaction.create(reference, {
      ...report,
      source: "automated",
      humanReviewRequired: true,
      automaticEnforcement: false,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return true;
  });
}

const accountCommands = createAccountCommands(admin);
const administratorRoleCommands = createAdministratorRoleCommands(admin);
const accountPrivacyCommands = createAccountPrivacyCommands(admin);
const accountVerificationCommands = createAccountVerificationCommands(admin);
const communicationCommands = createCommunicationCommands(admin);
const dispatchCommands = createDispatchCommands(admin);
const dispatchDirectoryProjection = createDispatchDirectoryProjection(admin);
const dispatchCredentialMonitor = createDispatchCredentialMonitor(admin);
const marketplaceCommands = createMarketplaceCommands(admin);
const marketplaceUserBlockCommands = createMarketplaceUserBlockCommands(admin);
const marketplaceListingLifecycle = createMarketplaceListingLifecycle(admin);
const marketplaceListingInsights = createMarketplaceListingInsights(admin);
const moderationCommands = createModerationCommands(admin);
const notificationDelivery = createNotificationDelivery(admin);
const policyAcceptanceCommands = createPolicyAcceptanceCommands(admin);
const supportCommands = createSupportCommands(admin);
const wantedMatching = createWantedMatching(admin);
exports.syncDispatchDirectoryFromPublicProfile = onDocumentWritten(
  {
    document: "public_business_profiles/{companyId}",
    retry: true,
  },
  async (event) => dispatchDirectoryProjection.syncCompany(event.params.companyId),
);
exports.syncDispatchDirectoryFromCarrierStatus = onDocumentWritten(
  {
    document: "dispatch_carriers/{companyId}",
    retry: true,
  },
  async (event) => dispatchDirectoryProjection.syncCompany(event.params.companyId),
);
exports.listAdministratorRoles = onCall(
  protectedCallableOptions,
  administratorRoleCommands.listAdministratorRoles,
);
exports.manageAdministratorRole = onCall(
  protectedCallableOptions,
  administratorRoleCommands.manageAdministratorRole,
);
exports.registerNotificationEndpoint = onCall(
  protectedCallableOptions,
  notificationDelivery.registerNotificationEndpoint,
);
exports.unregisterNotificationEndpoint = onCall(
  protectedCallableOptions,
  notificationDelivery.unregisterNotificationEndpoint,
);
exports.syncDispatchCredentialReminderSchedule = onCall(
  protectedCallableOptions,
  dispatchCredentialMonitor.syncDispatchCredentialReminderSchedule,
);
exports.resolveNotificationDeliveryFailure = onCall(
  protectedCallableOptions,
  notificationDelivery.resolveNotificationDeliveryFailure,
);
exports.onUserNotificationCreated = onDocumentCreated(
  {
    document: "users/{uid}/notifications/{notificationId}",
    retry: true,
  },
  async (event) => notificationDelivery.deliverNotification({
    uid: event.params.uid,
    notificationId: event.params.notificationId,
    notification: event.data && event.data.data(),
  }),
);
exports.syncAccountVerification = onCall(
  protectedCallableOptions,
  accountCommands.syncAccountVerification,
);
exports.submitAccountVerification = onCall(
  protectedCallableOptions,
  accountVerificationCommands.submitAccountVerification,
);
exports.reviewAccountVerification = onCall(
  protectedCallableOptions,
  accountVerificationCommands.reviewAccountVerification,
);
exports.requestAccountDataExport = onCall(
  protectedCallableOptions,
  accountPrivacyCommands.requestAccountDataExport,
);
exports.registerAccountDevice = onCall(
  protectedCallableOptions,
  accountPrivacyCommands.registerAccountDevice,
);
exports.revokeAccountSessions = onCall(
  protectedCallableOptions,
  accountPrivacyCommands.revokeAccountSessions,
);
exports.requestAccountDeletion = onCall(
  protectedCallableOptions,
  accountPrivacyCommands.requestAccountDeletion,
);
exports.cancelAccountDeletion = onCall(
  protectedCallableOptions,
  accountPrivacyCommands.cancelAccountDeletion,
);
exports.cleanupExpiredSecurityRateLimits = onSchedule(
  "every 24 hours",
  async () => cleanupExpiredRateLimits(admin),
);
exports.cleanupExpiredAccountExports = onSchedule(
  "every 24 hours",
  async () => accountPrivacyCommands.cleanupExpiredAccountExports(),
);
exports.cleanupStaleAccountDevices = onSchedule(
  "every 24 hours",
  async () => accountPrivacyCommands.cleanupStaleAccountDevices(),
);
exports.finalizeScheduledAccountDeletions = onSchedule(
  "every 24 hours",
  async () => accountPrivacyCommands.finalizeScheduledAccountDeletions(),
);
exports.cleanupExpiredMediaUploadAuthorizations = onSchedule(
  "every 24 hours",
  async () => cleanupExpiredMediaUploadAuthorizations(admin),
);
exports.cleanupExpiredMarketplaceListingDrafts = onSchedule(
  "every 24 hours",
  async () => marketplaceCommands.cleanupExpiredMarketplaceListingDrafts(),
);
exports.monitorDispatchCredentialReminders = onSchedule(
  "every 6 hours",
  async () => dispatchCredentialMonitor.monitorCredentialReminders(),
);
exports.monitorMarketplaceListingLifecycle = onSchedule(
  "every 1 hours",
  async () => {
    await marketplaceListingLifecycle.notifyExpiringListings();
    await marketplaceListingLifecycle.expireMarketplaceListings();
  },
);
exports.openMarketplaceConversation = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    communicationCommands.openMarketplaceConversation,
  ),
);
exports.openBusinessConversation = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    communicationCommands.openBusinessConversation,
  ),
);
exports.markMarketplaceConversationRead = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    communicationCommands.markMarketplaceConversationRead,
  ),
);
exports.authorizeMarketplaceUpload = onCall(
  protectedCallableOptions,
  communicationCommands.authorizeMarketplaceUpload,
);
exports.confirmMarketplaceUpload = onCall(
  protectedCallableOptions,
  communicationCommands.confirmMarketplaceUpload,
);
exports.readMarketplaceUserBlockStatus = onCall(
  protectedCallableOptions,
  marketplaceUserBlockCommands.readMarketplaceUserBlockStatus,
);
exports.setMarketplaceUserBlocked = onCall(
  protectedCallableOptions,
  marketplaceUserBlockCommands.setMarketplaceUserBlocked,
);
const sendMarketplaceMessageWithBlockGuard = async (request) => {
  await marketplaceUserBlockCommands.requireConversationMessagingAllowed(request);
  return communicationCommands.sendMarketplaceMessage(request);
};
exports.sendMarketplaceMessage = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    sendMarketplaceMessageWithBlockGuard,
  ),
);
exports.submitMarketplaceReport = onCall(
  protectedCallableOptions,
  communicationCommands.submitMarketplaceReport,
);
exports.reviewModerationReport = onCall(
  protectedCallableOptions,
  moderationCommands.reviewModerationReport,
);
exports.appealModerationDecision = onCall(
  protectedCallableOptions,
  moderationCommands.appealModerationDecision,
);
exports.reviewModerationAppeal = onCall(
  protectedCallableOptions,
  moderationCommands.reviewModerationAppeal,
);
exports.createSupportCase = onCall(
  protectedCallableOptions,
  supportCommands.createSupportCase,
);
exports.replySupportCase = onCall(
  protectedCallableOptions,
  supportCommands.replySupportCase,
);
exports.updateSupportCase = onCall(
  protectedCallableOptions,
  supportCommands.updateSupportCase,
);
exports.publishPolicyDocument = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.publishPolicyDocument,
);
exports.acceptRequiredPolicies = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.acceptRequiredPolicies,
);
exports.setPolicyEnforcement = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.setPolicyEnforcement,
);
exports.createDispatchJob = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.createDispatchJob,
  ),
);
exports.submitDispatchProviderApplication = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.submitDispatchProviderApplication,
  ),
);
exports.reviewDispatchProvider = onCall(
  protectedCallableOptions,
  dispatchCommands.reviewDispatchProvider,
);
exports.updateDispatchJob = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.updateDispatchJob,
  ),
);
exports.publishDispatchJob = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.publishDispatchJob,
  ),
);
exports.submitDispatchQuote = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.submitDispatchQuote,
  ),
);
exports.awardDispatchQuote = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.awardDispatchQuote,
  ),
);
exports.updateDispatchTransaction = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    dispatchCommands.updateDispatchTransaction,
  ),
);
exports.placeAuctionBid = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.placeAuctionBid,
  ),
);
exports.buyAuctionNow = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.buyAuctionNow,
  ),
);
exports.acceptAuctionBidBelowReserve = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.acceptAuctionBidBelowReserve,
  ),
);
exports.withdrawAuctionBid = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.withdrawAuctionBid,
  ),
);
exports.createMarketplaceOffer = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.createMarketplaceOffer,
  ),
);
exports.acceptMarketplaceOffer = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.acceptMarketplaceOffer,
  ),
);
exports.createMarketplaceListing = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.createMarketplaceListing,
  ),
);
exports.createMarketplaceListingDraft = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.createMarketplaceListingDraft,
  ),
);
exports.publishMarketplaceListingDraft = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.publishMarketplaceListingDraft,
  ),
);
exports.convertMarketplaceListingToAuction = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.convertMarketplaceListingToAuction,
  ),
);
exports.updateMarketplaceListingMedia = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.updateMarketplaceListingMedia,
  ),
);
exports.updateMarketplaceListingDraftMedia = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.updateMarketplaceListingDraftMedia,
  ),
);
exports.updateMarketplaceListingDetails = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.updateMarketplaceListingDetails,
  ),
);
exports.transitionMarketplaceListing = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.transitionMarketplaceListing,
  ),
);
exports.manageWantedMatch = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.manageWantedMatch,
  ),
);
exports.relistMarketplaceListing = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.relistMarketplaceListing,
  ),
);
exports.renewMarketplaceListing = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceListingLifecycle.renewMarketplaceListing,
  ),
);
exports.getMarketplaceListingInsights = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceListingInsights.getMarketplaceListingInsights,
  ),
);
exports.setMarketplaceListingSaved = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.setMarketplaceListingSaved,
  ),
);
exports.updateMarketplaceTransaction = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.updateMarketplaceTransaction,
  ),
);
exports.finalizeAuction = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.finalizeAuction,
  ),
);
exports.updateAuctionTransaction = onCall(
  protectedCallableOptions,
  policyAcceptanceCommands.requireCurrentPolicies(
    marketplaceCommands.updateAuctionTransaction,
  ),
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
    await marketplaceListingLifecycle.initializeListing(
      event.params.listingId,
      listing,
    );
    const sellerUid = listing.sellerUid;
    if (!sellerUid) return null;

    const followers = await admin.firestore()
      .collectionGroup("followed_sellers")
      .where("sellerUid", "==", sellerUid)
      .where("notifyNewListings", "==", true)
      .limit(500)
      .get();

    const writer = admin.firestore().bulkWriter();
    followers.docs.forEach((follow) => {
      const userRef = follow.ref.parent.parent;
      if (!userRef) return;
      const notification = userRef.collection("notifications")
        .doc(`seller-${event.params.listingId}`);
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
        .limit(500)
        .get();
      const notifiedUsers = new Set();
      watches.docs.forEach((watch) => {
        if (watch.data().enabled === false) return;
        const userRef = watch.ref.parent.parent;
        if (!userRef || userRef.id === sellerUid || notifiedUsers.has(userRef.id)) return;
        notifiedUsers.add(userRef.id);
        writer.set(userRef.collection("notifications")
          .doc(`watch-${event.params.listingId}`), {
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
    const wantedResult = await wantedMatching.processListingCreated(
        event.params.listingId,
        listing,
    );
    console.info("Wanted matching completed", {
      listingId: event.params.listingId,
      ...wantedResult,
    });
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
    await notifyActiveAdministrators({
      type: "tag_approval_request",
      title: "New marketplace tag request",
      body: `${request.requestedByEmail || "A user"} requested “${request.label || "Untitled tag"}”.`,
      tagRequestId: event.params.requestId,
      read: false,
    });
    return null;
  },
);

exports.onCatalogSuggestionCreated = onDocumentCreated(
  "catalog_suggestions/{suggestionId}",
  async (event) => {
    const suggestion = event.data.data();
    await notifyActiveAdministrators({
      type: "catalog_suggestion",
      title: "New marketplace catalog suggestion",
      body: `${suggestion.requestedByEmail || "A user"} suggested ` +
        `“${suggestion.value || "Untitled"}” for ` +
        `${suggestion.field || "the marketplace catalog"}.`,
      catalogSuggestionId: event.params.suggestionId,
      listingId: suggestion.listingId || null,
      read: false,
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
    await Promise.all([
      admin.firestore().collection("users").doc(userId)
        .collection("notifications").add(notification),
      notifyActiveAdministrators({
        type: "dispatch_signup",
        title: "New Dispatch provider signup",
        body: `${signup.operatingName || "A provider"} joined Dispatch in ${signup.serviceAreaLabel || "an unspecified service area"}.`,
        dispatchAccountUid: userId,
        read: false,
      }),
    ]);
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
    // Visual-sandbox conversations/offers already receive deterministic
    // analytics counters from seed_live_test_listing_analytics.js. Skip
    // asynchronous aggregate increments so fixture verification cannot
    // race delayed emulator onCreate deliveries. Production documents do
    // not carry visualSandbox=true and keep the normal aggregation path.
    if (data.visualSandbox === true) return null;
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
  // Visual-sandbox conversations/offers already receive deterministic
  // analytics counters from seed_live_test_listing_analytics.js. Skip
  // asynchronous aggregate increments so fixture verification cannot
  // race delayed emulator onCreate deliveries. Production documents do
  // not carry visualSandbox=true and keep the normal aggregation path.
  if (data.visualSandbox === true) return null;
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
    const hashes = validImageHashes(listing.imageHashes);
    if (!listing.sellerUid || !hashes.length ||
        JSON.stringify(hashes) ===
          JSON.stringify(validImageHashes(before.imageHashes))) {
      return null;
    }
    const matches = await admin.firestore().collection("public_listings")
      .where("sellerUid", "==", listing.sellerUid)
      .where("imageHashes", "array-contains-any", hashes)
      .limit(100)
      .get();
    const matchedListings = matches.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));
    const evidence = duplicateListingMediaEvidence({
      listingId: event.params.listingId,
      imageHashes: hashes,
      matches: matchedListings,
    });
    if (!evidence.duplicateListingIds.length) return null;
    const caseId = `duplicate_media_${event.params.listingId}`;
    const created = await createAutomatedReviewCase(caseId, {
      reporterUid: "automated-moderation",
      reportedUid: listing.sellerUid,
      targetType: "listing",
      listingId: event.params.listingId,
      relatedListingIds: evidence.duplicateListingIds,
      matchedImageHashes: evidence.matchedImageHashes,
      mediaEvidence: duplicateListingMediaItems({
        listingId: event.params.listingId,
        listing,
        matches: matchedListings,
        evidence,
      }),
      reason: "duplicate_listing_media",
      reasonLabel: "Exact photo reused across this seller's listings",
      details: `Exact file matches were found in ` +
        `${evidence.duplicateListingIds.length} other listing(s).`,
      attachments: [],
      attachmentCount: 0,
      detectionMethod: "sha256_exact_file_match",
      detectionPolicyVersion: 1,
      confidence: 1,
      priority: "high",
    });
    if (created) {
      await notifyActiveAdministrators({
        notificationId: `moderation-${caseId}`,
        type: "moderation_review_required",
        title: "Duplicate listing photos require review",
        body: "Exact photo reuse was detected across this seller's listings.",
        reportId: caseId,
        listingId: event.params.listingId,
        priority: "high",
        read: false,
      });
    }
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
    const {signals, priority} = classifyMessageSafety(text);
    if (!signals.length) return null;

    const conversation = await admin.firestore().collection("conversations")
      .doc(event.params.conversationId).get();
    const members = conversation.data()?.memberUids || [];
    const reportedUid = message.senderUid;
    const caseId = `message_signal_${event.params.messageId}`;
    const created = await createAutomatedReviewCase(caseId, {
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
        contentEvidence: messageContentEvidence(text),
        attachments: [],
        attachmentCount: 0,
        detectionMethod: "conservative_text_safety_prescreen",
        detectionPolicyVersion: 1,
        priority,
      });
    if (created) {
      await notifyActiveAdministrators({
        notificationId: `moderation-${caseId}`,
        type: "moderation_review_required",
        title: "Message safety signal requires review",
        body: priority === "high" ?
          "A high-priority message safety signal requires review." :
          "A message safety signal requires review.",
        reportId: caseId,
        conversationId: event.params.conversationId,
        priority,
        read: false,
      });
    }
    return null;
  },
);

exports.onWeightSuggestionCreated = onDocumentCreated(
  "weight_suggestions/{suggestionId}",
  async (event) => {
    const suggestion = event.data.data();
    await notifyActiveAdministrators({
      type: "catalog_suggestion",
      title: "New shipping-weight correction to review",
      body: `${suggestion.listingTitle || "Listing"} • ${suggestion.suggestedWeightKg} kg`,
      suggestionId: event.params.suggestionId,
      listingId: suggestion.listingId || null,
      read: false,
    });
    return null;
  },
);
