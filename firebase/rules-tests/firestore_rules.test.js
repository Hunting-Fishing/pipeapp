"use strict";

const assert = require("node:assert/strict");
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
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  Timestamp,
  updateDoc,
} = require("firebase/firestore");

const projectId = "demo-pipe-buyer-rules";
let testEnvironment;

before(async () => {
  const rules = fs.readFileSync(
      path.join(__dirname, "..", "firestore.rules"),
      "utf8",
  );
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules,
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "seller"), {
      accountType: "business",
      accountVerified: true,
      profileCompletion: 100,
      userScore: 100,
    });
    await setDoc(doc(db, "public_listings", "auction"), {
      sellerUid: "seller",
      status: "active",
      transactionType: "Auction",
      auctionStatus: "live",
      currentBid: 100,
      bidCount: 1,
      notifyNewBids: true,
    });
    await setDoc(doc(db, "public_listings", "listing"), {
      sellerUid: "seller",
      status: "active",
      transactionType: "Marketplace",
    });
    await setDoc(doc(db, "offers", "offer"), {
      sellerUid: "seller",
      buyerUid: "buyer",
      listingId: "listing",
      status: "pending",
    });
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test("normal users cannot read or write jurisdiction policies", async () => {
  const userDb = testEnvironment
      .authenticatedContext("ordinary-user")
      .firestore();
  const policy = doc(userDb, "jurisdiction_policies", "ca-ab-test");

  await assertFails(getDoc(policy));
  await assertFails(setDoc(policy, {status: "active"}));
});

test("admin claims can manage control-plane configuration", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", {admin: true})
      .firestore();
  const policy = doc(adminDb, "jurisdiction_policies", "ca-ab-test");

  await assertSucceeds(setDoc(policy, {status: "designOnly"}));
  const snapshot = await assertSucceeds(getDoc(policy));
  assert.equal(snapshot.data().status, "designOnly");
});

test("property listings remain closed even to signed-in clients", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", {admin: true})
      .firestore();
  const listing = doc(adminDb, "property_listings", "not-yet-enabled");

  await assertFails(getDoc(listing));
  await assertFails(setDoc(listing, {status: "draft"}));
});

test("property audit events cannot be forged by client admins", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", {admin: true})
      .firestore();
  const event = doc(adminDb, "property_audit_events", "forged-event");

  await assertFails(setDoc(event, {action: "approved"}));
});

test("auction state and bid records cannot be written by clients", async () => {
  const bidderDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const auction = doc(bidderDb, "public_listings", "auction");
  const bid = doc(bidderDb, "auction_bids", "forged-bid");

  await assertFails(updateDoc(auction, {
    currentBid: 1000,
    highBidderUid: "buyer",
  }));
  await assertFails(setDoc(bid, {
    listingId: "auction",
    sellerUid: "seller",
    bidderUid: "buyer",
    amount: 1000,
    status: "leading",
  }));
});

test("seller cannot accept an offer with a direct client update", async () => {
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const offer = doc(sellerDb, "offers", "offer");

  await assertFails(updateDoc(offer, {
    status: "accepted",
    acceptedByUid: "seller",
  }));
});

test("buyer cannot forge the seller identity on a new offer", async () => {
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const forged = doc(buyerDb, "offers", "forged-offer");

  await assertFails(setDoc(forged, {
    proposedByUid: "buyer",
    buyerUid: "buyer",
    sellerUid: "buyer",
    listingId: "listing",
    status: "pending",
  }));
});

test("seller can still change safe auction notification preferences", async () => {
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const auction = doc(sellerDb, "public_listings", "auction");

  await assertSucceeds(updateDoc(auction, {
    notifyNewBids: false,
    updatedAt: new Date("2026-07-19T12:00:00.000Z"),
  }));
  await assertFails(deleteDoc(auction));
});

test("new auctions must start with clean server-controlled bid state", async () => {
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const auction = doc(sellerDb, "public_listings", "new-auction");
  const validAuction = {
    sellerUid: "seller",
    status: "active",
    transactionType: "Auction",
    auctionStatus: "scheduled",
    auctionStartAt: Timestamp.fromDate(
        new Date("2026-07-20T12:00:00.000Z"),
    ),
    auctionEndAt: Timestamp.fromDate(
        new Date("2026-07-27T12:00:00.000Z"),
    ),
    startingBid: 100,
    minimumBidIncrement: 5,
    currentBid: 0,
    bidCount: 0,
  };

  await assertFails(setDoc(auction, {
    ...validAuction,
    currentBid: 1000,
    highBidderUid: "forged-bidder",
  }));
  await assertSucceeds(setDoc(auction, validAuction));
});
