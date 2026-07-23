import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, Timestamp, getFirestore} = require("firebase-admin/firestore");
const {
  enforceUserRateLimit,
} = require("../abuse_rate_limit");

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

if (!process.env.FIRESTORE_EMULATOR_HOST || !authHost || !functionsHost) {
  throw new Error(
      "Callable integration tests must run inside the Auth, Firestore, and " +
      "Functions emulators.",
  );
}

const app = initializeApp({projectId}, `callable-integration-${Date.now()}`);
const auth = getAuth(app);
const db = getFirestore(app);
const rateLimitAdmin = {firestore: {FieldValue, Timestamp}};
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
    distanceKm: 132.4,
    distanceSource: "integration_route_fixture",
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
    }),
    db.doc(`users/${buyer.uid}`).set({
      displayName: "Production Buyer",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
    }),
    db.doc(`users/${carrier.uid}`).set({
      displayName: "Production Carrier",
      userScore: 90,
      profileCompletion: 100,
      accountVerified: true,
    }),
    db.doc(`dispatch_carriers/${carrier.uid}`).set({
      ownerUid: carrier.uid,
      operatingName: "Integration Transport",
      status: "active",
      availableForHire: true,
    }),
    db.doc(`dispatch_carriers/${carrier.uid}/vehicles/truck-1`).set({
      ownerUid: carrier.uid,
      name: "Integration Truck 1",
      vehicleType: "Tractor",
      maximumPayloadKg: 10000,
      available: true,
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

  const receipts = await db.collection("marketplace_command_receipts").get();
  assert.equal(receipts.size, 37);
  console.log(
      "Callable integration passed: saved listings, listing lifecycle, " +
      "offer completion, auction settlement, bid, Buy It Now, Dispatch revision, " +
      "quote, award, delivery closure, and retry idempotency.",
  );
} finally {
  await deleteApp(app);
}
