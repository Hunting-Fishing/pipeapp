"use strict";

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

function requireLoopback(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must target a local emulator. Refusing ${normalized}`);
  }
  return normalized;
}

process.env.FIRESTORE_EMULATOR_HOST = requireLoopback(
    process.env.FIRESTORE_EMULATOR_HOST,
    "FIRESTORE_EMULATOR_HOST",
);

const projectId = process.env.GCLOUD_PROJECT || "flutter-flow-pipe";
const app = initializeApp({projectId}, `listing-analytics-${Date.now()}`);
const db = getFirestore(app);

// Engagement counters are intentionally deterministic for visual acceptance.
// Message/offer totals align with the visible seeded conversation and offer
// fixtures so seller analytics do not imply hidden mock deals.
const fixtures = Object.freeze({
  "visual-pipe-drill": {
    viewCount: 184,
    saveCount: 21,
    shareCount: 8,
    messageCount: 4,
    offerCount: 2,
  },
  "visual-casing": {
    viewCount: 92,
    saveCount: 8,
    shareCount: 3,
    messageCount: 0,
    offerCount: 0,
  },
  "visual-excavator": {
    viewCount: 251,
    saveCount: 34,
    shareCount: 11,
    messageCount: 2,
    offerCount: 0,
  },
  "visual-loader": {
    viewCount: 143,
    saveCount: 16,
    shareCount: 7,
    messageCount: 0,
    offerCount: 0,
  },
  "visual-office": {
    viewCount: 78,
    saveCount: 11,
    shareCount: 2,
    messageCount: 0,
    offerCount: 0,
  },
  "visual-tank": {
    viewCount: 61,
    saveCount: 5,
    shareCount: 1,
    messageCount: 0,
    offerCount: 0,
  },
  "visual-semi": {
    viewCount: 116,
    saveCount: 10,
    shareCount: 6,
    messageCount: 0,
    offerCount: 0,
  },
  "visual-vip-early-tubing": {
    viewCount: 27,
    saveCount: 5,
    shareCount: 2,
    messageCount: 0,
    offerCount: 0,
  },
});

async function main() {
  const entries = Object.entries(fixtures);
  const references = entries.map(([listingId]) =>
    db.collection("public_listings").doc(listingId));
  const snapshots = await db.getAll(...references);
  const missing = snapshots
      .filter((snapshot) => !snapshot.exists)
      .map((snapshot) => snapshot.id);
  if (missing.length) {
    throw new Error(
        `Base visual sandbox must be seeded first. Missing listings: ${missing.join(", ")}`,
    );
  }

  const batch = db.batch();
  entries.forEach(([listingId, analytics]) => {
    batch.update(db.collection("public_listings").doc(listingId), {
      ...analytics,
      analyticsFixtureVersion: 1,
      analyticsFixtureSource: "live_test_sandbox",
    });
  });
  await batch.commit();

  console.log("Listing analytics fixtures seeded.");
  entries.forEach(([listingId, analytics]) => {
    console.log(
        `  ${listingId}: ${analytics.viewCount} views / ` +
        `${analytics.saveCount} saves / ${analytics.messageCount} messages / ` +
        `${analytics.offerCount} offers`,
    );
  });
}

main()
    .then(() => deleteApp(app))
    .catch(async (error) => {
      console.error(error);
      await deleteApp(app).catch(() => {});
      process.exitCode = 1;
    });
