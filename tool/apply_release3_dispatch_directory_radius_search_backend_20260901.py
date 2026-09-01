from pathlib import Path

ABUSE = Path('firebase/functions/abuse_rate_limit.js')
ABUSE_TEST = Path('firebase/functions/test/abuse_rate_limit.test.js')
INDEX = Path('firebase/functions/index.js')
PACKAGE = Path('firebase/functions/package.json')
SEARCH = Path('firebase/functions/dispatch_directory_search.js')
SEARCH_TEST = Path('firebase/functions/test/dispatch_directory_search.test.js')
DOC = Path('docs/DISPATCH_RELEASE3_DIRECTORY_RADIUS_SEARCH_BACKEND.md')

abuse = ABUSE.read_text(encoding='utf-8')
old = '  dispatch: 180,\n  messaging: 120,\n'
new = '  dispatch: 180,\n  directory: 30,\n  messaging: 120,\n'
if abuse.count(old) != 1:
    raise SystemExit(f'abuse-rate anchor mismatch: {abuse.count(old)}')
abuse = abuse.replace(old, new, 1)
ABUSE.write_text(abuse, encoding='utf-8')

abuse_test = ABUSE_TEST.read_text(encoding='utf-8')
old = '    "account", "administration", "auctions", "dispatch", "marketplace",\n    "media",\n'
new = '    "account", "administration", "auctions", "directory", "dispatch",\n    "marketplace", "media",\n'
if abuse_test.count(old) != 1:
    raise SystemExit(f'abuse-test anchor mismatch: {abuse_test.count(old)}')
abuse_test = abuse_test.replace(old, new, 1)
ABUSE_TEST.write_text(abuse_test, encoding='utf-8')

index = INDEX.read_text(encoding='utf-8')
old = 'const { createDispatchDirectoryProjection } = require("./dispatch_directory_projection");\n'
new = old + 'const { createDispatchDirectorySearch } = require("./dispatch_directory_search");\n'
if index.count(old) != 1:
    raise SystemExit(f'index import anchor mismatch: {index.count(old)}')
index = index.replace(old, new, 1)
old = 'const dispatchDirectoryProjection = createDispatchDirectoryProjection(admin);\n'
new = old + 'const dispatchDirectorySearch = createDispatchDirectorySearch(admin);\n'
if index.count(old) != 1:
    raise SystemExit(f'index instance anchor mismatch: {index.count(old)}')
index = index.replace(old, new, 1)
old = '''exports.syncDispatchDirectoryFromCarrierStatus = onDocumentWritten(
  {
    document: "dispatch_carriers/{companyId}",
    retry: true,
  },
  async (event) => dispatchDirectoryProjection.syncCompany(event.params.companyId),
);
'''
new = old + '''exports.searchDispatchDirectoryRadius = onCall(
  protectedCallableOptions,
  dispatchDirectorySearch.searchDispatchDirectoryRadius,
);
'''
if index.count(old) != 1:
    raise SystemExit(f'index export anchor mismatch: {index.count(old)}')
index = index.replace(old, new, 1)
INDEX.write_text(index, encoding='utf-8')

package = PACKAGE.read_text(encoding='utf-8')
old = 'node --check dispatch_commands.js && node --check dispatch_credential_monitor.js && node --check dispatch_directory_projection.js && node --check integration/callable_integration.mjs'
new = 'node --check dispatch_commands.js && node --check dispatch_credential_monitor.js && node --check dispatch_directory_projection.js && node --check dispatch_directory_search.js && node --check integration/callable_integration.mjs'
if package.count(old) != 1:
    raise SystemExit(f'package check-script anchor mismatch: {package.count(old)}')
package = package.replace(old, new, 1)
PACKAGE.write_text(package, encoding='utf-8')

if SEARCH.exists() or SEARCH_TEST.exists() or DOC.exists():
    raise SystemExit('new radius-search file already exists')

