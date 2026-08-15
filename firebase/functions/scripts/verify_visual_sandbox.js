"use strict";

// Verifies the deterministic Pipe Buyer visual sandbox through the Firebase
// Admin SDK pointed at local emulators. This intentionally avoids the public
// Firestore REST surface because public client reads are evaluated by security
// rules and are not an administrative fixture-inspection API.

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

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

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "flutter-flow-pipe";
if (projectId !== "flutter-flow-pipe") {
  throw new Error(`Visual sandbox verification requires flutter-flow-pipe, not ${projectId}.`);
}

const app = initializeApp({projectId}, `visual-sandbox-verifier-${Date.now()}`);
const auth = getAuth(app);
const db = getFirestore(app);

const minimumCounts = Object.freeze({
  public_listings: 11,
  users: 4,
  conversations: 2,
  offers: 2,
  dispatch_jobs: 2,
  dispatch_carriers: 1,
});

const expectedAccounts = Object.freeze([
  "buyer.visual@pipebuyer.test",
  "standard.visual@pipebuyer.test",
  "seller.visual@pipebuyer.test",
  "carrier.visual@pipebuyer.test",
]);

async function collectionCount(name) {
  const snapshot = await db.collection(name).get();
  return snapshot.size;
}

async function main() {
  const counts = {};
  for (const collection of Object.keys(minimumCounts)) {
    counts[collection] = await collectionCount(collection);
  }

  console.log("Seeded Firestore fixture counts:");
  for (const [collection, count] of Object.entries(counts)) {
    console.log(`  ${collection.padEnd(20)} ${count}`);
    if (count < minimumCounts[collection]) {
      throw new Error(
          `Expected at least ${minimumCounts[collection]} documents in ${collection}, found ${count}.`,
      );
    }
  }

  const vipListing = await db.doc("public_listings/visual-vip-early-tubing").get();
  if (!vipListing.exists) {
    throw new Error("VIP early-access listing fixture is missing.");
  }

  console.log("Seeded Auth fixtures:");
  for (const email of expectedAccounts) {
    const user = await auth.getUserByEmail(email);
    if (user.disabled) throw new Error(`Fixture account is disabled: ${email}`);
    console.log(`  ${email}`);
  }

  console.log("Formal Pipe Buyer sandbox fixture verification passed.");
}

main()
    .then(() => deleteApp(app))
    .catch(async (error) => {
      console.error(error && error.stack ? error.stack : error);
      await deleteApp(app).catch(() => {});
      process.exitCode = 1;
    });
