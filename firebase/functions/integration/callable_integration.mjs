import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getStorage} = require("firebase-admin/storage");
const {
  FieldValue,
  GeoPoint,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {
  enforceUserRateLimit,
} = require("../abuse_rate_limit");
const {
  createAccountVerificationCommands,
} = require("../account_verification_commands");
const {createDispatchCommands} = require("../dispatch_commands");
const {createModerationCommands} = require("../moderation_commands");
const {
  createPolicyAcceptanceCommands,
} = require("../policy_acceptance_commands");
const {createSupportCommands} = require("../support_commands");
const {wantedMatchId} = require("../wanted_matching_policy");

const projectId = process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "demo-pipe-buyer-integration";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
let functionsHost = process.env.FUNCTIONS_EMULATOR_HOST;

if (!functionsHost && process.env.FIREBASE_EMULATOR_HUB) {
  const response = await fetch(
      `http://${process.env.FIREBASE_EMULATOR_HUB}/emulators`,
  );
  const emulators = await response.json();
  if (response.ok && emulators.functions) {
    functionsHost =
      `${emulators.functions.host}:${emulators.functions.port}`;
  }
}

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
    !authHost || !functionsHost) {
  throw new Error(
      "Callable integration tests must run inside the Auth, Firestore, and " +
      "Functions, and Storage emulators.",
  );
}

const storageBucket = `${projectId}.appspot.com`;
const app = initializeApp(
    {projectId, storageBucket},
    `callable-integration-${Date.now()}`,
);
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);
const rateLimitAdmin = {firestore: {FieldValue, Timestamp}};
const commandFirestore = Object.assign(
    () => db,
    {FieldValue, GeoPoint, Timestamp},
);
const accountVerificationCommands = createAccountVerificationCommands({
  firestore: commandFirestore,
  auth: () => auth,
});
const dispatchCommands = createDispatchCommands({
  firestore: commandFirestore,
  auth: () => auth,
});
const moderationCommands = createModerationCommands({
  firestore: commandFirestore,
  auth: () => auth,
});
const policyAcceptanceCommands = createPolicyAcceptanceCommands({
  firestore: commandFirestore,
  auth: () => auth,
});
const supportCommands = createSupportCommands({
  firestore: commandFirestore,
  auth: () => auth,
});
const now = Date.now();

async function createUser(label, {verified = true} = {}) {
  const response = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp` +
      "?key=demo-emulator-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email: `${label}-${now}@pipe.test`,
          password: "Integration!234",
          returnSecureToken: true,
        }),
      },
  );
  const payload = await response.json();
  if (!response.ok || !payload.localId || !payload.idToken) {
    throw new Error(`Auth emulator signup failed: ${JSON.stringify(payload)}`);
  }
  const phoneSuffix = {
    seller: "1001",
    buyer: "1002",
    carrier: "1003",
  }[label] || "1999";
  if (verified) {
    await auth.updateUser(payload.localId, {
      emailVerified: true,
      phoneNumber: `+1555555${phoneSuffix}`,
    });
  }
  const signInResponse = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/` +
      "accounts:signInWithPassword?key=demo-emulator-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email: `${label}-${now}@pipe.test`,
          password: "Integration!234",
          returnSecureToken: true,
        }),
      },
  );
  const signIn = await signInResponse.json();
  if (!signInResponse.ok || !signIn.idToken) {
    throw new Error(`Auth emulator sign-in failed: ${JSON.stringify(signIn)}`);
  }
  return {uid: payload.localId, token: signIn.idToken};
}