SEARCH.write_text(r'''"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const geofire = require("geofire-common");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  FeatureFlagError,
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");

const MAX_RADIUS_KM = 1000;
const DEFAULT_RESULT_LIMIT = 40;
const MAX_RESULT_LIMIT = 60;
const PER_BOUND_RESULT_LIMIT = 80;
const PER_BOUND_FETCH_LIMIT = PER_BOUND_RESULT_LIMIT + 1;
const MAX_CANDIDATES = 500;
const MAX_QUERY_BOUNDS = 9;

function finiteNumber(data, fieldName, {min, max}) {
  const value = Number(data && data[fieldName]);
  if (!Number.isFinite(value) || value < min || value > max) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} must be between ${min} and ${max}.`,
    );
  }
  return value;
}

function resultLimit(data) {
  if (data == null || data.resultLimit == null || data.resultLimit === "") {
    return DEFAULT_RESULT_LIMIT;
  }
  const value = Number(data.resultLimit);
  if (!Number.isInteger(value) || value < 1 || value > MAX_RESULT_LIMIT) {
    throw new HttpsError(
        "invalid-argument",
        `resultLimit must be between 1 and ${MAX_RESULT_LIMIT}.`,
    );
  }
  return value;
}

function validateRadiusSearchInput(data) {
  return {
    center: [
      finiteNumber(data, "latitude", {min: -90, max: 90}),
      finiteNumber(data, "longitude", {min: -180, max: 180}),
    ],
    radiusKm: finiteNumber(
        data,
        "radiusKm",
        {min: 1, max: MAX_RADIUS_KM},
    ),
    resultLimit: resultLimit(data),
  };
}

function pointCoordinates(point) {
  if (!point || typeof point !== "object") return null;
  const latitude = Number(point.latitude ?? point.lat);
  const longitude = Number(point.longitude ?? point.lng);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return [latitude, longitude];
}

function cleanText(value, maxLength = 600) {
  return String(value || "").trim().replace(/\s+/g, " ").slice(0, maxLength);
}

function cleanStringList(value, limit = 64) {
  if (!Array.isArray(value)) return [];
  return value
      .map((item) => cleanText(item, 180))
      .filter(Boolean)
      .slice(0, limit);
}

function publicDirectoryResult(document, distanceKm) {
  const data = document.data() || {};
  const point = pointCoordinates(data.mapPoint);
  if (!point) return null;
  const publicLocation = data.publicLocation && typeof data.publicLocation === "object" ?
    data.publicLocation : {};
  const publicServiceArea =
    data.publicServiceArea && typeof data.publicServiceArea === "object" ?
      data.publicServiceArea : {};
  return {
    id: cleanText(document.id, 180),
    operatingName: cleanText(data.operatingName || data.companyName, 180),
    publicSummary: cleanText(data.publicSummary),
    website: cleanText(data.website, 260),
    serviceCodes: cleanStringList(data.serviceCodes),
    serviceAreaSummary: cleanText(data.serviceAreaSummary, 260),
    publicLocation: {
      label: cleanText(publicLocation.label, 200),
      precision: cleanText(publicLocation.precision, 64),
      source: cleanText(publicLocation.source, 96),
    },
    publicServiceArea: {
      mode: cleanText(publicServiceArea.mode, 96),
      centerLabel: cleanText(publicServiceArea.centerLabel, 200),
      radiusKm: Number.isFinite(Number(publicServiceArea.radiusKm)) ?
        Number(publicServiceArea.radiusKm) : 0,
      countryCodes: cleanStringList(publicServiceArea.countryCodes, 32),
      regionKeys: cleanStringList(publicServiceArea.regionKeys, 120),
      placeKeys: cleanStringList(publicServiceArea.placeKeys, 240),
    },
    mapPoint: {latitude: point[0], longitude: point[1]},
    availability: cleanText(data.availability, 96),
    businessType: cleanText(data.businessType, 96),
    verified: data.verified === true,
    emergencyCallout: data.emergencyCallout === true,
    remoteSiteCapable: data.remoteSiteCapable === true,
    profileCompleteness: Math.max(
        0,
        Math.min(100, Number(data.profileCompleteness) || 0),
    ),
    distanceKm: Math.round(distanceKm * 10) / 10,
  };
}

async function queryDirectoryRadius({
  db,
  geofireApi = geofire,
  center,
  radiusKm,
  limit = DEFAULT_RESULT_LIMIT,
}) {
  const radiusInM = radiusKm * 1000;
  const bounds = geofireApi.geohashQueryBounds(center, radiusInM);
  if (!Array.isArray(bounds) || bounds.length < 1 ||
      bounds.length > MAX_QUERY_BOUNDS) {
    throw new Error("Geo query bounds were unavailable or exceeded the approved limit.");
  }

  const snapshots = await Promise.all(bounds.map((bound) => {
    if (!Array.isArray(bound) || bound.length !== 2) {
      throw new Error("Geo query bound was invalid.");
    }
    return db.collection("dispatch_directory_entries")
        .orderBy("geohash")
        .startAt(bound[0])
        .endAt(bound[1])
        .limit(PER_BOUND_FETCH_LIMIT)
        .get();
  }));

  let truncated = false;
  const candidates = new Map();
  for (const snapshot of snapshots) {
    const documents = Array.isArray(snapshot.docs) ? snapshot.docs : [];
    if (documents.length >= PER_BOUND_FETCH_LIMIT) truncated = true;
    for (const document of documents.slice(0, PER_BOUND_RESULT_LIMIT)) {
      if (candidates.has(document.id)) continue;
      if (candidates.size >= MAX_CANDIDATES) {
        truncated = true;
        continue;
      }
      candidates.set(document.id, document);
    }
  }

  const matches = [];
  for (const document of candidates.values()) {
    const data = document.data() || {};
    const point = pointCoordinates(data.mapPoint);
    if (!point) continue;
    const distanceKm = geofireApi.distanceBetween(point, center);
    if (!Number.isFinite(distanceKm) || distanceKm > radiusKm) continue;
    const result = publicDirectoryResult(document, distanceKm);
    if (result && result.id && result.operatingName) matches.push(result);
  }
  matches.sort((left, right) =>
    left.distanceKm - right.distanceKm ||
    left.operatingName.localeCompare(right.operatingName));
  if (matches.length > limit) truncated = true;

  return {
    results: matches.slice(0, limit),
    resultCount: Math.min(matches.length, limit),
    candidateCount: candidates.size,
    queryBounds: bounds.length,
    truncated,
  };
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError || error instanceof FeatureFlagError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch Directory radius search failed", error);
      throw new HttpsError(
          "internal",
          "The Directory radius search could not be completed.",
      );
    }
  };
}

function createDispatchDirectorySearch(admin, options = {}) {
  const db = admin.firestore();
  const geofireApi = options.geofireApi || geofire;
  const searchDispatchDirectoryRadius = command(async (request) => {
    requireAuthenticatedIdentity(request);
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "dispatch");
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "directory",
    });
    const input = validateRadiusSearchInput(request.data || {});
    const response = await queryDirectoryRadius({
      db,
      geofireApi,
      center: input.center,
      radiusKm: input.radiusKm,
      limit: input.resultLimit,
    });
    return {
      center: {latitude: input.center[0], longitude: input.center[1]},
      radiusKm: input.radiusKm,
      ...response,
    };
  });
  return {searchDispatchDirectoryRadius};
}

module.exports = {
  DEFAULT_RESULT_LIMIT,
  MAX_CANDIDATES,
  MAX_QUERY_BOUNDS,
  MAX_RADIUS_KM,
  MAX_RESULT_LIMIT,
  PER_BOUND_FETCH_LIMIT,
  PER_BOUND_RESULT_LIMIT,
  createDispatchDirectorySearch,
  pointCoordinates,
  publicDirectoryResult,
  queryDirectoryRadius,
  validateRadiusSearchInput,
};
''', encoding='utf-8')

