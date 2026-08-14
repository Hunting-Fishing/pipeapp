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
const app = initializeApp({projectId}, `dispatch-access-seed-${Date.now()}`);
const db = getFirestore(app);

async function main() {
  const now = Timestamp.now();
  const carrierUid = "visual-carrier";

  await Promise.all([
    db.collection("platform_configuration").doc("phase1_features").set({
      marketplace: true,
      wantedAds: true,
      offers: true,
      auctions: true,
      dispatch: true,
      updatedAt: now,
      source: "live_test_dispatch_access",
    }, {merge: true}),
    db.collection("dispatch_carriers").doc(carrierUid).set({
      ownerUid: carrierUid,
      operatingName: "Northline Heavy Haul",
      companyName: "Northline Heavy Haul Ltd.",
      status: "active",
      availableForHire: true,
      providerReviewVersion: 1,
      reviewRevision: 1,
      privacyVersion: 3,
      reviewedByUid: "visual-sandbox-admin",
      reviewReason: "Approved automatically for the isolated Pipe Buyer integration sandbox.",
      reviewedAt: now,
      updatedAt: now,
      visualSandbox: true,
    }, {merge: true}),
    db.collection("users").doc(carrierUid).set({
      dispatchAccess: true,
      dispatchRole: "carrier",
      isDispatchCarrier: true,
      dispatchProviderStatus: "active",
      dispatchSubscriptionStatus: "active",
      dispatchSubscriptionPlan: "yearly",
      dispatchSubscriptionTestMode: true,
      updatedAt: now,
    }, {merge: true}),
  ]);

  const [flagsSnapshot, carrierSnapshot, userSnapshot] = await Promise.all([
    db.collection("platform_configuration").doc("phase1_features").get(),
    db.collection("dispatch_carriers").doc(carrierUid).get(),
    db.collection("users").doc(carrierUid).get(),
  ]);

  const flags = flagsSnapshot.data() || {};
  const carrier = carrierSnapshot.data() || {};
  const user = userSnapshot.data() || {};
  const failures = [];
  if (flags.dispatch !== true) failures.push("phase1_features.dispatch is not true");
  if (carrier.status !== "active") failures.push("carrier status is not active");
  if (carrier.providerReviewVersion !== 1) failures.push("providerReviewVersion is not 1");
  if (carrier.availableForHire !== true) failures.push("availableForHire is not true");
  if (user.dispatchAccess !== true) failures.push("users.dispatchAccess is not true");
  if (user.dispatchSubscriptionStatus !== "active") {
    failures.push("dispatchSubscriptionStatus is not active");
  }

  if (failures.length) {
    throw new Error(`Dispatch integration fixture failed: ${failures.join("; ")}`);
  }

  console.log("Dispatch sandbox access enabled and verified for carrier.visual@pipebuyer.test");
  console.log("  feature flag            : dispatch=true");
  console.log("  provider status         : active");
  console.log("  providerReviewVersion   : 1");
  console.log("  availableForHire        : true");
  console.log("  user Dispatch access    : true / carrier");
  console.log("  subscription fixture    : active / yearly / test mode");
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await deleteApp(app);
  });
