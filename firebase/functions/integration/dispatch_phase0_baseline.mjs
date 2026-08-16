import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {
  GeoPoint,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {createDispatchCommands} = require("../dispatch_commands");

function requireLoopback(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must target a local emulator. Refusing ${normalized}`);
  }
  return normalized;
}

const authHost = requireLoopback(
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
    "FIREBASE_AUTH_EMULATOR_HOST",
);
const firestoreHost = requireLoopback(
    process.env.FIRESTORE_EMULATOR_HOST,
    "FIRESTORE_EMULATOR_HOST",
);
const functionsHost = requireLoopback(
    process.env.FUNCTIONS_EMULATOR_HOST,
    "FUNCTIONS_EMULATOR_HOST",
);
const projectId = process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "flutter-flow-pipe";
if (projectId !== "flutter-flow-pipe") {
  throw new Error(`Dispatch baseline requires flutter-flow-pipe, not ${projectId}.`);
}

const runId = Date.now();
const app = initializeApp({projectId}, `dispatch-phase0-${runId}`);
const auth = getAuth(app);
const db = getFirestore(app);
const commandFirestore = Object.assign(
    () => db,
    {GeoPoint, Timestamp, FieldValue: require("firebase-admin/firestore").FieldValue},
);
const dispatchCommands = createDispatchCommands({
  firestore: commandFirestore,
  auth: () => auth,
});

async function signUp(label, phoneSuffix) {
  const email = `dispatch-phase0-${label}-${runId}@pipe.test`;
  const password = "DispatchBaseline!2026";
  const signup = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=dispatch-phase0`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const signupBody = await signup.json();
  if (!signup.ok || !signupBody.localId) {
    throw new Error(`Auth signup failed: ${JSON.stringify(signupBody)}`);
  }
  await auth.updateUser(signupBody.localId, {
    emailVerified: true,
    phoneNumber: `+15555557${phoneSuffix}`,
  });
  const signin = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=dispatch-phase0`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const signinBody = await signin.json();
  if (!signin.ok || !signinBody.idToken) {
    throw new Error(`Auth sign-in failed: ${JSON.stringify(signinBody)}`);
  }
  return {uid: signupBody.localId, token: signinBody.idToken, email};
}

async function call(name, token, data) {
  const response = await fetch(
      `http://${functionsHost}/${projectId}/us-central1/${name}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({data}),
      },
  );
  const payload = await response.json();
  if (!response.ok || payload.error) {
    throw new Error(`${name} failed (${response.status}): ${JSON.stringify(payload)}`);
  }
  return payload.result;
}

async function firestoreGet(path, token) {
  return fetch(
      `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${path}`,
      {headers: {authorization: `Bearer ${token}`}},
  );
}

async function deleteQuery(query) {
  const snapshot = await query.get();
  if (snapshot.empty) return;
  const batch = db.batch();
  for (const document of snapshot.docs) batch.delete(document.ref);
  await batch.commit();
}

async function deleteDocAndChildren(path, childCollections = []) {
  const ref = db.doc(path);
  for (const child of childCollections) {
    await deleteQuery(ref.collection(child));
  }
  await ref.delete().catch(() => {});
}

let buyer;
let carrier;
let jobId;
let bidId;