SEARCH_TEST.write_text(r'''"use strict";

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
''', encoding='utf-8')

DOC.write_text(r'''# Release 3 — bounded Dispatch Directory radius-search backend

## Date

2026-09-01

## Verified production baseline

```text
8bdb619d7dcadcd6eb4a052cde27c14e0fb6340d
```

Production workflow `33514979061` / run #61 passed Firebase deployment,
post-deploy Function parity, and responsive mobile/desktop visual acceptance
with App Check enforced.

Evidence artifacts:

- Firebase release evidence: `9803427428`
- Visual acceptance evidence: `9803460965`

## Why this is backend-first

The Directory now shows approximate provider pins and published provider radius
coverage. A global `within X km` search cannot correctly filter only the
currently loaded client page because later pages may contain valid providers.

This slice establishes a bounded server contract before any radius-search UI is
added.

## Query architecture

The callable follows Firebase's documented Firestore geohash pattern:

1. validate the requested latitude, longitude, radius and result limit;
2. derive geohash query bounds with `geofire-common`;
3. issue a small bounded set of ordered `geohash` range queries against only
   `dispatch_directory_entries`;
4. deduplicate candidates from overlapping bounds;
5. calculate actual distance from each candidate's existing approximate public
   `mapPoint` and remove geohash false positives;
6. sort accepted providers nearest-first;
7. return only an explicit allowlist of fields already present in the public
   Directory projection.

Reference: `https://firebase.google.com/docs/firestore/solutions/geoqueries`

## Hard bounds

- Search radius: `1..1000 km`.
- Result limit: default `40`, maximum `60`.
- Geohash bounds: maximum `9`.
- Per-bound accepted candidates: `80`, with one extra read used to detect
  saturation.
- Global unique candidate cap: `500`.
- Dedicated Directory search abuse-control quota: `30` unique requests per
  signed-in user per hour; identical retries share the existing deterministic
  request-fingerprint behavior.

If a bound, candidate set, or final result set exceeds a bound, the response is
returned with `truncated: true`. The future client must tell the user to narrow
the area rather than implying the result set is complete.

## Security and privacy boundary

The callable:

- requires an authenticated identity;
- requires the existing Phase 1 `dispatch` feature flag;
- is exported with the repository's protected callable / App Check options;
- reads only `dispatch_directory_entries`;
- never reads `dispatch_carriers`, private profile records, Auth user records,
  credentials, contacts, exact addresses, moderation data, or payment data;
- serializes a fixed allowlist of already-public Directory fields;
- returns the approximate public map point as plain latitude/longitude values.

## Dependency

Pin `geofire-common` to `6.0.0`. Firebase documents this helper for Firestore
geohash bounds and distance filtering; npm currently publishes `6.0.0` as the
latest version.

## Not in this slice

- No radius-search control in Flutter yet.
- No device-location permission or automatic `near me` behavior.
- No new geocoding provider.
- No new Firestore collection, rules change, or Directory projection schema.
- No Stripe, membership, quote, messaging, or payment changes.

## Next slice

After this callable is verified and deployed, wire a simple location + distance
control into the Dispatch Directory. The client should reuse the existing
OpenStreetMap address/autocomplete stack, call this one protected function, and
feed the returned public entries into the existing synchronized List / Map view.
''', encoding='utf-8')
