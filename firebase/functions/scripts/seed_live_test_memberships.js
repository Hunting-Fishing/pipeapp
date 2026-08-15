"use strict";

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {GeoPoint, Timestamp, getFirestore} = require("firebase-admin/firestore");

function requireLoopback(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must target a local emulator. Refusing ${normalized}`);
  }
  return normalized;
}

process.env.FIREBASE_AUTH_EMULATOR_HOST = requireLoopback(
    process.env.FIREBASE_AUTH_EMULATOR_HOST,
    "FIREBASE_AUTH_EMULATOR_HOST",
);
process.env.FIRESTORE_EMULATOR_HOST = requireLoopback(
    process.env.FIRESTORE_EMULATOR_HOST,
    "FIRESTORE_EMULATOR_HOST",
);

const projectId = process.env.GCLOUD_PROJECT || "flutter-flow-pipe";
const app = initializeApp({projectId}, `live-test-memberships-${Date.now()}`);
const auth = getAuth(app);
const db = getFirestore(app);
const now = Date.now();
const hour = 60 * 60 * 1000;
const day = 24 * hour;
const password = "PipeBuyerDemo!2026";

async function ensureUser({uid, email, displayName, phoneNumber}) {
  try {
    await auth.getUser(uid);
    await auth.updateUser(uid, {
      email,
      password,
      displayName,
      phoneNumber,
      emailVerified: true,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid,
      email,
      password,
      displayName,
      phoneNumber,
      emailVerified: true,
    });
  }
}

async function main() {
  await ensureUser({
    uid: "visual-standard",
    email: "standard.visual@pipebuyer.test",
    displayName: "Morgan Standard",
    phoneNumber: "+15875550104",
  });

  const batch = db.batch();
  const set = (path, value, merge = true) =>
    batch.set(db.doc(path), value, {merge});

  set("users/visual-buyer", {
    vipActive: true,
    vipStatus: "active",
    membershipTier: "vip",
    vipStartedAt: Timestamp.fromMillis(now - day),
    vipExpiresAt: Timestamp.fromMillis(now + 30 * day),
    membership: {
      tier: "vip",
      status: "active",
      expiresAt: Timestamp.fromMillis(now + 30 * day),
      source: "live_test_sandbox",
    },
  });

  set("users/visual-standard", {
    uid: "visual-standard",
    displayName: "Morgan Standard",
    display_name: "Morgan Standard",
    email: "standard.visual@pipebuyer.test",
    phone_number: "+15875550104",
    verifiedPhoneE164: "+15875550104",
    accountType: "personal",
    preferredContact: "In-app message",
    baseCommunity: "Grande Prairie, Alberta",
    accountVerified: true,
    accountVerificationStatus: "approved",
    profileCompletion: 100,
    roleVersion: 1,
    userScore: 86,
    vipActive: false,
    vipStatus: "inactive",
    membershipTier: "standard",
    visualSandbox: true,
    updatedAt: Timestamp.fromMillis(now),
  }, false);

  set("public_seller_profiles/visual-standard", {
    ownerUid: "visual-standard",
    displayName: "Morgan Standard",
    accountType: "personal",
    baseCommunity: "Grande Prairie, Alberta",
    description: "Standard marketplace member used to verify VIP early-access locking.",
    accountVerified: true,
    visualSandbox: true,
  }, false);

  set("platform_configuration/vip_marketplace_access", {
    enabled: true,
    earlyAccessHours: 24,
    teaserVisibleToStandardUsers: true,
    standardUsersCanOpenLockedListing: false,
    source: "live_test_sandbox",
    updatedAt: Timestamp.fromMillis(now),
  }, false);

  set("public_listings/visual-vip-early-tubing", {
    sellerUid: "visual-seller",
    sellerName: "Prairie Tubular & Equipment",
    sellerVerified: true,
    title: "VIP EARLY ACCESS — 2⅞ in Used Production Tubing — 120 Joints",
    category: "Pipe, Tubing & Materials",
    productType: "Tubing",
    transactionType: "For Sale",
    status: "active",
    condition: "Used — serviceable, class unknown",
    inspectionStatus: "Visual inspection completed",
    pipeSize: "2-7/8 in",
    quantity: 120,
    price: 42,
    initialPrice: 42,
    priceBasis: "Per joint",
    currency: "CAD",
    description: "Fresh live-test listing created specifically to verify the 24-hour VIP early-access window, teaser countdown, offer access and public release transition.",
    imageUrls: [],
    thumbnailUrl: null,
    mediaPhotoCount: 0,
    source: "live_test_sandbox",
    locationVisibility: "approximate",
    publicLocationName: "Grande Prairie area, AB",
    nearestTown: "Grande Prairie",
    region: "Alberta",
    country: "Canada",
    approximateRadiusKm: 10,
    publicGeoPoint: new GeoPoint(55.1707, -118.7947),
    vipEarlyAccessEnabled: true,
    vipEarlyAccessUntil: Timestamp.fromMillis(now + 24 * hour),
    publishedAt: Timestamp.fromMillis(now),
    createdAt: Timestamp.fromMillis(now),
    updatedAt: Timestamp.fromMillis(now),
    visualSandbox: true,
  }, false);

  set("listing_private_locations/visual-vip-early-tubing", {
    ownerUid: "visual-seller",
    exactGeoPoint: new GeoPoint(55.1707, -118.7947),
    fullAddress: "Visual sandbox VIP inventory yard — Grande Prairie, AB",
    nearestTown: "Grande Prairie",
    region: "Alberta",
    country: "Canada",
    accessNotes: "Live-test sandbox only.",
    visibility: "approximate",
    publicName: "Grande Prairie area, AB",
    updatedAt: Timestamp.fromMillis(now),
    visualSandbox: true,
  }, false);

  await batch.commit();
  console.log("VIP live-test memberships seeded.");
  console.log("  VIP:      buyer.visual@pipebuyer.test");
  console.log("  Standard: standard.visual@pipebuyer.test");
  console.log("  Password: PipeBuyerDemo!2026");
  console.log("  Early listing: visual-vip-early-tubing");
}

main()
    .then(() => deleteApp(app))
    .catch(async (error) => {
      console.error(error);
      await deleteApp(app).catch(() => {});
      process.exitCode = 1;
    });
