# Release 3 — bounded Dispatch Directory radius-search backend

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
