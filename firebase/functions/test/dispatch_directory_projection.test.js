"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  buildDispatchDirectoryEntry,
  encodeGeohash,
  tokenize,
} = require("../dispatch_directory_projection");

function publicBusiness(overrides = {}) {
  return {
    ownerUid: "private-owner-uid-must-not-project",
    publicName: "Northline Heavy Haul",
    email: "private@example.test",
    phone: "+15555550123",
    dispatchProfile: {
      operatingName: "Northline Heavy Haul",
      businessType: "corporation",
      description: "Heavy-haul and oilfield transportation serving northern British Columbia.",
      website: "https://example.test",
      serviceCodes: ["transport.heavy_haul", "pilot.escort"],
      serviceAreaLabel: "Peace River, British Columbia, Canada",
      homeLocation: {
        label: "Fort St. John, British Columbia, Canada",
        point: {latitude: 56.25, longitude: -120.85},
        precision: "approximate_1km",
        source: "service_area_center",
      },
      serviceArea: {
        mode: "towns",
        centerLabel: "Fort St. John, British Columbia, Canada",
        center: {latitude: 56.25, longitude: -120.85},
        radiusKm: 250,
        countryCodes: ["CA"],
        regionKeys: ["ca:bc"],
        placeKeys: ["ca:bc:fort-st-john"],
      },
      availability: "available_now",
      emergencyCallout: true,
      remoteSiteCapable: true,
      profileCompleteness: 88,
      privateAddress: "123 Secret Yard Road",
      insurance: {policyNumber: "DO-NOT-PUBLISH", limit: 5000000},
      ...overrides,
    },
  };
}

function activeCarrier(overrides = {}) {
  return {
    ownerUid: "private-owner-uid-must-not-project",
    status: "active",
    availableForHire: true,
    phone: "+15555550123",
    providerReviewVersion: 1,
    ...overrides,
  };
}

test("active ready provider becomes a bounded public directory entry", () => {
  const entry = buildDispatchDirectoryEntry({
    businessId: "carrier-1",
    publicBusiness: publicBusiness(),
    carrier: activeCarrier(),
  });
  assert.ok(entry);
  assert.equal(entry.companyId, "carrier-1");
  assert.equal(entry.operatingName, "Northline Heavy Haul");
  assert.deepEqual(entry.serviceCodes, ["pilot.escort", "transport.heavy_haul"]);
  assert.equal(entry.availability, "available_now");
  assert.equal(entry.businessType, "corporation");
  assert.equal(entry.verified, false);
  assert.equal(entry.emergencyCallout, true);
  assert.equal(entry.remoteSiteCapable, true);
  assert.equal(entry.publicLocation.precision, "approximate_1km");
  assert.equal(entry.geohash.length, 6);
  assert.ok(entry.searchTokens.includes("northline"));
  assert.ok(entry.capabilityTokens.includes("emergency_callout"));
  assert.ok(entry.capabilityTokens.includes("service:transport.heavy_haul"));
});

test("directory projection excludes private identifiers, exact addresses, and credentials", () => {
  const entry = buildDispatchDirectoryEntry({
    businessId: "carrier-1",
    publicBusiness: publicBusiness(),
    carrier: activeCarrier(),
  });
  const serialized = JSON.stringify(entry);
  for (const forbidden of [
    "ownerUid",
    "private-owner-uid-must-not-project",
    "private@example.test",
    "+15555550123",
    "123 Secret Yard Road",
    "DO-NOT-PUBLISH",
    "policyNumber",
    "insurance",
  ]) {
    assert.equal(serialized.includes(forbidden), false, `leaked ${forbidden}`);
  }
});

test("inactive, suspended, or incomplete providers are not directory-published", () => {
  for (const carrier of [
    activeCarrier({status: "pending_review"}),
    activeCarrier({status: "suspended"}),
    activeCarrier({availableForHire: false}),
  ]) {
    assert.equal(buildDispatchDirectoryEntry({
      businessId: "carrier-1",
      publicBusiness: publicBusiness(),
      carrier,
    }), null);
  }
  assert.equal(buildDispatchDirectoryEntry({
    businessId: "carrier-1",
    publicBusiness: publicBusiness({serviceCodes: []}),
    carrier: activeCarrier(),
  }), null);
  assert.equal(buildDispatchDirectoryEntry({
    businessId: "carrier-1",
    publicBusiness: publicBusiness({serviceAreaLabel: ""}),
    carrier: activeCarrier(),
  }), null);
});

test("client supplied verified=true never becomes a Pipe Buyer verification claim", () => {
  const entry = buildDispatchDirectoryEntry({
    businessId: "carrier-1",
    publicBusiness: publicBusiness({verified: true, verificationBadge: "verified"}),
    carrier: activeCarrier(),
  });
  assert.ok(entry);
  assert.equal(entry.verified, false);
  assert.equal(JSON.stringify(entry).includes("verificationBadge"), false);
});

test("geohash is deterministic and search tokens are normalized and bounded", () => {
  assert.equal(encodeGeohash(56.25, -120.85, 6), encodeGeohash(56.25, -120.85, 6));
  assert.equal(encodeGeohash(100, 0, 6), "");
  const tokens = tokenize(
    "Northline Northline HEAVY Haul",
    Array.from({length: 200}, (_, index) => `token${index}`),
  );
  assert.ok(tokens.includes("northline"));
  assert.ok(tokens.includes("heavy"));
  assert.ok(tokens.length <= 80);
  assert.equal(tokens.filter((token) => token === "northline").length, 1);
});
