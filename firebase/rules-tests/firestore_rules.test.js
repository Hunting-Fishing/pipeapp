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

function phase1Features(overrides = {}) {
  return {
    marketplace: true,
    wantedAds: true,
    offers: true,
    auctions: true,
    dispatch: true,
    paidFeatures: false,
    regulatedListings: false,
    revision: 1,
    updatedAt: Timestamp.fromDate(new Date("2026-07-19T12:00:00.000Z")),
    updatedByUid: "system",
    ...overrides,
  };
}

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
    await setDoc(
        doc(db, "platform_configuration", "phase1_features"),
        phase1Features(),
    );
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
    await setDoc(doc(db, "public_listings", "listing", "revisions", "2"), {
      actorUid: "seller",
      event: "details_updated",
      revision: 2,
    });
    await setDoc(doc(db, "users", "buyer", "saved_listings", "listing"), {
      listingId: "listing",
      savedAt: Timestamp.fromDate(new Date("2026-07-19T12:00:00.000Z")),
    });
    await setDoc(doc(db, "verification_requests", "buyer"), {
      userUid: "buyer",
      displayName: "Buyer Business",
      status: "pending",
      revision: 1,
    });
    await setDoc(doc(db, "verification_review_events", "buyer-1-submitted"), {
      userUid: "buyer",
      event: "submitted",
      status: "pending",
      revision: 1,
    });
    await setDoc(doc(db, "account_exports", "buyer-export"), {
      ownerUid: "buyer",
      status: "ready",
      chunkCount: 1,
    });
    await setDoc(doc(
        db,
        "account_exports",
        "buyer-export",
        "chunks",
        "000000",
    ), {ownerUid: "buyer", index: 0, content: "{}"});
    await setDoc(doc(db, "account_deletion_requests", "buyer"), {
      ownerUid: "buyer",
      status: "scheduled",
    });
    await setDoc(doc(db, "account_privacy_events", "buyer-exported"), {
      ownerUid: "buyer",
      type: "data_export_generated",
    });
    await setDoc(doc(db, "offers", "offer"), {
      sellerUid: "seller",
      buyerUid: "buyer",
      listingId: "listing",
      status: "pending",
    });
    await setDoc(doc(db, "marketplace_transactions", "accepted-offer"), {
      offerId: "accepted-offer",
      listingId: "listing",
      buyerUid: "buyer",
      sellerUid: "seller",
      status: "pending_completion",
      buyerConfirmed: false,
      sellerConfirmed: false,
      revision: 1,
    });
    await setDoc(doc(
        db,
        "marketplace_transactions",
        "accepted-offer",
        "revisions",
        "1",
    ), {
      event: "offer_accepted",
      actorUid: "seller",
      revision: 1,
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
    await setDoc(doc(db, "auction_transactions", "auction"), {
      listingId: "auction",
      buyerUid: "buyer",
      sellerUid: "seller",
      status: "pending_completion",
      buyerConfirmed: false,
      sellerConfirmed: false,
      revision: 1,
    });
    await setDoc(doc(
        db,
        "auction_transactions",
        "auction",
        "revisions",
        "1",
    ), {
      event: "auction_won",
      actorUid: "auction_scheduler",
      revision: 1,
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
    await setDoc(doc(db, "dispatch_transactions", "job"), {
      jobId: "job",
      customerUid: "buyer",
      carrierUid: "carrier",
      bidId: "bid",
      amount: 2500,
      status: "awarded",
      revision: 1,
    });
    await setDoc(doc(
        db,
        "dispatch_transactions",
        "job",
        "revisions",
        "1",
    ), {
      event: "carrier_awarded",
      actorUid: "buyer",
      revision: 1,
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
      .authenticatedContext("admin-user", administratorClaims)
      .firestore();
  const policy = doc(adminDb, "jurisdiction_policies", "ca-ab-test");

  await assertSucceeds(setDoc(policy, {status: "designOnly"}));
  const snapshot = await assertSucceeds(getDoc(policy));
  assert.equal(snapshot.data().status, "designOnly");
});

test("administrator rules fail closed for email or incomplete claims", async () => {
  const emailOnly = testEnvironment.authenticatedContext("email-only", {
    email: "jordilwbailey@gmail.com",
    email_verified: true,
  }).firestore();
  const adminWithoutMfa = testEnvironment.authenticatedContext(
      "admin-without-mfa",
      {admin: true, role: "administrator"},
  ).firestore();
  const adminWithoutRole = testEnvironment.authenticatedContext(
      "admin-without-role",
      {admin: true, firebase: {sign_in_second_factor: "phone"}},
  ).firestore();

  await assertFails(getDoc(doc(
      emailOnly,
      "jurisdiction_policies",
      "ca-ab-test",
  )));
  await assertFails(getDoc(doc(
      adminWithoutMfa,
      "jurisdiction_policies",
      "ca-ab-test",
  )));
  await assertFails(getDoc(doc(
      adminWithoutRole,
      "jurisdiction_policies",
      "ca-ab-test",
  )));
});

test("administrator role records and audits are server owned", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", administratorClaims)
      .firestore();
  const role = doc(adminDb, "administrator_roles", "admin-user");
  const audit = doc(adminDb, "administrator_role_audits", "audit-1");

  await assertFails(setDoc(role, {active: true}));
  await assertFails(setDoc(audit, {action: "grant"}));
});

test("feature configuration is public read and admin-only validated write", async () => {
  const publicDb = testEnvironment.unauthenticatedContext().firestore();
  const userDb = testEnvironment
      .authenticatedContext("ordinary-user")
      .firestore();
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", administratorClaims)
      .firestore();
  const publicFlags = doc(
      publicDb,
      "platform_configuration",
      "phase1_features",
  );
  const userFlags = doc(
      userDb,
      "platform_configuration",
      "phase1_features",
  );
  const adminFlags = doc(
      adminDb,
      "platform_configuration",
      "phase1_features",
  );

  await assertSucceeds(getDoc(publicFlags));
  await assertFails(setDoc(userFlags, phase1Features({
    updatedByUid: "ordinary-user",
  })));
  await assertSucceeds(setDoc(adminFlags, phase1Features({
    auctions: false,
    revision: 2,
    updatedByUid: "admin-user",
  })));
  await assertFails(setDoc(adminFlags, phase1Features({
    revision: 4,
    updatedByUid: "admin-user",
  })));
  await assertFails(setDoc(adminFlags, phase1Features({
    revision: 3,
    updatedAt: "not-a-timestamp",
    updatedByUid: "admin-user",
  })));
  await assertFails(setDoc(adminFlags, {
    ...phase1Features({
      revision: 3,
      updatedByUid: "admin-user",
    }),
    unsupportedFlag: true,
  }));
});

test("property listings remain closed even to signed-in clients", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", administratorClaims)
      .firestore();
  const listing = doc(adminDb, "property_listings", "not-yet-enabled");

  await assertFails(getDoc(listing));
  await assertFails(setDoc(listing, {status: "draft"}));
});

test("property audit events cannot be forged by client admins", async () => {
  const adminDb = testEnvironment
      .authenticatedContext("admin-user", administratorClaims)
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

test("transaction state and history are participant-readable and server-only", async () => {
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const strangerDb = testEnvironment
      .authenticatedContext("stranger")
      .firestore();
  const buyerTransaction = doc(
      buyerDb,
      "marketplace_transactions",
      "accepted-offer",
  );

  await assertSucceeds(getDoc(buyerTransaction));
  await assertSucceeds(getDoc(doc(
      sellerDb,
      "marketplace_transactions",
      "accepted-offer",
      "revisions",
      "1",
  )));
  await assertFails(getDoc(doc(
      strangerDb,
      "marketplace_transactions",
      "accepted-offer",
  )));
  await assertFails(updateDoc(buyerTransaction, {
    status: "completed",
    buyerConfirmed: true,
  }));
  await assertFails(setDoc(doc(
      buyerDb,
      "marketplace_transactions",
      "accepted-offer",
      "revisions",
      "2",
  ), {event: "forged", actorUid: "buyer", revision: 2}));
});

test("auction settlement and history are participant-readable and server-only", async () => {
  const buyerDb = testEnvironment.authenticatedContext("buyer").firestore();
  const sellerDb = testEnvironment.authenticatedContext("seller").firestore();
  const strangerDb = testEnvironment.authenticatedContext("stranger").firestore();
  const settlement = doc(buyerDb, "auction_transactions", "auction");

  await assertSucceeds(getDoc(settlement));
  await assertSucceeds(getDoc(doc(
      sellerDb,
      "auction_transactions",
      "auction",
      "revisions",
      "1",
  )));
  await assertFails(getDoc(doc(
      strangerDb,
      "auction_transactions",
      "auction",
  )));
  await assertFails(updateDoc(settlement, {
    status: "completed",
    buyerConfirmed: true,
  }));
  await assertFails(setDoc(doc(
      buyerDb,
      "auction_transactions",
      "auction",
      "revisions",
      "2",
  ), {event: "forged", actorUid: "buyer", revision: 2}));
});

test("conversation participants cannot bypass server communication commands", async () => {
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
  await assertFails(updateDoc(conversation, {
    unreadCounts: {buyer: 0, seller: 0},
  }));
  await assertFails(setDoc(
      doc(buyerDb, "conversations", "conversation", "messages", "forged"),
      {
        senderUid: "buyer",
        text: "Direct client write",
        createdAt: Timestamp.fromDate(new Date("2026-07-19T12:00:00.000Z")),
      },
  ));
  await assertFails(setDoc(doc(buyerDb, "conversations", "forged"), {
    memberUids: ["buyer", "seller"],
    listingId: "listing",
    sellerUid: "seller",
  }));
});

test("reports, upload grants, and command receipts are server-owned", async () => {
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  await assertFails(setDoc(doc(buyerDb, "trust_reports", "forged"), {
    reporterUid: "buyer",
    reportedUid: "seller",
    targetType: "listing",
    listingId: "listing",
    reason: "fraud_or_scam",
    details: "This direct client report must be rejected.",
    attachmentCount: 0,
    status: "pending",
  }));
  await assertFails(setDoc(
      doc(buyerDb, "media_upload_authorizations", "forged"),
      {
        ownerUid: "buyer",
        purpose: "chat_attachment",
        targetId: "conversation",
        status: "authorized",
      },
  ));
  await assertFails(setDoc(
      doc(buyerDb, "communication_command_receipts", "forged"),
      {actorUid: "buyer", command: "sendMarketplaceMessage"},
  ));
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

test("saved listings are private and can only be changed by server commands", async () => {
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const strangerDb = testEnvironment
      .authenticatedContext("stranger")
      .firestore();
  const saved = doc(buyerDb, "users", "buyer", "saved_listings", "listing");

  await assertSucceeds(getDoc(saved));
  await assertFails(getDoc(doc(
      strangerDb,
      "users",
      "buyer",
      "saved_listings",
      "listing",
  )));
  await assertFails(setDoc(doc(
      buyerDb,
      "users",
      "buyer",
      "saved_listings",
      "another-listing",
  ), {listingId: "another-listing"}));
  await assertFails(deleteDoc(saved));
  await assertFails(setDoc(doc(buyerDb, "listing_events", "forged-save"), {
    listingId: "listing",
    actorUid: "buyer",
    type: "save",
    createdAt: Timestamp.fromDate(new Date("2026-07-19T12:00:00.000Z")),
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

test("clients cannot create or convert authoritative auction state", async () => {
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

  const privateAuction = doc(sellerDb, "auction_private", "new-auction");
  await assertFails(setDoc(auction, validAuction));
  await assertFails(setDoc(privateAuction, {
    ownerUid: "seller",
    reservePrice: 175,
  }));
  await assertFails(updateDoc(
      doc(sellerDb, "public_listings", "listing"),
      {
        transactionType: "Auction",
        auctionStatus: "live",
        startingBid: 100,
        currentBid: 0,
        minimumBidIncrement: 5,
      },
  ));
});

test("listing revision history is immutable and private to owner or admin", async () => {
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const buyerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const adminDb = testEnvironment
      .authenticatedContext("admin", administratorClaims)
      .firestore();
  const sellerRevision = doc(
      sellerDb,
      "public_listings",
      "listing",
      "revisions",
      "2",
  );

  await assertSucceeds(getDoc(sellerRevision));
  await assertSucceeds(getDoc(doc(
      adminDb,
      "public_listings",
      "listing",
      "revisions",
      "2",
  )));
  await assertFails(getDoc(doc(
      buyerDb,
      "public_listings",
      "listing",
      "revisions",
      "2",
  )));
  await assertFails(updateDoc(sellerRevision, {event: "forged"}));
  await assertFails(setDoc(doc(
      sellerDb,
      "public_listings",
      "listing",
      "revisions",
      "3",
  ), {
    actorUid: "seller",
    event: "forged",
    revision: 3,
  }));
  await assertFails(deleteDoc(sellerRevision));
});

test("disabled auction and Dispatch flags block legacy direct clients", async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
        doc(context.firestore(), "platform_configuration", "phase1_features"),
        phase1Features({auctions: false, dispatch: false, revision: 2}),
    );
  });
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();
  const carrierDb = testEnvironment
      .authenticatedContext("carrier")
      .firestore();

  await assertFails(setDoc(
      doc(sellerDb, "public_listings", "disabled-auction"),
      {
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
      },
  ));
  await assertFails(getDoc(
      doc(carrierDb, "dispatch_carriers", "carrier"),
  ));
});

test("ownership verification cannot be forged and Dispatch signup needs it", async () => {
  const unverifiedDb = testEnvironment
      .authenticatedContext("unverified")
      .firestore();
  const verifiedDb = testEnvironment
      .authenticatedContext("verified-provider", {
        email_verified: true,
        phone_number: "+12505550123",
      })
      .firestore();
  const sellerDb = testEnvironment
      .authenticatedContext("seller")
      .firestore();

  await assertFails(updateDoc(doc(sellerDb, "users", "seller"), {
    emailOwnershipVerified: true,
    phoneOwnershipVerified: true,
    verifiedPhoneE164: "+12505550123",
  }));
  await assertFails(setDoc(
      doc(unverifiedDb, "dispatch_carriers", "unverified"),
      {ownerUid: "unverified", operatingName: "Unverified Transport"},
  ));
  await assertSucceeds(setDoc(
      doc(verifiedDb, "dispatch_carriers", "verified-provider"),
      {
        ownerUid: "verified-provider",
        operatingName: "Verified Transport",
      },
  ));
  await assertFails(setDoc(
      doc(verifiedDb, "account_phone_registry", "forged"),
      {uid: "verified-provider", phoneE164: "+12505550123"},
  ));
  await assertFails(setDoc(
      doc(verifiedDb, "security_rate_limits", "forged"),
      {actorUid: "verified-provider", scope: "marketplace", count: 0},
  ));
  await assertFails(getDoc(
      doc(verifiedDb, "security_rate_limits", "forged"),
  ));
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

test("Dispatch job, quote, and award state cannot be forged by clients", async () => {
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
  await assertFails(updateDoc(doc(ownerDb, "dispatch_jobs", "job"), {
    title: "Updated pipe load",
    revision: 2,
    updatedAt: Timestamp.fromDate(
        new Date("2026-07-19T12:00:00.000Z"),
    ),
  }));
  await assertFails(setDoc(doc(ownerDb, "dispatch_jobs", "forged"), {
    createdByUid: "buyer",
    title: "Forged job",
    pickupLabel: "A",
    deliveryLabel: "B",
    truckingDate: Timestamp.fromDate(
        new Date("2026-07-20T12:00:00.000Z"),
    ),
    loadDetails: "Pipe",
    status: "open",
    bidCount: 0,
    revision: 1,
  }));
  await assertFails(setDoc(
      doc(ownerDb, "dispatch_jobs", "job", "revisions", "2"),
      {
        actorUid: "buyer",
        event: "request_updated",
        revision: 2,
      },
  ));
});

test("Dispatch transaction and proof history are participant-only", async () => {
  const carrierDb = testEnvironment
      .authenticatedContext("carrier")
      .firestore();
  const customerDb = testEnvironment
      .authenticatedContext("buyer")
      .firestore();
  const strangerDb = testEnvironment
      .authenticatedContext("stranger")
      .firestore();
  const settlement = doc(customerDb, "dispatch_transactions", "job");

  await assertSucceeds(getDoc(settlement));
  await assertSucceeds(getDoc(doc(
      carrierDb,
      "dispatch_transactions",
      "job",
      "revisions",
      "1",
  )));
  await assertFails(getDoc(doc(strangerDb, "dispatch_transactions", "job")));
  await assertFails(updateDoc(settlement, {
    status: "closed",
    proofOfDelivery: {receiverName: "Forged"},
  }));
  await assertFails(setDoc(doc(
      carrierDb,
      "dispatch_transactions",
      "job",
      "revisions",
      "2",
  ), {
    event: "mark_delivered",
    revision: 2,
  }));
});

test("account verification decisions are server-only and privately readable", async () => {
  const ownerDb = testEnvironment.authenticatedContext("buyer").firestore();
  const strangerDb = testEnvironment
      .authenticatedContext("stranger")
      .firestore();
  const adminDb = testEnvironment
      .authenticatedContext("admin", administratorClaims)
      .firestore();
  const requestRef = doc(ownerDb, "verification_requests", "buyer");

  await assertSucceeds(getDoc(requestRef));
  await assertSucceeds(getDoc(doc(
      ownerDb,
      "verification_review_events",
      "buyer-1-submitted",
  )));
  await assertSucceeds(getDoc(doc(
      adminDb,
      "verification_requests",
      "buyer",
  )));
  await assertFails(getDoc(doc(
      strangerDb,
      "verification_requests",
      "buyer",
  )));
  await assertFails(updateDoc(requestRef, {status: "approved"}));
  await assertFails(updateDoc(doc(
      adminDb,
      "verification_requests",
      "buyer",
  ), {status: "approved"}));
  await assertFails(setDoc(doc(
      ownerDb,
      "verification_review_events",
      "forged",
  ), {
    userUid: "buyer",
    event: "approved",
    status: "approved",
  }));
});

test("account privacy records are owner-readable and server-only", async () => {
  const ownerDb = testEnvironment.authenticatedContext("buyer").firestore();
  const strangerDb = testEnvironment
      .authenticatedContext("stranger")
      .firestore();
  const exportRef = doc(ownerDb, "account_exports", "buyer-export");
  const chunkRef = doc(
      ownerDb,
      "account_exports",
      "buyer-export",
      "chunks",
      "000000",
  );

  await assertSucceeds(getDoc(exportRef));
  await assertSucceeds(getDoc(chunkRef));
  await assertSucceeds(getDoc(doc(
      ownerDb,
      "account_deletion_requests",
      "buyer",
  )));
  await assertSucceeds(getDoc(doc(
      ownerDb,
      "account_privacy_events",
      "buyer-exported",
  )));
  await assertFails(getDoc(doc(
      strangerDb,
      "account_exports",
      "buyer-export",
  )));
  await assertFails(setDoc(doc(ownerDb, "account_exports", "forged"), {
    ownerUid: "buyer",
    status: "ready",
  }));
  await assertFails(updateDoc(exportRef, {status: "expired"}));
  await assertFails(deleteDoc(doc(ownerDb, "users", "buyer")));
});
