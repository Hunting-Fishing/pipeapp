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
  writeBatch,
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
    await setDoc(doc(db, "conversations", "conversation"), {
      memberUids: ["buyer", "seller"],
      listingId: "listing",
      sellerUid: "seller",
      messageCount: 0,
      unreadCounts: {buyer: 0, seller: 0},
    });
    await setDoc(doc(db, "auction_private", "auction"), {
      ownerUid: "seller",
      reservePrice: 175,
    });
    await setDoc(doc(db, "dispatch_carriers", "carrier"), {
      ownerUid: "carrier",
      operatingName: "Test Carrier",
      status: "active",
      availableForHire: true,
    });
    await setDoc(
        doc(db, "dispatch_carriers", "carrier", "vehicles", "truck"),
        {
          ownerUid: "carrier",
          name: "Truck 1",
          maximumPayloadKg: 25000,
          available: true,
        },
    );
    await setDoc(doc(db, "dispatch_jobs", "job"), {
      createdByUid: "buyer",
      title: "Pipe load",
      pickupLabel: "Grande Prairie",
      deliveryLabel: "Dawson Creek",
      loadDetails: "54 joints",
      status: "open",
      bidCount: 1,
      revision: 1,
    });
    await setDoc(doc(db, "dispatch_bids", "bid"), {
      jobId: "job",
      carrierUid: "carrier",
      amount: 2500,
      status: "pending",
      revision: 1,
      vehicleId: "truck",
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

test("conversation participants cannot replace members or forge negotiation state", async () => {
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const conversation = doc(buyerDb, "conversations", "conversation");

  await assertFails(updateDoc(conversation, {
    memberUids: ["buyer", "attacker"],
  }));
  await assertFails(updateDoc(conversation, {
    latestNegotiation: {
      unitPrice: 1,
      proposedByUid: "buyer",
    },
  }));
  await assertSucceeds(updateDoc(conversation, {
    unreadCounts: {buyer: 0, seller: 0},
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
  await assertFails(setDoc(
      doc(buyerDb, "offers", "direct-client-offer"),
      {
        proposedByUid: "buyer",
        buyerUid: "buyer",
        sellerUid: "seller",
        listingId: "listing",
        offeredUnitPrice: 70,
        requestedQuantity: 54,
        status: "pending",
      },
  ));
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
  await assertFails(setDoc(auction, {
    ...validAuction,
    reservePrice: 175,
  }));

  const privateAuction = doc(sellerDb, "auction_private", "new-auction");
  const batch = writeBatch(sellerDb);
  batch.set(auction, validAuction);
  batch.set(privateAuction, {
    ownerUid: "seller",
    reservePrice: 175,
  });
  await assertSucceeds(batch.commit());
  const privateSnapshot = await assertSucceeds(getDoc(privateAuction));
  assert.equal(privateSnapshot.data().reservePrice, 175);
});

test("only the auction owner can read the reserve amount", async () => {
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();

  await assertSucceeds(
      getDoc(doc(sellerDb, "auction_private", "auction")),
  );
  await assertFails(
      getDoc(doc(buyerDb, "auction_private", "auction")),
  );
});

test("Dispatch quote and award state cannot be forged by clients", async () => {
  const carrierDb = testEnvironment
      .authenticatedContext("carrier")
      .firestore();
  const ownerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();

  await assertFails(setDoc(doc(carrierDb, "dispatch_bids", "forged"), {
    jobId: "job",
    carrierUid: "carrier",
    amount: 1,
    status: "pending",
    revision: 1,
    vehicleId: "truck",
  }));
  await assertFails(updateDoc(doc(carrierDb, "dispatch_bids", "bid"), {
    amount: 1,
    revision: 2,
  }));
  await assertFails(updateDoc(doc(ownerDb, "dispatch_jobs", "job"), {
    status: "awarded",
    awardedBidId: "bid",
    awardedCarrierUid: "carrier",
    awardedAmount: 1,
    revision: 2,
  }));
  await assertSucceeds(updateDoc(doc(ownerDb, "dispatch_jobs", "job"), {
    title: "Updated pipe load",
    revision: 2,
    updatedAt: Timestamp.fromDate(
        new Date("2026-07-19T12:00:00.000Z"),
    ),
  }));
});
