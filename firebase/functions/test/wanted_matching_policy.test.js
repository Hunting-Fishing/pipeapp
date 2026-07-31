"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  MAXIMUM_WANTED_CANDIDATES,
  MAXIMUM_WANTED_MATCHES_PER_LISTING,
  MINIMUM_WANTED_MATCH_SCORE,
  publicListingSnapshot,
  scoreWantedMatch,
  validateWantedMatchAction,
  wantedMatchId,
} = require("../wanted_matching_policy");

function wanted(overrides = {}) {
  return {
    sellerUid: "buyer",
    status: "active",
    wantedStatus: "open",
    transactionType: "Wanted / Seeking",
    title: "Wanted 54 joints of 4 inch drill pipe",
    category: "Pipe, Tubing & Materials",
    productType: "Drill Pipe",
    pipeSize: "4 inch",
    quantity: 54,
    price: 75,
    priceBasis: "Per piece",
    region: "Alberta",
    country: "Canada",
    ...overrides,
  };
}

function supply(overrides = {}) {
  return {
    sellerUid: "seller",
    status: "active",
    transactionType: "For Sale",
    title: "54 joints of inspected 4 inch drill pipe",
    category: "Pipe, Tubing & Materials",
    productType: "Drill Pipe",
    pipeSize: "4 inch",
    quantity: 54,
    price: 73,
    priceBasis: "Per piece",
    region: "Alberta",
    country: "Canada",
    ...overrides,
  };
}

test("strong wanted matches are explainable and bounded", () => {
  const result = scoreWantedMatch(wanted(), supply());
  assert.ok(result);
  assert.equal(result.score, 100);
  assert.equal(result.confidence, "high");
  assert.ok(result.reasons.includes("Exact product type"));
  assert.ok(result.reasons.includes("Available quantity meets request"));
  assert.ok(result.reasons.includes("Price is within stated target"));
  assert.ok(result.reasons.length <= 8);
  assert.ok(MAXIMUM_WANTED_CANDIDATES <= 100);
  assert.ok(MAXIMUM_WANTED_MATCHES_PER_LISTING <= 20);
});

test("invalid or private lifecycle pairs never create matches", () => {
  for (const [request, listing] of [
    [wanted({sellerUid: "same"}), supply({sellerUid: "same"})],
    [wanted({wantedStatus: "fulfilled"}), supply()],
    [wanted(), supply({status: "sold"})],
    [wanted(), supply({category: "Heavy Equipment"})],
    [wanted(), supply({transactionType: "Auction"})],
  ]) {
    assert.equal(scoreWantedMatch(request, listing), null);
  }
});

test("price evidence is only used for the same pricing basis", () => {
  const sameBasis = scoreWantedMatch(wanted(), supply());
  const differentBasis = scoreWantedMatch(
      wanted(),
      supply({priceBasis: "Total asking price"}),
  );
  assert.equal(sameBasis.reasons.includes(
      "Price is within stated target"), true);
  assert.equal(differentBasis.reasons.includes(
      "Price is within stated target"), false);
  assert.ok(differentBasis.score >= MINIMUM_WANTED_MATCH_SCORE);
});

test("match identifiers are deterministic and do not expose listing ids", () => {
  const first = wantedMatchId("wanted-123", "supply-456");
  assert.equal(first, wantedMatchId("wanted-123", "supply-456"));
  assert.notEqual(first, wantedMatchId("wanted-123", "supply-789"));
  assert.match(first, /^[a-f0-9]{64}$/);
  assert.equal(first.includes("wanted-123"), false);
});

test("stored public snapshots omit owners and unrestricted descriptions", () => {
  const snapshot = publicListingSnapshot(supply({
    description: "private seller notes",
    exactLocation: "private yard",
    sellerUid: "seller-secret",
  }));
  assert.equal(snapshot.title, "54 joints of inspected 4 inch drill pipe");
  assert.equal(Object.hasOwn(snapshot, "sellerUid"), false);
  assert.equal(Object.hasOwn(snapshot, "description"), false);
  assert.equal(Object.hasOwn(snapshot, "exactLocation"), false);
});

test("match actions are participant-specific and preserve the other view", () => {
  const match = {
    wantedOwnerUid: "buyer",
    sellerUid: "seller",
    wantedOwnerState: "suggested",
    sellerState: "suggested",
    revision: 1,
  };
  const dismissed = validateWantedMatchAction({
    match,
    actorUid: "buyer",
    action: "dismiss",
  });
  assert.equal(dismissed.field, "wantedOwnerState");
  assert.equal(dismissed.nextState, "dismissed");
  assert.equal(dismissed.sellerState, "suggested");
  assert.equal(dismissed.status, "suggested");
  assert.equal(dismissed.revision, 2);

  const contacted = validateWantedMatchAction({
    match,
    actorUid: "seller",
    action: "mark_contacted",
  });
  assert.equal(contacted.field, "sellerState");
  assert.equal(contacted.status, "contacted");
});

test("match actions reject outsiders, invalid restores, and no-ops", () => {
  const match = {
    wantedOwnerUid: "buyer",
    sellerUid: "seller",
    wantedOwnerState: "suggested",
    sellerState: "dismissed",
  };
  assert.throws(() => validateWantedMatchAction({
    match,
    actorUid: "outsider",
    action: "dismiss",
  }), (error) => error.code === "permission-denied");
  assert.throws(() => validateWantedMatchAction({
    match,
    actorUid: "buyer",
    action: "restore",
  }), (error) => error.code === "failed-precondition");
  assert.throws(() => validateWantedMatchAction({
    match,
    actorUid: "seller",
    action: "dismiss",
  }), (error) => error.code === "failed-precondition");
});
