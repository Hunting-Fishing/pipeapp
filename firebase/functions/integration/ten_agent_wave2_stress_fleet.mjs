import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import {mkdirSync, writeFileSync} from "node:fs";
import {createRequire} from "node:module";
import {dirname, resolve} from "node:path";

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
const {createDispatchCredentialMonitor} = require("../dispatch_credential_monitor");
const {createMarketplaceListingLifecycle} = require("../marketplace_listing_lifecycle");
const {createMarketplaceCommands} = require("../marketplace_commands");

const projectId = process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "demo-pipe-buyer-wave2";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
let functionsHost = process.env.FUNCTIONS_EMULATOR_HOST;

if (!functionsHost && process.env.FIREBASE_EMULATOR_HUB) {
  const response = await fetch(
    `http://${process.env.FIREBASE_EMULATOR_HUB}/emulators`,
  );
  const emulators = await response.json();
  if (response.ok && emulators.functions) {
    functionsHost = `${emulators.functions.host}:${emulators.functions.port}`;
  }
}

if (!process.env.FIRESTORE_EMULATOR_HOST ||
    !process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
    !authHost || !functionsHost) {
  throw new Error(
    "Wave 2 Stress Fleet must run inside Auth, Firestore, Functions, and Storage emulators.",
  );
}

const storageBucket = `${projectId}.appspot.com`;
const app = initializeApp(
  {projectId, storageBucket},
  `ten-agent-wave2-${Date.now()}`,
);
const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);
const now = Date.now();

const adminAdapter = {
  firestore: Object.assign(() => db, {
    FieldValue,
    GeoPoint,
    Timestamp,
  }),
  auth: () => auth,
  storage: () => storage,
};

const telemetry = {
  startedAt: new Date().toISOString(),
  projectId,
  wave: "Wave 2 — Concurrency, Stress, Field-Service, Lifecycle & Settlement",
  agents: [],
  phases: [],
  actions: [],
  problemsTested: [],
  summary: {},
};

function recordAction(agentId, phase, action, status, durationMs, details = "") {
  telemetry.actions.push({agentId, phase, action, status, durationMs, details});
}

function recordProblem(agentId, scenario, expected, actual, passed) {
  telemetry.problemsTested.push({agentId, scenario, expected, actual, passed});
}

const PERSONAS = [
  {id: "W2-01", key: "w2_seller_pipe", name: "Athabasca Tubulars", type: "business", verified: true, score: 88},
  {id: "W2-02", key: "w2_seller_equip", name: "Foothills Rig Supply", type: "business", verified: true, score: 90},
  {id: "W2-03", key: "w2_buyer_alpha", name: "Clearwater Drilling", type: "business", verified: true, score: 82},
  {id: "W2-04", key: "w2_buyer_bravo", name: "Pembina Field Ops", type: "business", verified: true, score: 84},
  {id: "W2-05", key: "w2_auction_host", name: "Nisku Surplus Auctions", type: "business", verified: true, score: 92},
  // W2-06 intentionally omits userScore on users/{uid} to verify 70 default fallback!
  {id: "W2-06", key: "w2_new_bidder", name: "Smoky River Wellhead", type: "personal", verified: true, score: null},
  {id: "W2-07", key: "w2_buynow_bidder", name: "Wapiti Energy Services", type: "business", verified: true, score: 85},
  {id: "W2-08", key: "w2_stuck_operator", name: "Muskeg Lease Operator", type: "business", verified: true, score: 86},
  {id: "W2-09", key: "w2_winch_carrier", name: "Swan Hills Winch & Crane", type: "business", verified: true, score: 91},
  {id: "W2-10", key: "w2_blocked_bidder", name: "Blocked Contender", type: "personal", verified: true, score: 75},
];

