import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {Timestamp, getFirestore} = require("firebase-admin/firestore");

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
const db = getFirestore(app);
const now = Date.now();

async function createUser(label) {
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
  return {uid: payload.localId, token: payload.idToken};
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

  const receipts = await db.collection("marketplace_command_receipts").get();
  assert.equal(receipts.size, 15);
  console.log(
      "Callable integration passed: listing, offer, auction, bid, Buy It " +
      "Now, Dispatch revision, quote, award, and retry idempotency.",
  );
} finally {
  await deleteApp(app);
}
