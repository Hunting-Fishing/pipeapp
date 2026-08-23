"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  after,
  before,
  beforeEach,
  test,
} = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-rules";
let testEnvironment;

const administratorClaims = {
  admin: true,
  role: "administrator",
  firebase: {sign_in_second_factor: "phone"},
};

before(async () => {
  const rules = fs.readFileSync(
      path.join(__dirname, "..", "firestore.rules"),
      "utf8",
  );
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {rules, host: "127.0.0.1", port: 8080},
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "platform_configuration", "phase1_features"), {
      marketplace: true,
      wantedAds: true,
      offers: true,
      auctions: true,
      dispatch: true,
      paidFeatures: true,
      regulatedListings: false,
      revision: 1,
    });
    await setDoc(doc(db, "marketplace_transactions", "fee-transaction"), {
      buyerUid: "buyer",
      sellerUid: "seller",
      status: "pending_completion",
      externalSettlementBuyerConfirmed: true,
      externalSettlementSellerConfirmed: true,
      marketplaceFeeStatus: "collected",
      stripeMarketplaceFeeSessionId: "cs_rules_test",
      stripeMarketplaceFeePaymentIntentId: "pi_rules_test",
      stripeMarketplaceFeeChargeId: "ch_rules_test",
      marketplaceFeeProviderFeeMinor: 100,
      marketplaceFeeProviderNetMinor: 2400,
    });
    await setDoc(doc(db, "dispatch_subscriptions", "subscriber"), {
      plan: "monthly",
      status: "active",
      entitlementActive: true,
      stripeCheckoutSessionId: "cs_dispatch_rules",
      stripeSubscriptionId: "sub_dispatch_rules",
      stripeCustomerId: "cus_dispatch_rules",
    });
    await setDoc(doc(
        db,
        "subscription_checkout_sessions",
        "cs_dispatch_rules",
    ), {
      uid: "subscriber",
      plan: "monthly",
      status: "active",
      stripeSubscriptionId: "sub_dispatch_rules",
    });
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test("buyer and seller can read their own marketplace transaction", async () => {
  for (const uid of ["buyer", "seller"]) {
    const db = testEnvironment.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(
        db,
        "marketplace_transactions",
        "fee-transaction",
    )));
  }
});

test("unrelated authenticated user cannot read financial transaction evidence", async () => {
  const db = testEnvironment.authenticatedContext("outsider").firestore();
  await assertFails(getDoc(doc(
      db,
      "marketplace_transactions",
      "fee-transaction",
  )));
});

test("MFA administrator can read and query the settlement fee queue", async () => {
  const db = testEnvironment
      .authenticatedContext("admin-user", administratorClaims)
      .firestore();
  await assertSucceeds(getDoc(doc(
      db,
      "marketplace_transactions",
      "fee-transaction",
  )));
  const feeQueue = query(
      collection(db, "marketplace_transactions"),
      where("externalSettlementBuyerConfirmed", "==", true),
  );
  const snapshot = await assertSucceeds(getDocs(feeQueue));
  if (snapshot.size !== 1) {
    throw new Error(`Expected one admin fee transaction; received ${snapshot.size}.`);
  }
});

test("ordinary user cannot run the administrator fee-queue query", async () => {
  const db = testEnvironment.authenticatedContext("outsider").firestore();
  const feeQueue = query(
      collection(db, "marketplace_transactions"),
      where("externalSettlementBuyerConfirmed", "==", true),
  );
  await assertFails(getDocs(feeQueue));
});

test("clients cannot mutate authoritative settlement financial state", async () => {
  for (const [uid, claims] of [
    ["seller", undefined],
    ["admin-user", administratorClaims],
  ]) {
    const db = testEnvironment.authenticatedContext(uid, claims).firestore();
    await assertFails(updateDoc(doc(
        db,
        "marketplace_transactions",
        "fee-transaction",
    ), {
      marketplaceFeeStatus: "collected",
      stripeMarketplaceFeeChargeId: "ch_client_forged",
    }));
  }
});

test("Dispatch subscription provider state is never client-readable", async () => {
  for (const [uid, claims] of [
    ["subscriber", undefined],
    ["outsider", undefined],
    ["admin-user", administratorClaims],
  ]) {
    const db = testEnvironment.authenticatedContext(uid, claims).firestore();
    await assertFails(getDoc(doc(db, "dispatch_subscriptions", "subscriber")));
    await assertFails(getDoc(doc(
        db,
        "subscription_checkout_sessions",
        "cs_dispatch_rules",
    )));
  }
});

test("clients cannot forge Dispatch entitlement or Checkout provider evidence", async () => {
  for (const [uid, claims] of [
    ["subscriber", undefined],
    ["admin-user", administratorClaims],
  ]) {
    const db = testEnvironment.authenticatedContext(uid, claims).firestore();
    await assertFails(updateDoc(doc(db, "dispatch_subscriptions", "subscriber"), {
      status: "active",
      entitlementActive: true,
      stripeSubscriptionId: "sub_client_forged",
    }));
    await assertFails(updateDoc(doc(
        db,
        "subscription_checkout_sessions",
        "cs_dispatch_rules",
    ), {
      status: "active",
      stripeSubscriptionId: "sub_client_forged",
    }));
  }
});
