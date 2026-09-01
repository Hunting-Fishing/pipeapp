"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  PER_BOUND_FETCH_LIMIT,
  publicDirectoryResult,
  queryDirectoryRadius,
  validateRadiusSearchInput,
} = require("../dispatch_directory_search");

function document(id, latitude, longitude, overrides = {}) {
  const data = {
    companyName: `Company ${id}`,
    operatingName: `Company ${id}`,
    mapPoint: {latitude, longitude},
    geohash: `hash-${id}`,
    serviceCodes: ["transport_hotshot"],
    serviceAreaSummary: "Northern Alberta",
    publicLocation: {
      label: "Grande Prairie, Alberta",
      precision: "approximate_1km",
      source: "service_area_center",
    },
    publicServiceArea: {
      mode: "radius",
      centerLabel: "Grande Prairie, Alberta",
      radiusKm: 250,
      countryCodes: ["CA"],
      regionKeys: ["CA:alberta"],
      placeKeys: [],
    },
    availability: "available_now",
    businessType: "corporation",
    publicSummary: "Public provider summary",
    website: "https://example.test",
    profileCompleteness: 90,
    privateEmail: "must-not-leak@example.test",
    ownerUid: "must-not-leak-uid",
    insurance: {policyNumber: "PRIVATE"},
    ...overrides,
  };
  return {id, data: () => data};
}

class FakeQuery {
  constructor(snapshots, calls) {
    this.snapshots = snapshots;
    this.calls = calls;
    this.bound = [];
    this.readLimit = 0;
  }

  orderBy(field) {
    this.calls.push(["orderBy", field]);
    return this;
  }

  startAt(value) {
    this.bound[0] = value;
    return this;
  }

  endAt(value) {
    this.bound[1] = value;
    return this;
  }

  limit(value) {
    this.readLimit = value;
    return this;
  }

  async get() {
    this.calls.push(["get", ...this.bound, this.readLimit]);
    return this.snapshots.shift() || {docs: []};
  }
}

function fakeDb(snapshots, calls) {
  return {
    collection(name) {
      assert.equal(name, "dispatch_directory_entries");
      return new FakeQuery(snapshots, calls);
    },
  };
}

test("radius search validates coordinates, radius, and bounded result limit", () => {
  assert.deepEqual(validateRadiusSearchInput({
    latitude: 55.17,
    longitude: -118.79,
    radiusKm: 250,
  }), {
    center: [55.17, -118.79],
    radiusKm: 250,
    resultLimit: 40,
  });
  for (const input of [
    {latitude: 91, longitude: 0, radiusKm: 50},
    {latitude: 0, longitude: 181, radiusKm: 50},
    {latitude: 0, longitude: 0, radiusKm: 0},
    {latitude: 0, longitude: 0, radiusKm: 1001},
    {latitude: 0, longitude: 0, radiusKm: 50, resultLimit: 61},
  ]) {
    assert.throws(
        () => validateRadiusSearchInput(input),
        (error) => error instanceof HttpsError && error.code === "invalid-argument",
    );
  }
});

test("public radius result cannot leak private provider fields", () => {
  const result = publicDirectoryResult(document("safe", 55.17, -118.79), 12.34);
  assert.ok(result);
  assert.equal(result.distanceKm, 12.3);
  assert.equal(result.publicServiceArea.radiusKm, 250);
  const serialized = JSON.stringify(result);
  for (const forbidden of [
    "must-not-leak@example.test",
    "must-not-leak-uid",
    "policyNumber",
    "PRIVATE",
    "ownerUid",
    "privateEmail",
    "insurance",
  ]) {
    assert.equal(serialized.includes(forbidden), false, `leaked ${forbidden}`);
  }
});

test("bounded geohash search deduplicates, distance-filters, and sorts", async () => {
  const near = document("near", 55.1, -118.7);
  const farther = document("farther", 55.2, -118.8);
  const outside = document("outside", 60, -130);
  const calls = [];
  const snapshots = [
    {docs: [farther, near]},
    {docs: [near, outside]},
  ];
  const geofireApi = {
    geohashQueryBounds: () => [["a", "b"], ["c", "d"]],
    distanceBetween: (point) => {
      if (point[0] === 55.1) return 10;
      if (point[0] === 55.2) return 40;
      return 500;
    },
  };

  const result = await queryDirectoryRadius({
    db: fakeDb(snapshots, calls),
    geofireApi,
    center: [55.17, -118.79],
    radiusKm: 100,
    limit: 10,
  });

  assert.deepEqual(result.results.map((entry) => entry.id), ["near", "farther"]);
  assert.equal(result.candidateCount, 3);
  assert.equal(result.queryBounds, 2);
  assert.equal(result.truncated, false);
  assert.deepEqual(calls.filter((call) => call[0] === "get"), [
    ["get", "a", "b", PER_BOUND_FETCH_LIMIT],
    ["get", "c", "d", PER_BOUND_FETCH_LIMIT],
  ]);
});

test("server marks bounded range saturation as truncated", async () => {
  const docs = Array.from(
      {length: PER_BOUND_FETCH_LIMIT},
      (_, index) => document(`provider-${index}`, 55.17, -118.79),
  );
  const result = await queryDirectoryRadius({
    db: fakeDb([{docs}], []),
    geofireApi: {
      geohashQueryBounds: () => [["a", "b"]],
      distanceBetween: () => 1,
    },
    center: [55.17, -118.79],
    radiusKm: 100,
    limit: 60,
  });
  assert.equal(result.truncated, true);
  assert.equal(result.candidateCount, PER_BOUND_FETCH_LIMIT - 1);
  assert.equal(result.results.length, 60);
});
