"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  contactSharingAuthorization,
} = require("../communication_commands");

const source = fs.readFileSync(
    path.resolve(__dirname, "..", "communication_commands.js"),
    "utf8",
);

function authorize(overrides = {}) {
  return contactSharingAuthorization({
    hasActiveMembership: true,
    actorUid: "seller-1",
    recipientUid: "buyer-1",
    relationshipType: "marketplace_listing",
    relationship: {
      sellerUid: "seller-1",
      acceptedOfferId: "offer-1",
      acceptedBuyerUid: "buyer-1",
      status: "pending_sale",
    },
    ...overrides,
  });
}

test("active membership and an exact accepted-offer relationship are required", () => {
  assert.deepEqual(authorize(), {allowed: true, reason: "accepted_offer"});
  assert.deepEqual(authorize({
    actorUid: "buyer-1",
    recipientUid: "seller-1",
  }), {allowed: true, reason: "accepted_offer"});
  assert.deepEqual(authorize({hasActiveMembership: false}), {
    allowed: false,
    reason: "membership_required",
  });
  assert.deepEqual(authorize({actorUid: "unrelated-1"}), {
    allowed: false,
    reason: "relationship_required",
  });
  assert.deepEqual(authorize({recipientUid: "seller-1"}), {
    allowed: false,
    reason: "relationship_required",
  });
});

test("cancelled, stale, and incomplete marketplace relationships fail closed", () => {
  for (const relationship of [
    {
      sellerUid: "seller-1",
      acceptedOfferId: "offer-1",
      acceptedBuyerUid: "buyer-1",
      status: "active",
    },
    {
      sellerUid: "seller-1",
      acceptedOfferId: "offer-1",
      acceptedBuyerUid: "buyer-1",
      status: "cancelled",
    },
    {
      sellerUid: "seller-1",
      acceptedBuyerUid: "buyer-1",
      status: "pending_sale",
    },
    {
      sellerUid: "seller-1",
      acceptedBidderUid: "buyer-1",
      auctionStatus: "cancelled",
    },
    {
      sellerUid: "seller-1",
      acceptedBidderUid: "buyer-1",
      auctionStatus: "live",
    },
    null,
  ]) {
    assert.deepEqual(authorize({relationship}), {
      allowed: false,
      reason: "relationship_required",
    });
  }
});

test("won-auction authorization binds the exact seller and winning buyer", () => {
  for (const relationship of [
    {
      sellerUid: "seller-1",
      acceptedBidderUid: "buyer-1",
      acceptedBidAmount: 10000,
      auctionStatus: "won",
    },
    {
      sellerUid: "seller-1",
      acceptedBidderUid: "buyer-1",
      acceptedBidAmount: 10000,
      auctionStatus: "accepted_below_reserve",
    },
    {
      sellerUid: "seller-1",
      buyNowBuyerUid: "buyer-1",
      acceptedBidAmount: 10000,
      auctionStatus: "bought_now",
    },
  ]) {
    assert.deepEqual(authorize({relationship}), {
      allowed: true,
      reason: "won_auction",
    });
  }
  assert.deepEqual(authorize({
    relationship: {
      sellerUid: "seller-1",
      acceptedBidderUid: "different-buyer",
      acceptedBidAmount: 10000,
      auctionStatus: "won",
    },
  }), {allowed: false, reason: "relationship_required"});
  assert.deepEqual(authorize({
    relationship: {
      sellerUid: "seller-1",
      acceptedBidderUid: "buyer-1",
      acceptedBidAmount: 0,
      auctionStatus: "won",
    },
  }), {allowed: false, reason: "relationship_required"});
});

test("awarded Dispatch authorization rejects pre-award and cancelled jobs", () => {
  const base = {
    actorUid: "customer-1",
    recipientUid: "carrier-1",
    relationshipType: "dispatch_job",
  };
  for (const status of [
    "awarded",
    "accepted",
    "scheduled",
    "in_transit",
    "delivered",
    "closed",
    "disputed",
  ]) {
    assert.deepEqual(authorize({
      ...base,
      relationship: {
        customerUid: "customer-1",
        carrierUid: "carrier-1",
        status,
      },
    }), {allowed: true, reason: "awarded_dispatch"});
  }
  for (const status of ["draft", "open", "pending", "cancelled", ""]) {
    assert.deepEqual(authorize({
      ...base,
      relationship: {
        customerUid: "customer-1",
        carrierUid: "carrier-1",
        status,
      },
    }), {allowed: false, reason: "relationship_required"});
  }
  assert.deepEqual(authorize({
    ...base,
    recipientUid: "unrelated-1",
    relationship: {
      customerUid: "customer-1",
      carrierUid: "carrier-1",
      status: "awarded",
    },
  }), {allowed: false, reason: "relationship_required"});
});

test("contact and attachment sharing execute the membership and relationship guard", () => {
  assert.match(source, /contactSharingSignals\(text\)/u);
  assert.match(source, /signals\.length === 0 && !includesAttachment/u);
  assert.match(source, /collection\("dispatch_memberships"\)/u);
  assert.match(source, /collection\("vip_memberships"\)/u);
  assert.match(source, /paidMembershipCurrentForUser/u);
  assert.match(source, /contactSharingAuthorization\(\{/u);
  assert.match(source, /collection\("dispatch_transactions"\)/u);
  assert.match(source, /offer is accepted, an auction/u);
  assert.match(source, /is won, or a Dispatch quote is awarded/u);
});

test("message send and attachment authorization both enforce contact policy", () => {
  const calls = source.match(/await assertContactSharingAllowed\(/gu) || [];
  assert.ok(calls.length >= 2, "both protected paths must call the guard");

  const sendStart = source.indexOf("const sendMarketplaceMessage");
  const guard = source.indexOf("await assertContactSharingAllowed(", sendStart);
  const messageWrite = source.indexOf("transaction.create(messageRef", sendStart);
  assert.ok(sendStart >= 0, "sendMarketplaceMessage is missing");
  assert.ok(guard > sendStart, "message guard is missing");
  assert.ok(messageWrite > guard, "the guard must run before the message write");
});
