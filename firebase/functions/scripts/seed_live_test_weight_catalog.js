"use strict";

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

function loopbackHost(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must point to a local emulator. Refusing value: ${normalized}`);
  }
  return normalized;
}

process.env.FIRESTORE_EMULATOR_HOST = loopbackHost(
    process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:18080",
    "FIRESTORE_EMULATOR_HOST",
);

const projectId = process.env.GCLOUD_PROJECT || "flutter-flow-pipe";
const app = initializeApp({projectId}, `weight-catalog-seed-${Date.now()}`);
const db = getFirestore(app);

async function main() {
  const now = Timestamp.now();
  await db.collection("weight_catalog").doc("equipment_bobcat_s160").set({
    kind: "equipment",
    category: "Heavy Equipment",
    productType: "Skid Steer",
    manufacturer: "Bobcat",
    model: "S160",
    modelYearFrom: 2004,
    modelYearTo: 2013,
    variant: "Multiple archived Bobcat S160 configurations",
    // Bobcat's archived North American specifications list operating weights
    // from 5,752 lb through 8,140 lb across S160 configurations. The resolver
    // deliberately uses the upper reviewed value for planning until the exact
    // machine configuration and transport weight are confirmed.
    operatingWeightMinKg: 2609.06331224,
    operatingWeightMaxKg: 3692.2418918,
    sourceName: "Bobcat Company",
    sourceLabel: "Bobcat archived S160 specifications",
    sourceUrl:
      "https://www.bobcat.com/na/en/equipment/loaders/skid-steer-loaders/non-current-models/s160",
    sourceReference: "S160 Specifications → Operating Weight",
    verificationStatus: "manufacturer source",
    active: true,
    revision: 1,
    legalUse: false,
    visualSandbox: true,
    createdAt: now,
    updatedAt: now,
    updatedByUid: "visual-sandbox-admin",
  }, {merge: true});
  console.log("Seeded reviewed weight catalog example: Bobcat S160 (range)");
}

main()
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(async () => deleteApp(app));
