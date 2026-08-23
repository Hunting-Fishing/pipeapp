"use strict";

const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");

function requireLoopback(value, label) {
  const normalized = String(value || "").trim();
  if (!/^(127\.0\.0\.1|localhost):\d+$/.test(normalized)) {
    throw new Error(`${label} must target a local emulator. Refusing ${normalized}`);
  }
  return normalized;
}

process.env.FIREBASE_AUTH_EMULATOR_HOST = requireLoopback(
    process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:19099",
    "FIREBASE_AUTH_EMULATOR_HOST",
);

const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || "flutter-flow-pipe";
if (projectId !== "flutter-flow-pipe") {
  throw new Error(`Formal demo Auth repair requires flutter-flow-pipe, not ${projectId}.`);
}

const password = "PipeBuyerDemo!2026";
const users = [
  {
    uid: "visual-buyer",
    email: "buyer.visual@pipebuyer.test",
    displayName: "Alex Buyer",
    phoneNumber: "+15875550101",
  },
  {
    uid: "visual-standard",
    email: "standard.visual@pipebuyer.test",
    displayName: "Morgan Standard",
    phoneNumber: "+15875550104",
  },
  {
    uid: "visual-seller",
    email: "seller.visual@pipebuyer.test",
    displayName: "Prairie Tubular & Equipment",
    phoneNumber: "+15875550102",
  },
  {
    uid: "visual-carrier",
    email: "carrier.visual@pipebuyer.test",
    displayName: "Northline Heavy Haul",
    phoneNumber: "+17805550103",
  },
];

const app = initializeApp({projectId}, `formal-demo-auth-${Date.now()}`);
const auth = getAuth(app);

async function ensureUser(user) {
  try {
    await auth.getUser(user.uid);
    await auth.updateUser(user.uid, {
      email: user.email,
      password,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      emailVerified: true,
      disabled: false,
    });
    console.log(`  refreshed ${user.email}`);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid: user.uid,
      email: user.email,
      password,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      emailVerified: true,
      disabled: false,
    });
    console.log(`  created   ${user.email}`);
  }
}

async function main() {
  console.log("Ensuring formal demo Auth accounts only; Firestore fixtures are not modified.");
  for (const user of users) await ensureUser(user);
  console.log("FORMAL_DEMO_AUTH_ACCOUNTS_ENSURED");
}

main()
    .then(() => deleteApp(app))
    .catch(async (error) => {
      console.error(error?.stack || error);
      await deleteApp(app).catch(() => {});
      process.exitCode = 1;
    });