async function createAgent(p, idx) {
  const t0 = Date.now();
  const email = `${p.key}.${now}@pipebuyer.test`;
  const password = "Wave2Stress!2026#Pass";
  const phone = `+158755531${String(idx + 10).padStart(2, "0")}`;
  const signUpResp = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo-emulator-key`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({email, password, displayName: p.name, returnSecureToken: true}),
    },
  );
  const signUpData = await signUpResp.json();
  const uid = signUpData.localId;
  await auth.updateUser(uid, {
    emailVerified: true,
    phoneNumber: phone,
    displayName: p.name,
  });
  const signInResp = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-emulator-key`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({email, password, returnSecureToken: true}),
    },
  );
  const signInData = await signInResp.json();
  const userDoc = {
    displayName: p.name,
    email,
    accountType: p.type,
    accountStatus: "active",
    baseCommunity: "Grande Prairie, Alberta",
    profileCompletion: 100,
    accountVerified: p.verified,
    accountVerificationReviewVersion: p.verified ? 1 : 0,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (p.score !== null) {
    userDoc.userScore = p.score;
  }
  await db.doc(`users/${uid}`).set(userDoc);
  await db.doc(`public_seller_profiles/${uid}`).set({
    ownerUid: uid,
    displayName: p.name,
    accountType: p.type,
    baseCommunity: "Grande Prairie, Alberta",
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (p.type === "business") {
    await db.doc(`public_business_profiles/${uid}`).set({
      ownerUid: uid,
      publicName: p.name,
      publicPhone: phone,
      publicEmail: email,
      serviceAreaLabel: "Grande Prairie, Alberta and within 350 km",
      serviceArea: {
        mode: "radius",
        center: {latitude: 55.1707, longitude: -118.7886},
        centerLabel: "Grande Prairie, Alberta",
        radiusKm: 350,
        places: [],
      },
      serviceCountryCodes: ["CA"],
      serviceRegionKeys: ["CA-AB"],
      updatedAt: FieldValue.serverTimestamp(),
    });
    await db.doc(`business_private/${uid}`).set({
      ownerUid: uid,
      legalName: `${p.name} Inc.`,
      privateAddress: "204 Industrial Ave, Grande Prairie, AB",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  recordAction(p.id, "Phase 1", "Create Wave 2 Persona", "PASS", Date.now() - t0);
  telemetry.agents.push({id: p.id, uid, role: p.name, omittedScore: p.score === null});
  return {...p, uid, email, phone, token: signInData.idToken};
}

async function rawCall(name, token, data) {
  const t0 = Date.now();
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
  return {ok: response.ok && !payload.error, payload, durationMs: Date.now() - t0};
}

async function call(agentId, phase, label, token, data) {
  const fnName = label.split(" (")[0].trim();
  const {ok, payload, durationMs} = await rawCall(fnName, token, data);
  if (!ok) {
    recordAction(agentId, phase, label, "FAIL", durationMs, JSON.stringify(payload.error || payload));
    throw new Error(`[${agentId}] ${label} failed: ${JSON.stringify(payload)}`);
  }
  recordAction(agentId, phase, label, "PASS", durationMs);
  return payload.result;
}

async function expectError(agentId, phase, scenario, name, token, data, expectedStatus) {
  const {payload, durationMs} = await rawCall(name, token, data);
  const actualStatus = payload.error && payload.error.status;
  const passed = actualStatus === expectedStatus;
  recordAction(agentId, phase, `${name} (Expect ${expectedStatus})`, passed ? "PASS" : "FAIL", durationMs);
  recordProblem(
    agentId,
    scenario,
    expectedStatus,
    `${actualStatus}: ${payload.error ? payload.error.message : "NONE"}`,
    passed,
  );
  assert.equal(actualStatus, expectedStatus, `Expected ${expectedStatus}, got ${JSON.stringify(payload)}`);
  return payload.error;
}

const baseLoc = {
  visibility: "approximate",
  point: {latitude: 55.1707, longitude: -118.7947},
  publicName: "Grande Prairie area, AB",
  nearestTown: "Grande Prairie",
  region: "Alberta",
  country: "Canada",
  address: "Lot 14, Clairmont Industrial Park",
  postalCode: "T8X 5B2",
  accessNotes: "PPE required on yard.",
};

try {
  console.log("=== Wave 2: 10-Agent Stress, Concurrency & Field-Service Fleet ===");
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

  // =========================================================================
  // PHASE 1: Spawn 10 Wave-2 Agents + Verify Omitted userScore (70 Fallback)
  // =========================================================================
  console.log("[Phase 1] Spawning 10 Wave-2 Agents...");
  const agents = [];
  for (let i = 0; i < PERSONAS.length; i++) {
    agents.push(await createAgent(PERSONAS[i], i));
  }
  const [w01, w02, w03, w04, w05, w06, w07, w08, w09, w10] = agents;

  await db.doc(`dispatch_carriers/${w09.uid}`).set({
    ownerUid: w09.uid,
    companyName: w09.name,
    operatingName: w09.name,
    status: "active",
    providerReviewVersion: 1,
    availableForHire: true,
    serviceCountryCodes: ["CA"],
    serviceRegionKeys: ["CA-AB"],
    updatedAt: FieldValue.serverTimestamp(),
  });
  await db.doc(`dispatch_carriers/${w09.uid}/vehicles/winch-crane-1`).set({
    ownerUid: w09.uid,
    name: "Kenworth C500 45-Ton Picker & Winch",
    vehicleType: "Picker Truck",
    maximumPayloadKg: 28000,
    available: true,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await db.doc(`dispatch_memberships/${w09.uid}`).set({
    ownerUid: w09.uid,
    active: true,
    status: "active",
    renewalStatus: "paid",
    paymentIssue: false,
    plan: "monthly",
    subscriptionId: `sub_w2_fleet_${now}`,
    stripeCustomerId: `cus_w2_fleet_${now}`,
    currentPeriodStart: Timestamp.fromMillis(now - 86400000),
    currentPeriodEnd: Timestamp.fromMillis(now + 30 * 86400000),
    lastPaidInvoiceId: `in_w2_fleet_${now}`,
    createdAt: Timestamp.fromMillis(now - 86400000),
    updatedAt: Timestamp.fromMillis(now),
  });
  telemetry.phases.push({phase: "Phase 1: 10-Agent Wave 2 Setup", status: "PASS"});

  // =========================================================================
  // PHASE 2: 5-Agent Simultaneous Auction Bidding Race + Bid vs Buy-It-Now Race
  // =========================================================================
  console.log("[Phase 2] Running 5-Agent Simultaneous Auction Bidding & Buy-It-Now Race...");
  const raceAuctionId = `w2-race-auction-${now}`;
  await call(w05.id, "Phase 2", "createMarketplaceListing", w05.token, {
    listingId: raceAuctionId,
    requestId: `req-${raceAuctionId}`,
    listing: {
      title: "5-1/2 in 20 lb/ft L80 LTC Casing — Timed Buying Race Lot",
      category: "Pipe, Tubing & Materials",
      productType: "Casing",
      pipeSize: "5-1/2 in",
      pipeSchedule: "SCH 80",
      pipeGrade: "L80",
      pipeConnection: "LTC (Long Round Thread)",
      pipeLengthRange: "Range 3 (34-48 ft)",
      transactionType: "Auction",
      price: 10000,
      startingBid: 10000,
      minimumBidIncrement: 500,
      reservePrice: 12000,
      buyItNowPrice: 25000,
      auctionStartAt: now - 60000,
      auctionEndAt: now + 3600000,
      priceBasis: "Total lot",
      quantity: 80,
      condition: "New surplus",
      currency: "CAD",
      description: "Concurrency stress test auction lot.",
    },
    location: baseLoc,
  });

  // 2A: 5 agents simultaneously bid the EXACT same amount ($11,000)
  // Note: W2-06 has omitted userScore on users/{uid}, testing the 70 default fallback!
  const sameAmountContenders = [w01, w02, w03, w04, w06];
  const sameAmountResults = await Promise.all(
    sameAmountContenders.map((b) =>
      rawCall("placeAuctionBid", b.token, {listingId: raceAuctionId, amount: 11000}),
    ),
  );
  const sameAmountWins = sameAmountResults.filter((r) => r.ok);
  const sameAmountRejects = sameAmountResults.filter((r) => !r.ok);
  assert.equal(sameAmountWins.length, 1, `Expected exactly 1 winner on simultaneous $11,000 collision, got ${sameAmountWins.length}`);
  assert.equal(sameAmountRejects.length, 4);
  recordAction("Fleet-Race", "Phase 2", "5-Agent Simultaneous Same-Amount Bid Collision ($11,000)", "PASS", 0, "1 accepted, 4 rejected atomically");
  recordProblem("Fleet-Race", "5 simultaneous identical $11,000 bids in Promise.all", "1 OK, 4 FAILED_PRECONDITION", `${sameAmountWins.length} OK, ${sameAmountRejects.length} rejected`, true);

  // Verify W2-06 (omitted userScore) can explicitly place a valid bid ($11,600)
  await call(w06.id, "Phase 2", "placeAuctionBid (Omitted userScore -> 70 fallback)", w06.token, {
    listingId: raceAuctionId,
    amount: 11600,
  });

  // 2B: 5 agents fire escalating bids simultaneously ($12,500 .. $16,500)
  const escalatingBids = [
    {agent: w01, amount: 12500},
    {agent: w02, amount: 13500},
    {agent: w03, amount: 14500},
    {agent: w04, amount: 15500},
    {agent: w06, amount: 16500},
  ];
  const escalatingResults = await Promise.all(
    escalatingBids.map(({agent, amount}) =>
      rawCall("placeAuctionBid", agent.token, {listingId: raceAuctionId, amount}),
    ),
  );
  const acceptedEscalating = escalatingResults.filter((r) => r.ok);
  assert.ok(acceptedEscalating.length >= 1, "At least one escalating bid must commit");
  const afterStormSnap = await db.doc(`public_listings/${raceAuctionId}`).get();
  const afterStorm = afterStormSnap.data();
  const allBidsSnap = await db.collection("auction_bids").where("listingId", "==", raceAuctionId).get();
  const leadingBids = allBidsSnap.docs.filter((d) => d.data().status === "leading");
  assert.equal(leadingBids.length, 1, `Expected 1 leading bid after storm, got ${leadingBids.length}`);
  assert.equal(leadingBids[0].data().amount, afterStorm.currentBid);
  assert.equal(leadingBids[0].data().bidderUid, afterStorm.highBidderUid);
  const seqNums = allBidsSnap.docs.map((d) => d.data().sequenceNumber).sort((a, b) => a - b);
  assert.deepEqual(seqNums, Array.from({length: allBidsSnap.size}, (_, i) => i + 1), "Sequence numbers must be unique and contiguous");
  recordAction("Fleet-Race", "Phase 2", "5-Agent Simultaneous Escalating Bid Storm", "PASS", 0, `bidCount=${allBidsSnap.size}, currentBid=${afterStorm.currentBid}`);

  // 2C: Simultaneous placeAuctionBid ($18,000) vs buyAuctionNow ($25,000) race
  const [bidRaceRes, buyNowRaceRes] = await Promise.all([
    rawCall("placeAuctionBid", w03.token, {listingId: raceAuctionId, amount: 18000}),
    rawCall("buyAuctionNow", w07.token, {listingId: raceAuctionId}),
  ]);
  assert.equal(buyNowRaceRes.ok, true, `buyAuctionNow should succeed: ${JSON.stringify(buyNowRaceRes.payload)}`);
  const closedListing = (await db.doc(`public_listings/${raceAuctionId}`).get()).data();
  assert.equal(closedListing.auctionStatus, "bought_now");
  assert.equal(closedListing.highBidderUid, w07.uid);
  const closedTx = await db.doc(`auction_transactions/${raceAuctionId}`).get();
  assert.equal(closedTx.exists, true);
  assert.equal(closedTx.data().buyerUid, w07.uid);
  recordAction("Fleet-Race", "Phase 2", "Simultaneous Bid vs Buy-It-Now Race", "PASS", 0, `bidOk=${bidRaceRes.ok}, buyNowWinner=${w07.id}`);
  telemetry.phases.push({phase: "Phase 2: 5-Agent Auction Concurrency & Buy-Now Race", status: "PASS"});

  // =========================================================================
  // PHASE 3: Pair-Block Enforcement on Timed Buying & Dispatch
  // =========================================================================
  console.log("[Phase 3] Verifying Pair-Block Enforcement on Timed Buying & Dispatch...");
  const blockAuctionId = `w2-block-auction-${now}`;
  await call(w05.id, "Phase 3", "createMarketplaceListing", w05.token, {
    listingId: blockAuctionId,
    requestId: `req-${blockAuctionId}`,
    listing: {
      title: "Cat 336 Excavator — Block Enforcement Auction",
      category: "Heavy Equipment",
      productType: "Excavator",
      brand: "Caterpillar",
      model: "336",
      transactionType: "Auction",
      price: 80000,
      startingBid: 80000,
      minimumBidIncrement: 2000,
      buyItNowPrice: 120000,
      auctionStartAt: now - 60000,
      auctionEndAt: now + 3600000,
      priceBasis: "Total asking price",
      quantity: 1,
      condition: "Good working order",
      currency: "CAD",
      description: "Pair block test auction.",
    },
    location: baseLoc,
  });

  const w10Conv = await call(w10.id, "Phase 3", "openMarketplaceConversation", w10.token, {
    listingId: blockAuctionId,
  });
  await call(w05.id, "Phase 3", "setMarketplaceUserBlocked (Block W2-10)", w05.token, {
    conversationId: w10Conv.conversationId,
    blocked: true,
  });

  const bidBlockErr = await expectError(
    w10.id,
    "Phase 3",
    "Blocked user attempting placeAuctionBid on seller's auction",
    "placeAuctionBid",
    w10.token,
    {listingId: blockAuctionId, amount: 82000},
    "PERMISSION_DENIED",
  );
  assert.equal(/blocked/i.test(bidBlockErr.message), false, "Block error must not reveal block to blocked user");

  const buyNowBlockErr = await expectError(
    w10.id,
    "Phase 3",
    "Blocked user attempting buyAuctionNow on seller's auction",
    "buyAuctionNow",
    w10.token,
    {listingId: blockAuctionId},
    "PERMISSION_DENIED",
  );
  assert.equal(/blocked/i.test(buyNowBlockErr.message), false, "Block error must not reveal block to blocked user");

  // Dispatch pair-block enforcement on openDispatchConversation & awardDispatchQuote
  const dispatchBlockJobId = `w2-disp-blk-${now}`;
  await call(w08.id, "Phase 3", "createDispatchJob", w08.token, {
    jobId: dispatchBlockJobId,
    requestId: `req-${dispatchBlockJobId}`,
    title: "Haul 40 Joints of 7 in Casing",
    pickupLabel: "Grande Prairie, AB",
    deliveryLabel: "Dawson Creek, BC",
    pickupPoint: {latitude: 55.1707, longitude: -118.7886},
    deliveryPoint: {latitude: 55.7596, longitude: -120.2377},
    truckingDate: now + 2 * 86400000,
    loadDetails: "40 joints Range 3 casing",
    sourceType: "manual",
    estimatedWeightKg: 18000,
  });
  const blkQuoteRes = await call(w09.id, "Phase 3", "submitDispatchQuote", w09.token, {
    requestId: `quote-${dispatchBlockJobId}`,
    jobId: dispatchBlockJobId,
    vehicleId: "winch-crane-1",
    amount: 2400,
    currency: "CAD",
    availableDate: now + 2 * 86400000,
    note: "Ready with pipe stakes.",
  });

  const bizConv = await call(w08.id, "Phase 3", "openBusinessConversation", w08.token, {
    providerUid: w09.uid,
  });
  await call(w08.id, "Phase 3", "setMarketplaceUserBlocked (Block Carrier W2-09)", w08.token, {
    conversationId: bizConv.conversationId,
    blocked: true,
  });

  await expectError(
    w09.id,
    "Phase 3",
    "Blocked carrier attempting openDispatchConversation",
    "openDispatchConversation",
    w09.token,
    {jobId: dispatchBlockJobId, bidId: blkQuoteRes.bidId},
    "PERMISSION_DENIED",
  );
  await expectError(
    w08.id,
    "Phase 3",
    "Customer attempting awardDispatchQuote while blocking carrier",
    "awardDispatchQuote",
    w08.token,
    {requestId: `awd-blk-${now}`, jobId: dispatchBlockJobId, bidId: blkQuoteRes.bidId},
    "PERMISSION_DENIED",
  );

  // Unblock and verify both succeed
  await call(w08.id, "Phase 3", "setMarketplaceUserBlocked (Unblock Carrier W2-09)", w08.token, {
    conversationId: bizConv.conversationId,
    blocked: false,
  });
  await call(w09.id, "Phase 3", "openDispatchConversation (After Unblock)", w09.token, {
    jobId: dispatchBlockJobId,
    bidId: blkQuoteRes.bidId,
  });
  await call(w08.id, "Phase 3", "awardDispatchQuote (After Unblock)", w08.token, {
    requestId: `awd-ok-${now}`,
    jobId: dispatchBlockJobId,
    bidId: blkQuoteRes.bidId,
  });
  telemetry.phases.push({phase: "Phase 3: Pair-Block Enforcement on Timed Buying & Dispatch", status: "PASS"});

  // =========================================================================
  // PHASE 4: Dispatch R4 Field-Service ("I'm Stuck / Winch-Out / Crane")
  // =========================================================================
  console.log("[Phase 4] Testing Dispatch R4 Field-Service ('I'm Stuck / Winch-Out') + Attachments + Cancel...");
  const fieldJobId = `w2-stuck-field-${now}`;
  const attBytes = Buffer.from(`stuck-truck-lease-road-photo-${now}`);
  const attAuth = await call(w08.id, "Phase 4", "authorizeDispatchRequestUpload", w08.token, {
    requestId: `att-auth-${now}`,
    jobId: fieldJobId,
    contentType: "image/jpeg",
    sizeBytes: attBytes.length,
    originalName: "stuck-rig-mud.jpg",
  });
  await storage.bucket().file(attAuth.storagePath).save(attBytes, {
    contentType: "image/jpeg",
  });
  const attUrl =
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `${encodeURIComponent(attAuth.storagePath)}?alt=media&token=emulator`;
  await call(w08.id, "Phase 4", "confirmMarketplaceUpload", w08.token, {
    authorizationId: attAuth.authorizationId,
    url: attUrl,
  });

  // Problem test: Mixing freight_route + field_service in one request
  await expectError(
    w08.id,
    "Phase 4",
    "Mixing freight transport and on-site field_service codes in one Dispatch request",
    "createDispatchJob",
    w08.token,
    {
      jobId: `mixed-bad-${now}`,
      requestId: `req-mixed-${now}`,
      serviceCodes: ["transport_pipe_hauling", "field_towing_recovery"],
      requestPath: "field_service",
      contactPreference: "phone",
      title: "Invalid Mixed Request",
      pickupLabel: "LSD 06-14-071-06W6",
      truckingDate: now + 86400000,
      loadDetails: "Mixed",
      sourceType: "manual",
      estimatedWeightKg: 5000,
    },
    "INVALID_ARGUMENT",
  );

  // Create valid R4 Field-Service ("I'm stuck / Winch-out + Picker") request
  await call(w08.id, "Phase 4", "createDispatchJob (field_service + attachment)", w08.token, {
    jobId: fieldJobId,
    requestId: `req-${fieldJobId}`,
    serviceCodes: ["field_towing_recovery", "crane_picker_truck"],
    requestPath: "field_service",
    contactPreference: "phone",
    attachments: [
      {
        authorizationId: attAuth.authorizationId,
        url: attUrl,
        name: "stuck-rig-mud.jpg",
      },
    ],
    title: "Urgent Winch-Out & 45T Picker — Stuck Bed Truck on Lease Road",
    pickupLabel: "LSD 06-14-071-06W6 (South of Grande Prairie)",
    pickupPoint: {latitude: 55.08, longitude: -118.82},
    truckingDate: now + 43200000,
    loadDetails: "Loaded tandem bed truck bogged in soft lease approach; winch + picker assist needed.",
    sourceType: "manual",
    estimatedWeightKg: 24000,
  });

  const fieldJobDoc = (await db.doc(`dispatch_jobs/${fieldJobId}`).get()).data();
  assert.equal(fieldJobDoc.requestPath, "field_service");
  assert.equal(fieldJobDoc.routeRelevant, false);
  assert.deepEqual(fieldJobDoc.serviceCodes, ["field_towing_recovery", "crane_picker_truck"]);
  assert.equal(fieldJobDoc.attachmentCount, 1);
  const fieldPrivDoc = (await db.doc(`dispatch_job_private/${fieldJobId}`).get()).data();
  assert.equal(Array.isArray(fieldPrivDoc.requestAttachments) && fieldPrivDoc.requestAttachments.length, 1);

  await new Promise((r) => setTimeout(r, 3200));
  await call(w08.id, "Phase 4", "updateDispatchJob (field_service)", w08.token, {
    requestId: `upd-${fieldJobId}`,
    jobId: fieldJobId,
    serviceCodes: ["field_towing_recovery", "crane_picker_truck"],
    requestPath: "field_service",
    contactPreference: "phone",
    title: "Urgent Winch-Out & 45T Picker — Updated Approach Coordinates",
    pickupLabel: "LSD 06-14-071-06W6 (Mile 14 Forestry Trunk Rd)",
    pickupPoint: {latitude: 55.085, longitude: -118.825},
    truckingDate: now + 43200000,
    loadDetails: "Updated: 2 winch lines recommended.",
    sourceType: "manual",
    estimatedWeightKg: 24000,
  });
  await call(w08.id, "Phase 4", "publishDispatchJob (field_service)", w08.token, {
    requestId: `pub-${fieldJobId}`,
    jobId: fieldJobId,
  });
  await call(w09.id, "Phase 4", "submitDispatchQuote (field_service)", w09.token, {
    requestId: `q-${fieldJobId}`,
    jobId: fieldJobId,
    vehicleId: "winch-crane-1",
    amount: 1850,
    currency: "CAD",
    availableDate: now + 43200000,
    note: "Dispatched C500 picker + winch tractor, 45 mins away.",
  });
  const cancelRes = await call(w08.id, "Phase 4", "cancelDispatchJob", w08.token, {
    requestId: `can-${fieldJobId}`,
    jobId: fieldJobId,
    reason: "Lease operator freed truck with on-site D8 dozer.",
  });
  assert.equal(cancelRes.status, "cancelled");
  telemetry.phases.push({phase: "Phase 4: Dispatch R4 Field-Service, Attachments & Cancellation", status: "PASS"});

  // =========================================================================
  // PHASE 5: >25 MB (30 MB) Walk-Around Video Draft Verification
  // =========================================================================
  console.log("[Phase 5] Verifying 30 MB Walk-Around Video Draft Upload & Publish...");
  const videoDraftId = `w2-video-draft-${now}`;
  await call(w01.id, "Phase 5", "createMarketplaceListingDraft (with 30 MB video)", w01.token, {
    listingId: videoDraftId,
    listing: {
      title: "9-5/8 in 40 lb/ft N80 BTC Casing — With 30 MB Walk-Around Video",
      category: "Pipe, Tubing & Materials",
      productType: "Casing",
      pipeSize: "9-5/8 in",
      pipeSchedule: "STD",
      pipeGrade: "N80",
      pipeConnection: "BTC (Buttress Thread)",
      pipeLengthRange: "Range 3 (34-48 ft)",
      transactionType: "For Sale",
      price: 165,
      priceBasis: "Per joint",
      quantity: 60,
      condition: "Inspected / certified",
      currency: "CAD",
      description: "Full rack walk-around video inspection.",
      mediaPhotoCount: 1,
      hasVideo: true,
      imageUrls: [],
      imageHashes: [],
      thumbnailUrl: null,
      videoUrl: null,
      mediaUploadStatus: "queued",
    },
    location: baseLoc,
  });

  const vPhotoBytes = Buffer.from(`w01-casing-photo-${now}`);
  const vPhotoHash = createHash("sha256").update(vPhotoBytes).digest("hex");
  const vPhotoPath = `listing_media/${w01.uid}/${videoDraftId}/photo_1.jpg`;
  await storage.bucket().file(vPhotoPath).save(vPhotoBytes, {contentType: "image/jpeg"});
  const vPhotoUrl =
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `${encodeURIComponent(vPhotoPath)}?alt=media&token=emulator`;

  // 30 MB video buffer (previously failed against 25 MB server cap!)
  const video30MbBytes = Buffer.alloc(30 * 1024 * 1024, 0x61);
  const vVideoPath = `listing_media/${w01.uid}/${videoDraftId}/video.mp4`;
  await storage.bucket().file(vVideoPath).save(video30MbBytes, {contentType: "video/mp4"});
  const vVideoUrl =
    `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/` +
    `${encodeURIComponent(vVideoPath)}?alt=media&token=emulator`;

  await call(w01.id, "Phase 5", "updateMarketplaceListingDraftMedia (30 MB MP4)", w01.token, {
    listingId: videoDraftId,
    status: "complete",
    imageUrls: [vPhotoUrl],
    imageHashes: [vPhotoHash],
    thumbnailUrl: vPhotoUrl,
    videoUrl: vVideoUrl,
  });
  await call(w01.id, "Phase 5", "publishMarketplaceListingDraft (30 MB MP4)", w01.token, {
    requestId: `pub-vid-${now}`,
    listingId: videoDraftId,
  });
  const pubVideoDoc = (await db.doc(`public_listings/${videoDraftId}`).get()).data();
  assert.equal(pubVideoDoc.status, "active");
  assert.equal(pubVideoDoc.videoUrl, vVideoUrl);
  telemetry.phases.push({phase: "Phase 5: 30 MB Walk-Around Video Draft Verification", status: "PASS"});

  // =========================================================================
  // PHASE 6: External Wire/PO Settlement + Refund Request -> Cancel -> Re-Request
  // =========================================================================
  console.log("[Phase 6] Testing External Wire/PO Settlement & Refund Cancel/Re-Request...");
  const offerId = `w2-offer-ext-${now}`;
  await call(w03.id, "Phase 6", "createMarketplaceOffer", w03.token, {
    requestId: offerId,
    listingId: videoDraftId,
    offeredUnitPrice: 160,
    requestedQuantity: 60,
    truckingPlan: "buyer_arranged",
    note: "Purchasing full 60-joint rack via corporate wire / PO.",
  });
  await call(w01.id, "Phase 6", "acceptMarketplaceOffer", w01.token, {
    offerId,
  });
  const extTxId = offerId;
  for (let attempt = 0; attempt < 25; attempt++) {
    const snap = await db.doc(`marketplace_transactions/${extTxId}`).get();
    if (snap.exists && snap.data().marketplaceFeeSnapshot) break;
    await new Promise((r) => setTimeout(r, 200));
  }

  const buyerExt = await call(w03.id, "Phase 6", "confirmExternalSettlement (Buyer)", w03.token, {
    transactionId: extTxId,
  });
  assert.equal(buyerExt.fullyConfirmed, false);
  assert.equal(buyerExt.buyerConfirmed, true);

  const sellerExt = await call(w01.id, "Phase 6", "confirmExternalSettlement (Seller)", w01.token, {
    transactionId: extTxId,
  });
  assert.equal(sellerExt.fullyConfirmed, true);
  const extSaleDoc = (await db.doc(`marketplace_transactions/${extTxId}`).get()).data();
  assert.ok(extSaleDoc, "Expected marketplace_transactions document after external settlement");

  // Card-paid transaction -> requestMarketplaceRefund -> counterparty blocked from cancelling -> buyer cancels -> buyer re-requests!
  const paidTxId = `w2-paid-tx-${now}`;
  await db.doc(`marketplace_transactions/${paidTxId}`).set({
    listingId: `paid-listing-${now}`,
    buyerUid: w04.uid,
    sellerUid: w02.uid,
    status: "accepted",
    currency: "CAD",
    amount: 5000,
    buyerChargedMinor: 500000,
    refundedMinor: 0,
    paymentProviderStatus: "paid",
    stripeChargeId: "ch_3QWave2TestCharge001",
    financialStatus: "settled",
    updatedAt: FieldValue.serverTimestamp(),
  });

  const refundReq1 = await call(w04.id, "Phase 6", "requestMarketplaceRefund (#1)", w04.token, {
    requestId: `refund-${paidTxId}-1`,
    transactionId: paidTxId,
    reason: "Two joints arrived with damaged threads; requesting partial review.",
  });
  const txAfterReq1 = (await db.doc(`marketplace_transactions/${paidTxId}`).get()).data();
  assert.equal(txAfterReq1.activeFinancialCaseId, refundReq1.caseId);
  assert.equal(txAfterReq1.activeFinancialCaseRequestedByUid, w04.uid);

  await expectError(
    w02.id,
    "Phase 6",
    "Non-requesting seller attempting to cancel buyer's refund review request",
    "cancelMarketplaceRefundRequest",
    w02.token,
    {caseId: refundReq1.caseId},
    "PERMISSION_DENIED",
  );

  await call(w04.id, "Phase 6", "cancelMarketplaceRefundRequest (Buyer)", w04.token, {
    caseId: refundReq1.caseId,
  });
  const txAfterCancel = (await db.doc(`marketplace_transactions/${paidTxId}`).get()).data();
  assert.equal(txAfterCancel.activeFinancialCaseId, null);
  assert.equal(txAfterCancel.activeFinancialCaseRequestedByUid, null);

  const refundReq2 = await call(w04.id, "Phase 6", "requestMarketplaceRefund (#2 Fresh RequestId)", w04.token, {
    requestId: `refund-${paidTxId}-2`,
    transactionId: paidTxId,
    reason: "Re-opening review with tally sheet and thread gauge photos.",
  });
  assert.equal(refundReq2.status, "requested");
  assert.equal(refundReq2.alreadyCreated, false);
  telemetry.phases.push({phase: "Phase 6: External Wire/PO Settlement & Refund Cancel/Re-Request", status: "PASS"});

  // =========================================================================
  // PHASE 7: Scheduled Lifecycle & Credential Monitors + Declined-Offer Deletion
  // =========================================================================
  console.log("[Phase 7] Running Scheduled Lifecycle Jobs, Credential Reminders & Declined-Offer Deletion...");
  // 7A: Dispatch credential expiry schedule + monitor
  const dueDateIso = new Date(Date.now() + 5 * 86400000).toISOString().slice(0, 10);
  await db.doc(`business_private/${w09.uid}`).set({
    ownerUid: w09.uid,
    dispatchCredentialReminderSettings: {enabled: true, reminderDays: [14, 7, 1]},
    dispatchCredentials: {
      cargo_insurance: {
        state: "self_reported_current",
        policyNumber: "CARGO-9921",
        expiryDate: dueDateIso,
      },
    },
  }, {merge: true});
  await call(w09.id, "Phase 7", "syncDispatchCredentialReminderSchedule", w09.token, {});
  const credMonitor = createDispatchCredentialMonitor(adminAdapter);
  const credRun = await credMonitor.monitorCredentialReminders();
  assert.ok(credRun.notifications >= 1, `Expected credential notification, got ${JSON.stringify(credRun)}`);
  recordAction("System-Cron", "Phase 7", "monitorDispatchCredentialReminders", "PASS", 0, `notifications=${credRun.notifications}`);

  // 7B: Marketplace listing expiry + renewal
  const expListingId = `w2-expiring-${now}`;
  await call(w02.id, "Phase 7", "createMarketplaceListing (For Expiry Test)", w02.token, {
    listingId: expListingId,
    requestId: `req-${expListingId}`,
    listing: {
      title: "Gardner Denver Mud Pump — Rental Unit",
      category: "Oilfield & Drilling",
      productType: "Mud Pump",
      transactionType: "For Sale",
      price: 3200,
      priceBasis: "For Rent",
      quantity: 1,
      condition: "Ready for use",
      currency: "CAD",
      description: "Weekly mud pump rental.",
    },
    location: baseLoc,
  });
  await db.doc(`public_listings/${expListingId}`).update({
    expiresAt: Timestamp.fromMillis(Date.now() - 60000),
  });
  const lifecycle = createMarketplaceListingLifecycle(adminAdapter);
  await lifecycle.expireMarketplaceListings();
  assert.equal((await db.doc(`public_listings/${expListingId}`).get()).data().status, "expired");
  await call(w02.id, "Phase 7", "renewMarketplaceListing", w02.token, {
    requestId: `ren-${expListingId}`,
    listingId: expListingId,
  });
  assert.equal((await db.doc(`public_listings/${expListingId}`).get()).data().status, "active");
  recordAction("System-Cron", "Phase 7", "expireMarketplaceListings + renewMarketplaceListing", "PASS", 0);

  // 7C: Timed auction auto-close via finalizeAuctionRecord
  await db.doc(`public_listings/${blockAuctionId}`).update({
    auctionEndAt: Timestamp.fromMillis(Date.now() - 5000),
  });
  const mktCommands = createMarketplaceCommands(adminAdapter);
  await mktCommands.finalizeAuctionRecord(blockAuctionId);
  const autoEnded = (await db.doc(`public_listings/${blockAuctionId}`).get()).data();
  assert.ok(String(autoEnded.auctionStatus || "").startsWith("ended"));
  recordAction("System-Cron", "Phase 7", "monitorTimedAuctions (expireEndedAuctions)", "PASS", 0);

  // 7D: Declined offer NO LONGER blocks account deletion!
  const delAgent = await createAgent({
    id: "W2-Del",
    key: "w2_declined_offer_user",
    name: "Declined Offer Closure Tester",
    type: "personal",
    verified: true,
    score: 75,
  }, 25);
  await db.doc(`offers/declined-offer-${now}`).set({
    listingId: expListingId,
    buyerUid: delAgent.uid,
    sellerUid: w02.uid,
    amount: 2800,
    status: "declined",
    createdAt: FieldValue.serverTimestamp(),
  });
  const delRes = await call(delAgent.id, "Phase 7", "requestAccountDeletion (with declined offer)", delAgent.token, {
    requestId: `del-req-${now}`,
    confirmation: "DELETE MY ACCOUNT",
  });
  assert.equal(delRes.status, "scheduled");
  await call(delAgent.id, "Phase 7", "cancelAccountDeletion", delAgent.token, {
    requestId: `can-del-${now}`,
  });
  telemetry.phases.push({phase: "Phase 7: Scheduled Lifecycle Jobs, Credential Monitor & Declined-Offer Deletion", status: "PASS"});

  telemetry.completedAt = new Date().toISOString();
  telemetry.summary = {
    totalAgents: telemetry.agents.length,
    phasesPassed: telemetry.phases.length,
    totalActions: telemetry.actions.length,
    passedActions: telemetry.actions.filter((a) => a.status === "PASS").length,
    failedActions: telemetry.actions.filter((a) => a.status === "FAIL").length,
    problemsVerified: telemetry.problemsTested.filter((p) => p.passed).length,
  };

  const outPath = resolve(process.cwd(), "build/acceptance/ten-agent-wave2-stress-report.json");
  mkdirSync(dirname(outPath), {recursive: true});
  writeFileSync(outPath, JSON.stringify(telemetry, null, 2));
  console.log("Wave 2 Stress Fleet PASSED:", JSON.stringify(telemetry.summary));
} finally {
  await deleteApp(app);
}
