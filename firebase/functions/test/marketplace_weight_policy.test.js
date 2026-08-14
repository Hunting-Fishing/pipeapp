"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  applyWeightSnapshot,
  catalogCandidateIds,
  catalogSnapshot,
  formulaSnapshot,
  pipeNominalEstimate,
  sellerSnapshot,
  unknownSnapshot,
} = require("../marketplace_weight_policy");

test("equipment exact-year catalog id precedes generic model id", () => {
  assert.deepEqual(catalogCandidateIds({
    category: "Heavy Equipment",
    productType: "Skid Steer",
    brand: "Bobcat",
    model: "S160",
    modelYear: 2011,
  }).slice(0, 2), [
    "equipment_bobcat_s160_2011",
    "equipment_bobcat_s160",
  ]);
});

test("catalog range uses conservative upper weight for planning", () => {
  const snapshot = catalogSnapshot(
      "equipment_bobcat_s160",
      {
        active: true,
        kind: "equipment",
        manufacturer: "Bobcat",
        model: "S160",
        operatingWeightMinKg: 2609,
        operatingWeightMaxKg: 3692,
        sourceName: "Bobcat Company",
        verificationStatus: "manufacturer source",
        revision: 3,
      },
      {quantity: 1},
  );
  assert.equal(snapshot.estimatedWeightKg, 3692);
  assert.equal(snapshot.estimatedWeightMinKg, 2609);
  assert.equal(snapshot.estimatedWeightMaxKg, 3692);
  assert.match(snapshot.method, /upper planning value/);
});

test("seller estimate remains a clearly identified approximation", () => {
  const snapshot = sellerSnapshot({sellerEstimatedWeightKg: 5670});
  assert.equal(snapshot.estimatedWeightKg, 5670);
  assert.equal(snapshot.confidence, "seller estimate");
  assert.equal(snapshot.legalUse, false);
});

test("unknown weight remains publishable and explicit", () => {
  const snapshot = unknownSnapshot();
  assert.equal(snapshot.status, "unknown");
  assert.equal(snapshot.estimatedWeightKg, undefined);
  assert.equal(snapshot.legalUse, false);
});

test("pipe nominal lb-per-foot calculation includes joint length and quantity", () => {
  const kg = pipeNominalEstimate({
    nominalWeightLbFt: 16.6,
    jointLengthFt: 31,
    quantity: 54,
  });
  const expected = 16.6 * 31 * 54 * 0.45359237;
  assert.ok(Math.abs(kg - expected) < 0.001);
});

test("formula snapshot retains source and legal disclaimer", () => {
  const snapshot = formulaSnapshot({
    nominalWeightLbFt: 16.6,
    jointLengthFt: 31,
    quantity: 54,
  });
  assert.equal(snapshot.status, "estimated");
  assert.match(snapshot.method, /nominal lb\/ft/);
  assert.match(snapshot.legalDisclaimer, /certified scales/);
});

test("applying snapshot stores compatibility fields without making it legal weight", () => {
  const listing = applyWeightSnapshot(
      {title: "Test pipe"},
      {
        status: "estimated",
        sourceLabel: "Approved catalog",
        confidence: "manufacturer source",
        estimatedWeightKg: 1200,
        catalogId: "pipe_test",
        legalUse: false,
      },
  );
  assert.equal(listing.shippingWeightKg, 1200);
  assert.equal(listing.catalogWeightKg, 1200);
  assert.equal(listing.weightSnapshot.legalUse, false);
});
