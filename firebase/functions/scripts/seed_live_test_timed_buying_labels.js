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
if (projectId !== "flutter-flow-pipe") {
  throw new Error(`Timed Buying sandbox labels require flutter-flow-pipe, not ${projectId}.`);
}

const app = initializeApp({projectId}, `timed-buying-labels-${Date.now()}`);
const db = getFirestore(app);

const labels = Object.freeze({
  "visual-auction-dozer": {
    title: "Timed Buying — CAT D6 Dozer",
    description: "CAT D6 dozer offered through Pipe Buyer Timed Buying with a defined closing time and visible timed-offer activity.",
  },
  "visual-auction-upcoming": {
    title: "Timed Buying — 2020 Bobcat T76",
    description: "Upcoming Pipe Buyer Timed Buying listing for a 2020 compact track loader.",
  },
  "visual-auction-ended": {
    title: "Timed Buying Closed — 48 ft Step Deck Trailer",
    description: "Completed Timed Buying example retained locally for closed-listing acceptance testing.",
  },
});

async function main() {
  const batch = db.batch();
  for (const [listingId, publicCopy] of Object.entries(labels)) {
    const ref = db.collection("public_listings").doc(listingId);
    const snapshot = await ref.get();
    if (!snapshot.exists) {
      throw new Error(`Base visual sandbox is missing ${listingId}.`);
    }
    batch.update(ref, {
      ...publicCopy,
      publicSaleFormatLabel: "Timed Buying",
      publicOfferActionLabel: "Timed Offer",
      timedBuyingLabelVersion: 1,
    });
  }
  await batch.commit();
  console.log("Timed Buying public sandbox labels seeded.");
  for (const [listingId, value] of Object.entries(labels)) {
    console.log(`  ${listingId}: ${value.title}`);
  }
}

main()
    .then(() => deleteApp(app))
    .catch(async (error) => {
      console.error(error && error.stack ? error.stack : error);
      await deleteApp(app).catch(() => {});
      process.exitCode = 1;
    });