async function call(name, token, data) {
  const response = await fetch(
      `http://${functionsHost}/${projectId}/us-central1/${name}`,
      {
        method: "POST",
        headers: {
          "authorization": `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({data}),
      },
  );
  const payload = await response.json();
  if (!response.ok || payload.error) {
    throw new Error(
        `${name} failed (${response.status}): ${JSON.stringify(payload)}`,
    );
  }
  return payload.result;
}

async function expectCallableError(name, token, data, expectedStatus) {
  const response = await fetch(
      `http://${functionsHost}/${projectId}/us-central1/${name}`,
      {
        method: "POST",
        headers: {
          "authorization": `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({data}),
      },
  );
  const payload = await response.json();
  assert.equal(payload.error && payload.error.status, expectedStatus);
  return payload.error;
}

function listingInput(title = "Integration pipe") {
  return {
    title,
    category: "Pipe, Tubing & Materials",
    productType: "Drill Pipe",
    transactionType: "For Sale",
    price: 73,
    priceBasis: "Per piece",
    quantity: 54,
    condition: "Ready for use",
    currency: "CAD",
    description: "Emulator-only production command integration fixture.",
  };
}

function locationInput() {
  return {
    visibility: "approximate",
    point: {latitude: 55.1707, longitude: -118.7947},
    publicName: "Grande Prairie area, AB",
    nearestTown: "Grande Prairie",
    region: "Alberta",
    country: "Canada",
    address: "Emulator fixture",
    postalCode: "T8V 0A1",
    accessNotes: "Call before arrival.",
  };
}

function dispatchInput(jobId, requestId) {
  return {
    jobId,
    requestId,
    title: "Pipe transport",
    pickupLabel: "Grande Prairie yard",
    deliveryLabel: "Dawson Creek yard",
    truckingDate: now + 7 * 24 * 60 * 60 * 1000,
    loadDetails: "54 joints of drill pipe",
    sourceType: "manual",
    estimatedWeightKg: 5000,
    pickupPoint: {latitude: 55.1707, longitude: -118.7947},
    deliveryPoint: {latitude: 55.7596, longitude: -120.2377},
  };
}

async function assertCollectionSize(collection, expected, filters = []) {
  let query = db.collection(collection);
  for (const [field, operator, value] of filters) {
    query = query.where(field, operator, value);
  }
  const snapshot = await query.get();
  assert.equal(snapshot.size, expected, `${collection} count`);
}

async function waitForDocument(path, predicate, timeoutMillis = 15000) {
  const deadline = Date.now() + timeoutMillis;
  while (Date.now() < deadline) {
    const snapshot = await db.doc(path).get();
    if (snapshot.exists && predicate(snapshot.data())) return snapshot.data();
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error(`Timed out waiting for ${path}.`);
}

try {
  const rateRequest = (sequence) => ({
    auth: {uid: "rate-limit-integration"},
    data: {sequence},
    rawRequest: {path: "/integration-rate-limit"},
  });
  assert.equal((await enforceUserRateLimit({
    db,
    admin: rateLimitAdmin,
    request: rateRequest(1),
    scope: "marketplace",
    limitOverride: 2,
    nowMillis: now,
  })).duplicate, false);
  assert.equal((await enforceUserRateLimit({
    db,
    admin: rateLimitAdmin,
    request: rateRequest(1),
    scope: "marketplace",
    limitOverride: 2,
    nowMillis: now,
  })).duplicate, true);
  await enforceUserRateLimit({
    db,
    admin: rateLimitAdmin,
    request: rateRequest(2),
    scope: "marketplace",
    limitOverride: 2,
    nowMillis: now,
  });
  await assert.rejects(
      enforceUserRateLimit({
        db,
        admin: rateLimitAdmin,
        request: rateRequest(3),
        scope: "marketplace",
        limitOverride: 2,
        nowMillis: now,
      }),
      (error) => error.code === "resource-exhausted",
  );
  const [seller, buyer, carrier] = await Promise.all([
    createUser("seller"),
    createUser("buyer"),
    createUser("carrier"),
  ]);
  await db.doc("platform_configuration/phase1_features").set({
    marketplace: true,
    wantedAds: true,
    offers: true,
    auctions: true,
    dispatch: true,
    paidFeatures: false,
    regulatedListings: false,
    revision: 1,
  });
  await Promise.all([
    db.doc(`users/${seller.uid}`).set({
      displayName: "Production Seller",
      userScore: 95,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),
    db.doc(`users/${buyer.uid}`).set({
      displayName: "Production Buyer",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),
    db.doc(`users/${carrier.uid}`).set({
      displayName: "Production Carrier",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
      accountVerificationReviewVersion: 1,
    }),
    db.doc(`public_seller_profiles/${buyer.uid}`).set({
      ownerUid: buyer.uid,
      displayName: "Production Buyer",
      photoUrl: "https://storage.test/production-buyer.jpg",
      approvedTagIds: ["pipe"],
    }),
    db.doc(`dispatch_carriers/${carrier.uid}/vehicles/truck-1`).set({
      ownerUid: carrier.uid,
      name: "Integration Truck 1",
      vehicleType: "Tractor",
      maximumPayloadKg: 10000,
      available: true,
    }),
    db.doc("administrator_roles/integration-admin").set({
      active: true,
      role: "administrator",
    }),
  ]);
  const unverified = await createUser("unverified", {verified: false});
  const verificationResults = await Promise.all([
    call("syncAccountVerification", seller.token, {}),
    call("syncAccountVerification", buyer.token, {}),
    call("syncAccountVerification", carrier.token, {}),
  ]);
  for (const result of verificationResults) {
    assert.deepEqual(result, {emailVerified: true, phoneVerified: true});
  }
  const verificationRequestId = `verification-${now}`;
  const verificationFirst = await call(
      "submitAccountVerification",
      buyer.token,
      {requestId: verificationRequestId},
  );
  const verificationRetry = await call(
      "submitAccountVerification",
      buyer.token,
      {requestId: verificationRequestId},
  );
  assert.deepEqual(verificationRetry, verificationFirst);
  assert.equal(verificationFirst.status, "pending");
  assert.equal(verificationFirst.submitted, true);
  assert.equal(
      (await db.doc(`verification_requests/${buyer.uid}`).get()).data().status,
      "pending",
  );
  const reviewRequest = {
    auth: {
      uid: "integration-admin",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data: {
      requestId: `review-${now}`,
      userUid: buyer.uid,
      decision: "approved",
      reason: "Verified ownership and public profile evidence were reviewed.",
    },
  };
  const reviewFirst = await accountVerificationCommands
      .reviewAccountVerification(reviewRequest);
  const reviewRetry = await accountVerificationCommands
      .reviewAccountVerification(reviewRequest);
  assert.deepEqual(reviewRetry, reviewFirst);
  assert.equal(reviewFirst.status, "approved");
  assert.equal(
      (await db.doc(`users/${buyer.uid}`).get())
          .data().accountVerificationReviewVersion,
      1,
  );
  assert.equal(
      (await db.doc(`verification_requests/${buyer.uid}`).get()).data().status,
      "approved",
  );
  const providerRequest = {
    requestId: `dispatch-provider-${now}`,
    operatingName: "Integration Transport",
    companyName: "Integration Transport Ltd.",
    serviceAreaLabel: "Dawson Creek and within 250 km",
    serviceArea: {
      mode: "radius",
      center: {latitude: 55.76, longitude: -120.24},
      centerLabel: "Dawson Creek, British Columbia",
      radiusKm: 250,
      places: [],
    },
  };
  const providerFirst = await call(
      "submitDispatchProviderApplication",
      carrier.token,
      providerRequest,
  );
  const providerRetry = await call(
      "submitDispatchProviderApplication",
      carrier.token,
      providerRequest,
  );
  assert.deepEqual(providerRetry, providerFirst);
  assert.equal(providerFirst.status, "pending_review");
  assert.equal(
      (await db.doc(`dispatch_carriers/${carrier.uid}`).get()).data().status,
      "pending_review",
  );
  const providerReviewRequest = {
    auth: reviewRequest.auth,
    data: {
      requestId: `dispatch-provider-review-${now}`,
      providerUid: carrier.uid,
      decision: "approved",
      reason: "Verified public operating information and service coverage.",
    },
  };
  const providerReviewFirst = await dispatchCommands
      .reviewDispatchProvider(providerReviewRequest);
  const providerReviewRetry = await dispatchCommands
      .reviewDispatchProvider(providerReviewRequest);
  assert.deepEqual(providerReviewRetry, providerReviewFirst);
  assert.equal(providerReviewFirst.status, "active");
  assert.equal(
      (await db.doc(`dispatch_carriers/${carrier.uid}`).get()).data().status,
      "active",
  );
  await db.doc(`dispatch_memberships/${carrier.uid}`).set({
    ownerUid: carrier.uid,
    active: true,
    status: "active",
    renewalStatus: "paid",
    paymentIssue: false,
    plan: "monthly",
    subscriptionId: `sub_integration_${now}`,
    stripeCustomerId: `cus_integration_${now}`,
    currentPeriodStart: Timestamp.fromMillis(
        now - 24 * 60 * 60 * 1000,
    ),
    currentPeriodEnd: Timestamp.fromMillis(
        now + 30 * 24 * 60 * 60 * 1000,
    ),
    lastPaidInvoiceId: `in_integration_${now}`,
    createdAt: Timestamp.fromMillis(now - 24 * 60 * 60 * 1000),
    updatedAt: Timestamp.fromMillis(now),
  });

  await assertCollectionSize("account_phone_registry", 3);
  assert.deepEqual(
      await call("syncAccountVerification", unverified.token, {}),
      {emailVerified: false, phoneVerified: false},
  );
  const unverifiedListingId = `blocked-listing-${now}`;
  const blocked = await expectCallableError(
      "createMarketplaceListing",
      unverified.token,
      {
        listingId: unverifiedListingId,
        requestId: `blocked-${now}`,
        listing: listingInput("Blocked unverified listing"),
        location: locationInput(),
      },
      "FAILED_PRECONDITION",
  );
  assert.match(blocked.message, /verify your email/i);
  assert.equal((await db.doc(`public_listings/${unverifiedListingId}`).get())
      .exists, false);

  const bypassListingId = `media-bypass-${now}`;
  await expectCallableError(
      "createMarketplaceListing",
      seller.token,
      {
        listingId: bypassListingId,
        listing: {
          ...listingInput("Unsafe media bypass"),
          mediaPhotoCount: 1,
          hasVideo: false,
          imageUrls: [
            "https://firebasestorage.googleapis.com/v0/b/example/o/fake.jpg",
          ],
        },
        location: locationInput(),
      },
      "FAILED_PRECONDITION",
  );
  assert.equal(
      (await db.doc(`public_listings/${bypassListingId}`).get()).exists,
      false,
  );

  const draftListingId = `draft-listing-${now}`;
  const draftData = {
    listingId: draftListingId,
    listing: {
      ...listingInput("Draft-first integration listing"),
      mediaPhotoCount: 0,
      hasVideo: false,
      imageUrls: [],
      imageHashes: [],
      thumbnailUrl: null,
      videoUrl: null,
      mediaUploadStatus: "none",
    },
    location: locationInput(),
  };
  const draftFirst = await call(
      "createMarketplaceListingDraft",
      seller.token,
      draftData,
  );
  const draftRetry = await call(
      "createMarketplaceListingDraft",
      seller.token,
      draftData,
  );
  assert.deepEqual(draftRetry, draftFirst);
  assert.equal(
      (await db.doc(`public_listings/${draftListingId}`).get()).exists,
      false,
  );
  assert.equal(
      (await db.doc(`marketplace_listing_drafts/${draftListingId}`).get())
          .data().status,
      "ready_to_publish",
  );
  const publishDraftData = {
    requestId: `publish-draft-${now}`,
    listingId: draftListingId,
  };
  const publishDraftFirst = await call(
      "publishMarketplaceListingDraft",
      seller.token,
      publishDraftData,
  );
  const publishDraftRetry = await call(
      "publishMarketplaceListingDraft",
      seller.token,
      publishDraftData,
  );
  assert.deepEqual(publishDraftRetry, publishDraftFirst);
  assert.equal(
      (await db.doc(`public_listings/${draftListingId}`).get()).data().status,
      "active",
  );
  assert.equal(
      (await db.doc(`marketplace_listing_drafts/${draftListingId}`).get())
          .exists,
      false,
  );

  const mediaDraftId = `media-draft-${now}`;
  await call("createMarketplaceListingDraft", seller.token, {
    listingId: mediaDraftId,
    listing: {
      ...listingInput("Media draft integration listing"),
      mediaPhotoCount: 1,
      hasVideo: false,
      imageUrls: [],
      imageHashes: [],
      thumbnailUrl: null,
      videoUrl: null,
      mediaUploadStatus: "queued",
    },
    location: locationInput(),
  });
  await expectCallableError(
      "publishMarketplaceListingDraft",
      seller.token,
      {requestId: `early-media-publish-${now}`, listingId: mediaDraftId},
      "FAILED_PRECONDITION",
  );
  const photoBytes = Buffer.from("emulator listing photo fixture");
  const photoPath =
    `listing_media/${seller.uid}/${mediaDraftId}/photo_1.jpg`;
  await storage.bucket().file(photoPath).save(photoBytes, {
    contentType: "image/jpeg",
  });
  const photoUrl =
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `${encodeURIComponent(photoPath)}?alt=media&token=emulator`;
  await expectCallableError(
      "updateMarketplaceListingDraftMedia",
      seller.token,
      {
        listingId: mediaDraftId,
        status: "complete",
        imageUrls: [photoUrl],
        imageHashes: ["0".repeat(64)],
        thumbnailUrl: photoUrl,
        videoUrl: null,
      },
      "FAILED_PRECONDITION",
  );
  await call("updateMarketplaceListingDraftMedia", seller.token, {
    listingId: mediaDraftId,
    status: "complete",
    imageUrls: [photoUrl],
    imageHashes: [createHash("sha256").update(photoBytes).digest("hex")],
    thumbnailUrl: photoUrl,
    videoUrl: null,
  });
  await call("publishMarketplaceListingDraft", seller.token, {
    requestId: `publish-media-draft-${now}`,
    listingId: mediaDraftId,
  });
  const publishedMediaListing = (
    await db.doc(`public_listings/${mediaDraftId}`).get()
  ).data();
  assert.equal(publishedMediaListing.mediaUploadStatus, "complete");
  assert.equal(publishedMediaListing.thumbnailUrl, photoUrl);
  assert.equal(publishedMediaListing.imageUrls.length, 1);

  const duplicateMediaDraftId = `duplicate-media-${now}`;
  await call("createMarketplaceListingDraft", seller.token, {
    listingId: duplicateMediaDraftId,
    listing: {
      ...listingInput("Duplicate media review fixture"),
      mediaPhotoCount: 1,
      hasVideo: false,
      imageUrls: [],
      imageHashes: [],
      thumbnailUrl: null,
      videoUrl: null,
      mediaUploadStatus: "queued",
    },
    location: locationInput(),
  });
  const duplicatePhotoPath =
    `listing_media/${seller.uid}/${duplicateMediaDraftId}/photo_1.jpg`;
  await storage.bucket().file(duplicatePhotoPath).save(photoBytes, {
    contentType: "image/jpeg",
  });
  const duplicatePhotoUrl =
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `${encodeURIComponent(duplicatePhotoPath)}?alt=media&token=emulator`;
  const trustedPhotoHash = createHash("sha256")
      .update(photoBytes)
      .digest("hex");
  await call("updateMarketplaceListingDraftMedia", seller.token, {
    listingId: duplicateMediaDraftId,
    status: "complete",
    imageUrls: [duplicatePhotoUrl],
    imageHashes: [trustedPhotoHash],
    thumbnailUrl: duplicatePhotoUrl,
    videoUrl: null,
  });
  await call("publishMarketplaceListingDraft", seller.token, {
    requestId: `publish-duplicate-media-${now}`,
    listingId: duplicateMediaDraftId,
  });
  const duplicateCaseId = `duplicate_media_${duplicateMediaDraftId}`;
  const duplicateCase = await waitForDocument(
      `trust_reports/${duplicateCaseId}`,
      (data) => data.status === "pending",
  );
  assert.equal(duplicateCase.reason, "duplicate_listing_media");
  assert.equal(duplicateCase.humanReviewRequired, true);
  assert.equal(duplicateCase.automaticEnforcement, false);
  assert.ok(duplicateCase.relatedListingIds.includes(mediaDraftId));
  assert.deepEqual(duplicateCase.matchedImageHashes, [trustedPhotoHash]);
  assert.equal(duplicateCase.mediaEvidence.length, 2);
  assert.deepEqual(
      duplicateCase.mediaEvidence.map((item) => item.listingId).sort(),
      [duplicateMediaDraftId, mediaDraftId].sort(),
  );
  assert.ok(duplicateCase.mediaEvidence.every((item) => item.photoUrl));
  const duplicateListing = (
    await db.doc(`public_listings/${duplicateMediaDraftId}`).get()
  ).data();
  assert.equal(duplicateListing.status, "active");
  assert.equal(duplicateListing.moderationStatus, undefined);
  await waitForDocument(
      `users/integration-admin/notifications/moderation-${duplicateCaseId}`,
      (data) => data.reportId === duplicateCaseId,
  );

  const offerListingId = `offer-listing-${now}`;
  const createListingData = {
    listingId: offerListingId,
    listing: listingInput("Offer integration listing"),
    location: locationInput(),
  };
  const listingFirst = await call(
      "createMarketplaceListing",
      seller.token,
      createListingData,
  );
  const listingRetry = await call(
      "createMarketplaceListing",
      seller.token,
      createListingData,
  );
  assert.deepEqual(listingRetry, listingFirst);

  const offerId = `offer-${now}`;
  const offerData = {
    requestId: offerId,
    listingId: offerListingId,
    offeredUnitPrice: 70,
    requestedQuantity: 54,
    truckingPlan: "buyer_arranged",
  };
  const offerFirst = await call(
      "createMarketplaceOffer",
      buyer.token,
      offerData,
  );
  const offerRetry = await call(
      "createMarketplaceOffer",
      buyer.token,
      offerData,
  );
  assert.deepEqual(offerRetry, offerFirst);
  await assertCollectionSize(
      "offers",
      1,
      [["listingId", "==", offerListingId]],
  );

  const conversationData = {listingId: offerListingId};
  const conversationFirst = await call(
      "openMarketplaceConversation",
      buyer.token,
      conversationData,
  );
  const conversationRetry = await call(
      "openMarketplaceConversation",
      buyer.token,
      conversationData,
  );
  assert.deepEqual(conversationRetry, conversationFirst);
  const sellerConversation = await call(
      "openMarketplaceConversation",
      seller.token,
      {
        listingId: offerListingId,
        participantUid: buyer.uid,
        offerId,
      },
  );
  assert.equal(sellerConversation.conversationId,
      conversationFirst.conversationId);
  const uploadAuthorization = await call(
      "authorizeMarketplaceUpload",
      buyer.token,
      {
        requestId: `chat-upload-${now}`,
        purpose: "chat_attachment",
        conversationId: conversationFirst.conversationId,
        originalName: "integration.jpg",
        contentType: "image/jpeg",
        sizeBytes: 4,
      },
  );
  assert.match(uploadAuthorization.storagePath, /chat_attachments/);
  const uploadUrl = "https://firebasestorage.googleapis.com/v0/b/" +
    "integration/o/" + encodeURIComponent(uploadAuthorization.storagePath) +
    "?alt=media";
  await call("confirmMarketplaceUpload", buyer.token, {
    authorizationId: uploadAuthorization.authorizationId,
    url: uploadUrl,
  });
  const messageData = {
    requestId: `message-${now}`,
    conversationId: conversationFirst.conversationId,
    text: "The production communication command is ready.",
    attachment: {
      authorizationId: uploadAuthorization.authorizationId,
      url: uploadUrl,
      name: "integration.jpg",
    },
  };
  const messageFirst = await call(
      "sendMarketplaceMessage",
      buyer.token,
      messageData,
  );
  assert.deepEqual(
      await call("sendMarketplaceMessage", buyer.token, messageData),
      messageFirst,
  );
  await assertCollectionSize(
      `conversations/${conversationFirst.conversationId}/messages`,
      1,
  );
  const flaggedMessageId = `message-safety-${now}`;
  await call("sendMarketplaceMessage", buyer.token, {
    requestId: flaggedMessageId,
    conversationId: conversationFirst.conversationId,
    text: "Send the payment by gift card off-platform.",
  });
  const messageCaseId = `message_signal_${flaggedMessageId}`;
  const messageCase = await waitForDocument(
      `trust_reports/${messageCaseId}`,
      (data) => data.status === "pending",
  );
  assert.deepEqual(messageCase.moderationSignals, ["possible_payment_fraud"]);
  assert.equal(messageCase.humanReviewRequired, true);
  assert.equal(messageCase.automaticEnforcement, false);
  assert.deepEqual(messageCase.contentEvidence, {
    excerpt: "Send the payment by gift card off-platform.",
    characterCount: 43,
    truncated: false,
  });
  const flaggedMessage = (
    await db.doc(
        `conversations/${conversationFirst.conversationId}/messages/` +
        flaggedMessageId,
    ).get()
  ).data();
  assert.equal(flaggedMessage.moderationVisibility, undefined);
  await waitForDocument(
      `users/integration-admin/notifications/moderation-${messageCaseId}`,
      (data) => data.reportId === messageCaseId,
  );
  assert.equal((await call(
      "markMarketplaceConversationRead",
      seller.token,
      {conversationId: conversationFirst.conversationId},
  )).changed, true);
  const reportData = {
    requestId: `report-${now}`,
    reportedUid: seller.uid,
    targetType: "listing",
    listingId: offerListingId,
    reason: "misleading_information",
    details: "Integration evidence for the protected reporting command.",
    attachments: [],
  };
  const reportFirst = await call(
      "submitMarketplaceReport",
      buyer.token,
      reportData,
  );
  assert.deepEqual(
      await call("submitMarketplaceReport", buyer.token, reportData),
      reportFirst,
  );
  assert.equal(
      (await db.doc(`trust_reports/${reportFirst.reportId}`).get())
          .data().status,
      "pending",
  );
  const moderationReviewRequest = {
    auth: reviewRequest.auth,
    data: {
      requestId: `moderation-review-${now}`,
      reportId: reportFirst.reportId,
      decision: "violation_confirmed",
      reason: "The submitted listing evidence confirms misleading information.",
      enforcementAction: "warning",
    },
  };
  const moderationReviewFirst = await moderationCommands
      .reviewModerationReport(moderationReviewRequest);
  assert.deepEqual(
      await moderationCommands.reviewModerationReport(moderationReviewRequest),
      moderationReviewFirst,
  );
  assert.equal(
      (await db.doc(`trust_reports/${reportFirst.reportId}`).get())
          .data().status,
      "violation_confirmed",
  );
  assert.equal(
      (await db.doc(`moderation_notices/${reportFirst.reportId}`).get())
          .data().reportedUid,
      seller.uid,
  );
  const appealRequest = {
    auth: {
      uid: seller.uid,
      token: {
        email_verified: true,
        phone_number: "+15555551001",
        auth_time: Math.floor(Date.now() / 1000),
      },
    },
    data: {
      requestId: `moderation-appeal-${now}`,
      reportId: reportFirst.reportId,
      reason: "The listing facts can be verified with the original documents.",
    },
  };
  const appealFirst = await moderationCommands
      .appealModerationDecision(appealRequest);
  assert.deepEqual(
      await moderationCommands.appealModerationDecision(appealRequest),
      appealFirst,
  );
  assert.equal(appealFirst.status, "appealed");
  const appealReviewRequest = {
    auth: reviewRequest.auth,
    data: {
      requestId: `moderation-appeal-review-${now}`,
      reportId: reportFirst.reportId,
      decision: "overturned",
      reason: "Original documentation resolves the reported discrepancy.",
    },
  };
  const appealReviewFirst = await moderationCommands
      .reviewModerationAppeal(appealReviewRequest);
  assert.deepEqual(
      await moderationCommands.reviewModerationAppeal(appealReviewRequest),
      appealReviewFirst,
  );
  assert.equal(appealReviewFirst.status, "appeal_overturned");
  const dismissedReportId = `dismissed-report-${now}`;
  await db.doc(`trust_reports/${dismissedReportId}`).set({
    reporterUid: buyer.uid,
    reportedUid: seller.uid,
    targetType: "user",
    reason: "other",
    reasonLabel: "Something else",
    details: "A report that should be dismissed without notifying its target.",
    source: "user",
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });
  await moderationCommands.reviewModerationReport({
    auth: reviewRequest.auth,
    data: {
      requestId: `moderation-dismiss-${now}`,
      reportId: dismissedReportId,
      decision: "dismissed",
      reason: "The available evidence does not support a policy violation.",
      enforcementAction: "none",
    },
  });
  assert.equal(
      (await db.doc(`moderation_notices/${dismissedReportId}`).get()).exists,
      false,
  );
  const supportCaseData = {
    requestId: `support-${now}`,
    category: "technical",
    subject: "Listing photo upload fails",
    description: "The upload stops before completion when publishing a listing.",
    relatedType: "listing",
    relatedId: offerListingId,
  };
  const supportFirst = await call(
      "createSupportCase",
      buyer.token,
      supportCaseData,
  );
  assert.deepEqual(
      await call("createSupportCase", buyer.token, supportCaseData),
      supportFirst,
  );
  const supportResponse = {
    auth: reviewRequest.auth,
    data: {
      requestId: `support-response-${now}`,
      caseId: supportFirst.caseId,
      action: "respond",
      message: "Please retry once and provide the image format and file size.",
    },
  };
  assert.equal(
      (await supportCommands.updateSupportCase(supportResponse)).status,
      "waiting_customer",
  );
  const supportReply = {
    requestId: `support-reply-${now}`,
    caseId: supportFirst.caseId,
    message: "The image is a four megabyte JPEG and retrying has the same result.",
  };
  const supportReplyFirst = await call(
      "replySupportCase",
      buyer.token,
      supportReply,
  );
  assert.deepEqual(
      await call("replySupportCase", buyer.token, supportReply),
      supportReplyFirst,
  );
  const resolveSupport = {
    auth: reviewRequest.auth,
    data: {
      requestId: `support-resolve-${now}`,
      caseId: supportFirst.caseId,
      action: "resolve",
      message: "The upload authorization was refreshed and the issue is resolved.",
    },
  };
  const resolvedSupport = await supportCommands.updateSupportCase(resolveSupport);
  assert.deepEqual(
      await supportCommands.updateSupportCase(resolveSupport),
      resolvedSupport,
  );
  assert.equal(resolvedSupport.status, "resolved");
  await assertCollectionSize(
      "support_case_events",
      4,
      [["caseId", "==", supportFirst.caseId]],
  );
  const requiredPolicies = [
    "terms_of_service",
    "privacy_notice",
    "prohibited_items",
    "mapping_location",
    "communications",
  ];
  const policyAcceptanceItems = [];
  for (const policyId of requiredPolicies) {
    const contentSha256 = createHash("sha256")
        .update(`reviewed-${policyId}-2026.07`)
        .digest("hex");
    const publicationRequest = {
      auth: reviewRequest.auth,
      data: {
        requestId: `publish-${policyId}-${now}`,
        policyId,
        version: "2026.07",
        summary: `Reviewed integration summary for the ${policyId} policy.`,
        documentUrl: `https://example.test/policies/${policyId}`,
        contentSha256,
        effectiveAtMillis: now + 24 * 60 * 60 * 1000,
        approvalNote:
          "Approved only for the isolated authenticated emulator acceptance exercise.",
      },
    };
    const published = await policyAcceptanceCommands
        .publishPolicyDocument(publicationRequest);
    assert.deepEqual(
        await policyAcceptanceCommands
            .publishPolicyDocument(publicationRequest),
        published,
    );
    policyAcceptanceItems.push({
      policyId,
      version: published.version,
      contentSha256,
    });
  }
  const enablePolicyEnforcement = {
    auth: reviewRequest.auth,
    data: {
      requestId: `policy-enforcement-enable-${now}`,
      enabled: true,
      approvalNote:
        "Enable policy enforcement for the isolated authenticated emulator exercise.",
    },
  };
  const enforcementFirst = await policyAcceptanceCommands
      .setPolicyEnforcement(enablePolicyEnforcement);
  assert.deepEqual(
      await policyAcceptanceCommands
          .setPolicyEnforcement(enablePolicyEnforcement),
      enforcementFirst,
  );
  assert.equal(enforcementFirst.enabled, true);
  await expectCallableError(
      "setMarketplaceListingSaved",
      buyer.token,
      {
        requestId: `policy-blocked-save-${now}`,
        listingId: offerListingId,
        saved: true,
      },
      "FAILED_PRECONDITION",
  );
  const policyAcceptanceData = {
    requestId: `policy-acceptance-${now}`,
    policies: policyAcceptanceItems,
  };
  const policyAcceptanceFirst = await call(
      "acceptRequiredPolicies",
      buyer.token,
      policyAcceptanceData,
  );
  assert.deepEqual(
      await call(
          "acceptRequiredPolicies",
          buyer.token,
          policyAcceptanceData,
      ),
      policyAcceptanceFirst,
  );
  assert.equal(policyAcceptanceFirst.current, true);
  assert.equal(
      (await db.doc(`policy_acceptances/${buyer.uid}`).get())
          .data().fingerprint.length,
      64,
  );
  await assertCollectionSize(
      "policy_acceptance_events",
      1,
      [["ownerUid", "==", buyer.uid]],
  );
  const policyVerifiedSave = {
    requestId: `policy-verified-save-${now}`,
    listingId: offerListingId,
    saved: true,
  };
  const policySaveFirst = await call(
      "setMarketplaceListingSaved",
      buyer.token,
      policyVerifiedSave,
  );
  assert.deepEqual(
      await call(
          "setMarketplaceListingSaved",
          buyer.token,
          policyVerifiedSave,
      ),
      policySaveFirst,
  );
  await call("setMarketplaceListingSaved", buyer.token, {
    requestId: `policy-verified-unsave-${now}`,
    listingId: offerListingId,
    saved: false,
  });
  assert.equal(
      (await policyAcceptanceCommands.setPolicyEnforcement({
        auth: reviewRequest.auth,
        data: {
          requestId: `policy-enforcement-disable-${now}`,
          enabled: false,
          approvalNote:
            "Disable policy enforcement after the isolated emulator gate test completes.",
        },
      })).enabled,
      false,
  );
  const blockedMessage = await expectCallableError(
      "openMarketplaceConversation",
      unverified.token,
      {listingId: offerListingId},
      "FAILED_PRECONDITION",
  );
  assert.match(blockedMessage.message, /verify your email/i);

  const acceptanceFirst = await call(
      "acceptMarketplaceOffer",
      seller.token,
      {offerId},
  );
  const acceptanceRetry = await call(
      "acceptMarketplaceOffer",
      seller.token,
      {offerId},
  );
  assert.deepEqual(acceptanceRetry, acceptanceFirst);
  assert.equal(
      (await db.doc(`public_listings/${offerListingId}`).get()).data().status,
      "pending_sale",
  );
  const buyerConfirmationData = {
    requestId: `buyer-confirm-${now}`,
    offerId,
    action: "confirm_completion",
  };
  const unpaidMarketplaceCompletion = await expectCallableError(
      "updateMarketplaceTransaction",
      buyer.token,
      buyerConfirmationData,
      "FAILED_PRECONDITION",
  );
  assert.match(unpaidMarketplaceCompletion.message, /payment|settlement/i);
  await db.doc(`marketplace_transactions/${offerId}`).update({
    paymentProviderStatus: "external_agreed",
    financialStatus: "external_settlement_confirmed",
    updatedAt: FieldValue.serverTimestamp(),
  });
  const buyerConfirmation = await call(
      "updateMarketplaceTransaction",
      buyer.token,
      buyerConfirmationData,
  );
  assert.deepEqual(
      await call(
          "updateMarketplaceTransaction",
          buyer.token,
          buyerConfirmationData,
      ),
      buyerConfirmation,
  );
  assert.equal(
      buyerConfirmation.status,
      "awaiting_seller_confirmation",
  );
  const sellerConfirmationData = {
    requestId: `seller-confirm-${now}`,
    offerId,
    action: "confirm_completion",
  };
  const sellerConfirmation = await call(
      "updateMarketplaceTransaction",
      seller.token,
      sellerConfirmationData,
  );
  assert.deepEqual(
      await call(
          "updateMarketplaceTransaction",
          seller.token,
          sellerConfirmationData,
      ),
      sellerConfirmation,
  );
  assert.equal(sellerConfirmation.status, "completed");
  assert.equal(sellerConfirmation.buyerConfirmed, true);
  assert.equal(sellerConfirmation.sellerConfirmed, true);
  assert.equal(
      (await db.doc(`public_listings/${offerListingId}`).get()).data().status,
      "sold",
  );

  const lifecycleListingId = `lifecycle-listing-${now}`;
  await call("createMarketplaceListing", seller.token, {
    listingId: lifecycleListingId,
    listing: listingInput("Lifecycle integration listing"),
    location: locationInput(),
  });
  const saveData = {
    requestId: `save-listing-${now}`,
    listingId: lifecycleListingId,
    saved: true,
  };
  const saveFirst = await call(
      "setMarketplaceListingSaved",
      buyer.token,
      saveData,
  );
  const saveRetry = await call(
      "setMarketplaceListingSaved",
      buyer.token,
      saveData,
  );
  assert.deepEqual(saveRetry, saveFirst);
  assert.equal(saveFirst.changed, true);
  assert.equal(
      (await db.doc(
          `users/${buyer.uid}/saved_listings/${lifecycleListingId}`,
      ).get()).exists,
      true,
  );
  const unsaveData = {
    requestId: `unsave-listing-${now}`,
    listingId: lifecycleListingId,
    saved: false,
  };
  const unsaveFirst = await call(
      "setMarketplaceListingSaved",
      buyer.token,
      unsaveData,
  );
  const unsaveRetry = await call(
      "setMarketplaceListingSaved",
      buyer.token,
      unsaveData,
  );
  assert.deepEqual(unsaveRetry, unsaveFirst);
  assert.equal(
      (await db.doc(
          `users/${buyer.uid}/saved_listings/${lifecycleListingId}`,
      ).get()).exists,
      false,
  );
  const detailsData = {
    requestId: `edit-listing-${now}`,
    listingId: lifecycleListingId,
    expectedRevision: 1,
    patch: {
      title: "Updated lifecycle listing",
      price: 75,
      quantity: 50,
      description: "Updated through the authenticated listing command.",
    },
  };
  const detailsFirst = await call(
      "updateMarketplaceListingDetails",
      seller.token,
      detailsData,
  );
  const detailsRetry = await call(
      "updateMarketplaceListingDetails",
      seller.token,
      detailsData,
  );
  assert.deepEqual(detailsRetry, detailsFirst);
  assert.equal(detailsFirst.revision, 2);

  let transitionNumber = 0;
  for (const [action, status] of [
    ["pause", "paused"],
    ["activate", "active"],
    ["mark_sold", "sold"],
    ["archive", "archived"],
  ]) {
    transitionNumber += 1;
    const transitionData = {
      requestId: `transition-${transitionNumber}-${now}`,
      listingId: lifecycleListingId,
      action,
    };
    const transitionFirst = await call(
        "transitionMarketplaceListing",
        seller.token,
        transitionData,
    );
    const transitionRetry = await call(
        "transitionMarketplaceListing",
        seller.token,
        transitionData,
    );
    assert.deepEqual(transitionRetry, transitionFirst);
    assert.equal(transitionFirst.status, status);
  }
  const relistedListingId = `relisted-${now}`;
  const relistData = {
    requestId: `relist-${now}`,
    listingId: lifecycleListingId,
    newListingId: relistedListingId,
  };
  const relistFirst = await call(
      "relistMarketplaceListing",
      seller.token,
      relistData,
  );
  const relistRetry = await call(
      "relistMarketplaceListing",
      seller.token,
      relistData,
  );
  assert.deepEqual(relistRetry, relistFirst);
  const relisted = (
    await db.doc(`public_listings/${relistedListingId}`).get()
  ).data();
  assert.equal(relisted.status, "active");
  assert.equal(relisted.revision, 1);
  assert.equal(relisted.relistedFromListingId, lifecycleListingId);
  assert.equal(relisted.offerCount, 0);
  assert.equal(
      (await db.doc(`listing_private_locations/${relistedListingId}`).get())
          .exists,
      true,
  );

  const auctionListingId = `auction-listing-${now}`;
  await call("createMarketplaceListing", seller.token, {
    listingId: auctionListingId,
    listing: listingInput("Auction conversion listing"),
    location: locationInput(),
  });
  const conversionData = {
    requestId: `convert-${now}`,
    listingId: auctionListingId,
    startingBid: 73,
    minimumBidIncrement: 1,
    reservePrice: 90,
    buyItNowPrice: 120,
    durationDays: 30,
    customAuction: false,
  };
  const conversionFirst = await call(
      "convertMarketplaceListingToAuction",
      seller.token,
      conversionData,
  );
  const conversionRetry = await call(
      "convertMarketplaceListingToAuction",
      seller.token,
      conversionData,
  );
  assert.deepEqual(conversionRetry, conversionFirst);
  const converted = (
    await db.doc(`public_listings/${auctionListingId}`).get()
  ).data();
  assert.equal(converted.transactionType, "Auction");
  assert.equal(converted.bidCount, 0);
  assert.equal(converted.reservePrice, undefined);
  assert.equal(
      (await db.doc(`auction_private/${auctionListingId}`).get()).data()
          .reservePrice,
      90,
  );

  const bidFirst = await call("placeAuctionBid", buyer.token, {
    listingId: auctionListingId,
    amount: 73,
  });
  const bidRetry = await call("placeAuctionBid", buyer.token, {
    listingId: auctionListingId,
    amount: 73,
  });
  assert.deepEqual(bidRetry, bidFirst);
  assert.equal(
      (await db.doc(`public_listings/${auctionListingId}`).get()).data()
          .bidCount,
      1,
  );
  const belowReserveFirst = await call(
      "acceptAuctionBidBelowReserve",
      seller.token,
      {listingId: auctionListingId},
  );
  const belowReserveRetry = await call(
      "acceptAuctionBidBelowReserve",
      seller.token,
      {listingId: auctionListingId},
  );
  assert.deepEqual(belowReserveRetry, belowReserveFirst);

  const buyNowListingId = `buy-now-listing-${now}`;
  await call("createMarketplaceListing", seller.token, {
    listingId: buyNowListingId,
    listing: listingInput("Buy Now integration listing"),
    location: locationInput(),
  });
  await call("convertMarketplaceListingToAuction", seller.token, {
    ...conversionData,
    requestId: `convert-buy-now-${now}`,
    listingId: buyNowListingId,
  });
  const buyNowFirst = await call(
      "buyAuctionNow",
      buyer.token,
      {listingId: buyNowListingId},
  );
  const buyNowRetry = await call(
      "buyAuctionNow",
      buyer.token,
      {listingId: buyNowListingId},
  );
  assert.deepEqual(buyNowRetry, buyNowFirst);
  const boughtListing = (
    await db.doc(`public_listings/${buyNowListingId}`).get()
  ).data();
  assert.equal(boughtListing.auctionStatus, "bought_now");
  assert.equal(boughtListing.bidCount, 1);
  assert.equal(
      (await db.doc(`auction_transactions/${buyNowListingId}`).get()).data()
          .status,
      "pending_completion",
  );

  const finalizationListingId = `finalization-listing-${now}`;
  await call("createMarketplaceListing", seller.token, {
    listingId: finalizationListingId,
    listing: listingInput("Auction finalization integration listing"),
    location: locationInput(),
  });
  await call("convertMarketplaceListingToAuction", seller.token, {
    ...conversionData,
    requestId: `convert-finalization-${now}`,
    listingId: finalizationListingId,
    reservePrice: 90,
  });
  await call("placeAuctionBid", buyer.token, {
    listingId: finalizationListingId,
    amount: 90,
  });
  await db.doc(`public_listings/${finalizationListingId}`).update({
    auctionEndAt: Timestamp.fromMillis(now - 1000),
  });
  const finalizeData = {
    requestId: `finalize-auction-${now}`,
    listingId: finalizationListingId,
  };
  const finalized = await call(
      "finalizeAuction",
      buyer.token,
      finalizeData,
  );
  assert.deepEqual(
      await call("finalizeAuction", buyer.token, finalizeData),
      finalized,
  );
  assert.equal(finalized.auctionStatus, "won");
  assert.equal(finalized.winnerUid, buyer.uid);
  const auctionBuyerConfirmation = {
    requestId: `auction-buyer-confirm-${now}`,
    listingId: finalizationListingId,
    action: "confirm_completion",
  };
  const unpaidAuctionCompletion = await expectCallableError(
      "updateAuctionTransaction",
      buyer.token,
      auctionBuyerConfirmation,
      "FAILED_PRECONDITION",
  );
  assert.match(unpaidAuctionCompletion.message, /paid|payment/i);
  const auctionPaymentPath =
    `marketplace_transactions/auction_${finalizationListingId}`;
  await waitForDocument(
      auctionPaymentPath,
      (data) => data.listingId === finalizationListingId,
  );
  await db.doc(auctionPaymentPath).set({
    paymentProviderStatus: "external_agreed",
    financialStatus: "external_settlement_confirmed",
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  const auctionBuyerResult = await call(
      "updateAuctionTransaction",
      buyer.token,
      auctionBuyerConfirmation,
  );
  assert.deepEqual(
      await call(
          "updateAuctionTransaction",
          buyer.token,
          auctionBuyerConfirmation,
      ),
      auctionBuyerResult,
  );
  assert.equal(auctionBuyerResult.status, "awaiting_seller_confirmation");
  const auctionSellerConfirmation = {
    requestId: `auction-seller-confirm-${now}`,
    listingId: finalizationListingId,
    action: "confirm_completion",
  };
  const auctionSellerResult = await call(
      "updateAuctionTransaction",
      seller.token,
      auctionSellerConfirmation,
  );
  assert.deepEqual(
      await call(
          "updateAuctionTransaction",
          seller.token,
          auctionSellerConfirmation,
      ),
      auctionSellerResult,
  );
  assert.equal(auctionSellerResult.status, "completed");
  assert.equal(
      (await db.doc(`public_listings/${finalizationListingId}`).get()).data()
          .status,
      "sold",
  );

  const jobId = `job-${now}`;
  const jobCreateData = dispatchInput(jobId, `create-job-${now}`);
  const jobFirst = await call("createDispatchJob", buyer.token, jobCreateData);
  const jobRetry = await call("createDispatchJob", buyer.token, jobCreateData);
  assert.deepEqual(jobRetry, jobFirst);
  const publicDispatchJob =
    (await db.doc(`dispatch_jobs/${jobId}`).get()).data();
  const privateDispatchJob =
    (await db.doc(`dispatch_job_private/${jobId}`).get()).data();
  assert.equal(publicDispatchJob.pickupPoint, undefined);
  assert.equal(publicDispatchJob.deliveryPoint, undefined);
  assert.equal(publicDispatchJob.distanceSource, "server_straight_line_estimate");
  assert.equal(publicDispatchJob.routeProfile, "truck");
  assert.ok(privateDispatchJob.pickupPoint);
  assert.ok(privateDispatchJob.deliveryPoint);
  await db.doc(`dispatch_jobs/${jobId}`).update({
    updatedAt: Timestamp.fromMillis(now - 10000),
  });
  const updateData = {
    ...dispatchInput(jobId, `update-job-${now}`),
    title: "Updated pipe transport",
  };
  const updateFirst = await call("updateDispatchJob", buyer.token, updateData);
  const updateRetry = await call("updateDispatchJob", buyer.token, updateData);
  assert.deepEqual(updateRetry, updateFirst);
  assert.equal(updateFirst.revision, 2);

  const draftJobId = `draft-job-${now}`;
  await db.doc(`dispatch_jobs/${draftJobId}`).set({
    ...dispatchInput(draftJobId, "unused"),
    createdByUid: buyer.uid,
    status: "draft",
    revision: 1,
    truckingDate: Timestamp.fromMillis(now + 7 * 24 * 60 * 60 * 1000),
    createdAt: Timestamp.fromMillis(now - 10000),
    updatedAt: Timestamp.fromMillis(now - 10000),
  });
  const publishData = {jobId: draftJobId, requestId: `publish-${now}`};
  const publishFirst = await call(
      "publishDispatchJob",
      buyer.token,
      publishData,
  );
  const publishRetry = await call(
      "publishDispatchJob",
      buyer.token,
      publishData,
  );
  assert.deepEqual(publishRetry, publishFirst);

  const quoteData = {
    requestId: `quote-${now}`,
    jobId,
    vehicleId: "truck-1",
    amount: 1450,
    note: "Includes route and loading time.",
    availableDate: now + 6 * 24 * 60 * 60 * 1000,
  };
  const quoteFirst = await call(
      "submitDispatchQuote",
      carrier.token,
      quoteData,
  );
  const quoteRetry = await call(
      "submitDispatchQuote",
      carrier.token,
      quoteData,
  );
  assert.deepEqual(quoteRetry, quoteFirst);
  assert.equal(
      (await db.doc(`dispatch_jobs/${jobId}`).get()).data().bidCount,
      1,
  );

  const awardData = {
    requestId: `award-${now}`,
    jobId,
    bidId: quoteFirst.bidId,
  };
  const awardFirst = await call(
      "awardDispatchQuote",
      buyer.token,
      awardData,
  );
  const awardRetry = await call(
      "awardDispatchQuote",
      buyer.token,
      awardData,
  );
  assert.deepEqual(awardRetry, awardFirst);
  const awardedJob = (await db.doc(`dispatch_jobs/${jobId}`).get()).data();
  assert.equal(awardedJob.status, "awarded");
  assert.equal(awardedJob.revision, 3);

  const dispatchActions = [
    {
      token: carrier.token,
      data: {
        requestId: `dispatch-accept-${now}`,
        jobId,
        action: "accept_award",
      },
      status: "accepted",
    },
    {
      token: carrier.token,
      data: {
        requestId: `dispatch-schedule-${now}`,
        jobId,
        action: "schedule",
        scheduledDate: now + 6 * 24 * 60 * 60 * 1000,
      },
      status: "scheduled",
    },
    {
      token: carrier.token,
      data: {
        requestId: `dispatch-transit-${now}`,
        jobId,
        action: "start_transit",
      },
      status: "in_transit",
    },
    {
      token: carrier.token,
      data: {
        requestId: `dispatch-delivered-${now}`,
        jobId,
        action: "mark_delivered",
        receiverName: "Integration Receiver",
        deliveryNote: "Load received at the mapped integration-test yard.",
      },
      status: "delivered",
    },
    {
      token: buyer.token,
      data: {
        requestId: `dispatch-close-${now}`,
        jobId,
        action: "confirm_delivery",
      },
      status: "closed",
    },
  ];
  for (const expected of dispatchActions) {
    const first = await call(
        "updateDispatchTransaction",
        expected.token,
        expected.data,
    );
    const retry = await call(
        "updateDispatchTransaction",
        expected.token,
        expected.data,
    );
    assert.deepEqual(retry, first);
    assert.equal(first.status, expected.status);
  }
  assert.equal(
      (await db.doc(`dispatch_jobs/${jobId}`).get()).data().status,
      "completed",
  );
  assert.equal(
      (await db.doc(`dispatch_transactions/${jobId}`).get()).data().status,
      "closed",
  );
  assert.equal(
      (await db.doc(`dispatch_bids/${quoteFirst.bidId}`).get()).data().status,
      "completed",
  );

  const privacyUser = await createUser("privacy");
  await db.doc(`users/${privacyUser.uid}`).set({
    displayName: "Privacy Integration User",
    accountType: "personal",
    accountStatus: "active",
    userScore: 70,
    accountVerified: false,
  });
  const rememberedDevice = await call(
      "registerAccountDevice",
      privacyUser.token,
      {
        deviceId: "a1b2c3d4-1111-4222-8333-1234567890ab",
        label: "Integration web browser",
        platform: "web",
      },
  );
  assert.equal(rememberedDevice.isNew, true);
  assert.equal(
      (await db.doc(
          `users/${privacyUser.uid}/account_devices/${rememberedDevice.deviceDocumentId}`,
      ).get()).data().status,
      "active",
  );
  const notificationToken = `integration-token-${"a".repeat(80)}`;
  const notificationEndpoint = await call(
      "registerNotificationEndpoint",
      privacyUser.token,
      {
        token: notificationToken,
        platform: "web",
        installationId: "a1b2c3d4-1111-4222-8333-1234567890ab",
      },
  );
  assert.equal(notificationEndpoint.active, true);
  assert.equal(
      (await db.doc(
          `users/${privacyUser.uid}/notification_endpoints/${notificationEndpoint.endpointId}`,
      ).get()).data().status,
      "active",
  );
  assert.equal((await call(
      "unregisterNotificationEndpoint",
      privacyUser.token,
      {
        token: notificationToken,
        platform: "web",
        installationId: "a1b2c3d4-1111-4222-8333-1234567890ab",
      },
  )).active, false);
  assert.equal(
      (await db.doc(
          `users/${privacyUser.uid}/notification_endpoints/${notificationEndpoint.endpointId}`,
      ).get()).data().status,
      "revoked",
  );
  const accountExport = await call(
      "requestAccountDataExport",
      privacyUser.token,
      {},
  );
  assert.equal(accountExport.chunkCount > 0, true);
  const exportSnapshot = await db.doc(
      `account_exports/${accountExport.exportId}`,
  ).get();
  assert.equal(exportSnapshot.data().status, "ready");
  assert.equal(
      (await db.collection(
          `account_exports/${accountExport.exportId}/chunks`,
      ).get()).size,
      accountExport.chunkCount,
  );
  const deletion = await call(
      "requestAccountDeletion",
      privacyUser.token,
      {confirmation: "DELETE MY ACCOUNT"},
  );
  assert.equal(deletion.status, "scheduled");
  assert.equal(
      (await db.doc(`account_deletion_requests/${privacyUser.uid}`).get())
          .data().status,
      "scheduled",
  );
  assert.equal(
      (await call("cancelAccountDeletion", privacyUser.token, {})).status,
      "cancelled",
  );
  assert.equal(
      (await call("revokeAccountSessions", privacyUser.token, {})).revoked,
      true,
  );
  assert.equal(
      (await db.doc(
          `users/${privacyUser.uid}/account_devices/${rememberedDevice.deviceDocumentId}`,
      ).get()).data().status,
      "revoked",
  );

  const wantedListingId = `wanted-request-${now}`;
  const wantedSupplyId = `wanted-supply-${now}`;
  const wantedMatchDocumentId = wantedMatchId(
      wantedListingId,
      wantedSupplyId,
  );
  await Promise.all([
    db.doc(`public_listings/${wantedListingId}`).set({
      sellerUid: buyer.uid,
      transactionType: "Wanted / Seeking",
      status: "active",
      wantedStatus: "open",
      responseCount: 0,
    }),
    db.doc(`public_listings/${wantedSupplyId}`).set({
      sellerUid: seller.uid,
      transactionType: "For Sale",
      status: "active",
    }),
    db.doc(`wanted_matches/${wantedMatchDocumentId}`).set({
      wantedListingId,
      supplyListingId: wantedSupplyId,
      wantedOwnerUid: buyer.uid,
      sellerUid: seller.uid,
      wantedOwnerState: "suggested",
      sellerState: "suggested",
      contactRecorded: false,
      status: "suggested",
      revision: 1,
    }),
    db.doc(`wanted_matches/${wantedMatchDocumentId}/events/1`).set({
      actorRole: "system",
      action: "matched",
      state: "suggested",
      status: "suggested",
      revision: 1,
    }),
  ]);
  const dismissMatch = {
    requestId: `wanted-dismiss-${now}`,
    matchId: wantedMatchDocumentId,
    action: "dismiss",
  };
  const dismissFirst = await call(
      "manageWantedMatch", buyer.token, dismissMatch);
  const dismissRetry = await call(
      "manageWantedMatch", buyer.token, dismissMatch);
  assert.deepEqual(dismissRetry, dismissFirst);
  assert.equal(dismissFirst.state, "dismissed");
  assert.equal((await call("manageWantedMatch", buyer.token, {
    requestId: `wanted-restore-${now}`,
    matchId: wantedMatchDocumentId,
    action: "restore",
  })).state, "suggested");
  const contactMatch = {
    requestId: `wanted-contact-${now}`,
    matchId: wantedMatchDocumentId,
    action: "mark_contacted",
  };
  const contactFirst = await call(
      "manageWantedMatch", seller.token, contactMatch);
  const contactRetry = await call(
      "manageWantedMatch", seller.token, contactMatch);
  assert.deepEqual(contactRetry, contactFirst);
  const managedMatch =
    (await db.doc(`wanted_matches/${wantedMatchDocumentId}`).get()).data();
  assert.equal(managedMatch.wantedOwnerState, "suggested");
  assert.equal(managedMatch.sellerState, "contacted");
  assert.equal(managedMatch.revision, 4);
  assert.equal(
      (await db.doc(`public_listings/${wantedListingId}`).get())
          .data().responseCount,
      1,
  );
  assert.equal(
      (await db.collection(
          `wanted_matches/${wantedMatchDocumentId}/events`).get()).size,
      4,
  );
  await assertCollectionSize(
      `users/${buyer.uid}/notifications`,
      1,
      [["type", "==", "wanted_contact"]],
  );

  const receipts = await db.collection("marketplace_command_receipts").get();
  assert.equal(receipts.size, 50);
  const communicationReceipts = await db
      .collection("communication_command_receipts").get();
  assert.equal(communicationReceipts.size, 3);
  console.log(
      "Callable integration passed: trusted media hashes, duplicate-photo " +
      "and message-safety review signals, private listing drafts, saved listings, " +
      "listing lifecycle, " +
      "Wanted match dismissal, restore, contact history, " +
      "offer completion, auction settlement, bid, Buy It Now, Dispatch revision, " +
      "provider review, quote, award, delivery closure, protected messages/reports/uploads, " +
      "versioned policy publication and acceptance, " +
      "private export, staged deletion, remembered devices, session revocation, " +
      "and retry idempotency.",
  );
} finally {
  await deleteApp(app);
}