try {
  console.log("Dispatch Phase 0 baseline: creating isolated Auth users");
  [buyer, carrier] = await Promise.all([
    signUp("buyer", "101"),
    signUp("carrier", "102"),
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
  }, {merge: true});
  await Promise.all([
    db.doc(`users/${buyer.uid}`).set({
      displayName: "Dispatch Baseline Buyer",
      accountVerified: true,
      userScore: 95,
      profileCompletion: 100,
    }, {merge: true}),
    db.doc(`users/${carrier.uid}`).set({
      displayName: "Dispatch Baseline Carrier",
      accountVerified: true,
      userScore: 95,
      profileCompletion: 100,
    }, {merge: true}),
    db.doc("administrator_roles/dispatch-phase0-admin").set({
      active: true,
      role: "administrator",
    }, {merge: true}),
  ]);

  console.log("Dispatch Phase 0 baseline: provider signup and approval");
  const providerData = {
    requestId: `provider-${runId}`,
    operatingName: "Phase 0 Transport",
    companyName: "Phase 0 Transport Ltd.",
    serviceAreaLabel: "Grande Prairie and within 300 km",
    serviceArea: {
      mode: "radius",
      center: {latitude: 55.1707, longitude: -118.7947},
      centerLabel: "Grande Prairie, Alberta",
      radiusKm: 300,
      places: [],
    },
  };
  const submitted = await call(
      "submitDispatchProviderApplication",
      carrier.token,
      providerData,
  );
  assert.equal(submitted.status, "pending_review");
  assert.equal(submitted.submitted, true);

  const providerSnapshot = await db.doc(`dispatch_carriers/${carrier.uid}`).get();
  assert.equal(providerSnapshot.exists, true);
  assert.equal(providerSnapshot.data().status, "pending_review");

  const approved = await dispatchCommands.reviewDispatchProvider({
    auth: {
      uid: "dispatch-phase0-admin",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data: {
      requestId: `provider-review-${runId}`,
      providerUid: carrier.uid,
      decision: "approved",
      reason: "Phase 0 baseline approval for local emulator regression testing.",
    },
  });
  assert.equal(approved.status, "active");

  const activeProvider = (await db.doc(`dispatch_carriers/${carrier.uid}`).get()).data();
  assert.equal(activeProvider.status, "active");
  assert.equal(activeProvider.availableForHire, true);
  assert.equal(activeProvider.providerReviewVersion, 1);

  await db.doc(`dispatch_carriers/${carrier.uid}/vehicles/truck-1`).set({
    ownerUid: carrier.uid,
    name: "Phase 0 Lowboy",
    vehicleType: "Lowboy",
    maximumPayloadKg: 36000,
    tareWeightKg: 12000,
    grossWeightKg: 48000,
    calculatedPayloadKg: 36000,
    weightSource: "manufacturer",
    services: ["Lowboy", "Heavy equipment", "Oversize load"],
    pilotTruck: false,
    available: true,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });

  console.log("Dispatch Phase 0 baseline: authenticated provider profile rule check");
  const carrierOwnProfile = await firestoreGet(
      `dispatch_carriers/${carrier.uid}`,
      carrier.token,
  );
  assert.equal(carrierOwnProfile.status, 200, "carrier should read own provider profile");
  const buyerCarrierProfile = await firestoreGet(
      `dispatch_carriers/${carrier.uid}`,
      buyer.token,
  );
  assert.equal(buyerCarrierProfile.status, 403, "unrelated buyer should not read private provider enrollment");

  console.log("Dispatch Phase 0 baseline: create manual job and prove retry safety");
  jobId = `dispatch-phase0-job-${runId}`;
  const jobData = {
    requestId: `job-create-${runId}`,
    jobId,
    title: "Phase 0 equipment move",
    pickupLabel: "Grande Prairie yard",
    deliveryLabel: "Dawson Creek yard",
    truckingDate: Date.now() + 7 * 24 * 60 * 60 * 1000,
    loadDetails: "Emulator-only Phase 0 baseline load.",
    sourceType: "manual",
    estimatedWeightKg: 22000,
    pickupPoint: {latitude: 55.1707, longitude: -118.7947},
    deliveryPoint: {latitude: 55.7596, longitude: -120.2377},
  };
  const jobFirst = await call("createDispatchJob", buyer.token, jobData);
  const jobRetry = await call("createDispatchJob", buyer.token, jobData);
  assert.deepEqual(jobRetry, jobFirst);
  assert.equal(jobFirst.status, "open");

  const publicJob = (await db.doc(`dispatch_jobs/${jobId}`).get()).data();
  const privateJob = (await db.doc(`dispatch_job_private/${jobId}`).get()).data();
  assert.equal(publicJob.createdByUid, buyer.uid);
  assert.equal(publicJob.sourceType, "manual");
  assert.equal(publicJob.status, "open");
  assert.equal(privateJob.createdByUid, buyer.uid);
  assert.equal(privateJob.pickupPoint instanceof GeoPoint, true);

  const carrierJobRead = await firestoreGet(`dispatch_jobs/${jobId}`, carrier.token);
  assert.equal(carrierJobRead.status, 200, "signed-in carrier should read open Dispatch job");
  const buyerPrivateRead = await firestoreGet(`dispatch_job_private/${jobId}`, buyer.token);
  assert.equal(buyerPrivateRead.status, 200, "job owner should read private route data");
  const carrierPrivateBeforeAward = await firestoreGet(
      `dispatch_job_private/${jobId}`,
      carrier.token,
  );
  assert.equal(
      carrierPrivateBeforeAward.status,
      403,
      "carrier must not read private route data before award",
  );

  console.log("Dispatch Phase 0 baseline: carrier quote and retry safety");
  const quoteData = {
    requestId: `quote-${runId}`,
    jobId,
    vehicleId: "truck-1",
    amount: 2450,
    note: "Phase 0 baseline carrier quote.",
    availableDate: Date.now() + 6 * 24 * 60 * 60 * 1000,
  };
  const quoteFirst = await call("submitDispatchQuote", carrier.token, quoteData);
  const quoteRetry = await call("submitDispatchQuote", carrier.token, quoteData);
  assert.deepEqual(quoteRetry, quoteFirst);
  bidId = quoteFirst.bidId;
  assert.ok(bidId);
  const bid = (await db.doc(`dispatch_bids/${bidId}`).get()).data();
  assert.equal(bid.carrierUid, carrier.uid);
  assert.equal(bid.jobId, jobId);
  assert.equal(bid.status, "pending");

  console.log("Dispatch Phase 0 baseline: customer award and participant transaction");
  const awardData = {
    requestId: `award-${runId}`,
    jobId,
    bidId,
  };
  const awardFirst = await call("awardDispatchQuote", buyer.token, awardData);
  const awardRetry = await call("awardDispatchQuote", buyer.token, awardData);
  assert.deepEqual(awardRetry, awardFirst);

  const awardedJob = (await db.doc(`dispatch_jobs/${jobId}`).get()).data();
  assert.equal(awardedJob.status, "awarded");
  assert.equal(awardedJob.awardedCarrierUid, carrier.uid);
  const transaction = (await db.doc(`dispatch_transactions/${jobId}`).get()).data();
  assert.equal(transaction.status, "awarded");
  assert.equal(transaction.customerUid, buyer.uid);
  assert.equal(transaction.carrierUid, carrier.uid);
  assert.equal(transaction.bidId, bidId);

  const carrierPrivateAfterAward = await firestoreGet(
      `dispatch_job_private/${jobId}`,
      carrier.token,
  );
  assert.equal(
      carrierPrivateAfterAward.status,
      200,
      "awarded carrier should read participant-only private route data",
  );

  console.log("DISPATCH PHASE 0 EMULATOR BASELINE PASSED");
} finally {
  console.log("Dispatch Phase 0 baseline: cleaning isolated test records");
  if (jobId) {
    await deleteDocAndChildren(`dispatch_transactions/${jobId}`, ["revisions"]);
    await deleteDocAndChildren(`dispatch_job_private/${jobId}`, ["revisions"]);
    await deleteDocAndChildren(`dispatch_jobs/${jobId}`, ["revisions"]);
  }
  if (bidId) await deleteDocAndChildren(`dispatch_bids/${bidId}`, ["revisions"]);
  if (carrier) {
    await deleteDocAndChildren(`dispatch_carriers/${carrier.uid}`, ["vehicles", "saved_quotes"]);
    await deleteQuery(
        db.collection("dispatch_provider_review_events")
            .where("providerUid", "==", carrier.uid),
    ).catch(() => {});
    await deleteDocAndChildren(`users/${carrier.uid}`, ["notifications"]);
    await auth.deleteUser(carrier.uid).catch(() => {});
  }
  if (buyer) {
    await deleteDocAndChildren(`users/${buyer.uid}`, ["notifications"]);
    await auth.deleteUser(buyer.uid).catch(() => {});
  }
  await deleteDocAndChildren("administrator_roles/dispatch-phase0-admin");
  const actors = [buyer?.uid, carrier?.uid, "dispatch-phase0-admin"].filter(Boolean);
  for (const actorUid of actors) {
    await deleteQuery(
        db.collection("marketplace_command_receipts")
            .where("actorUid", "==", actorUid),
    ).catch(() => {});
  }
  await deleteApp(app).catch(() => {});
}
