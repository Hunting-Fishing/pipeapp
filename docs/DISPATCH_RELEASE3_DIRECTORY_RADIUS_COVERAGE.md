# Release 3 — Dispatch Directory published radius coverage

## Date

2026-09-01

## Verified production baseline

```text
5f3875cb57a0629c180e19db36c2b9c21b0ce6ea
```

Production workflow `33511679533` / run #60 passed Firebase deployment, post-deploy Function parity, and responsive mobile/desktop visual acceptance with App Check enforced.

Evidence artifacts:

- Firebase release evidence: `9802129019`
- Visual acceptance evidence: `9802162842`

## User problem

The Dispatch Directory now has synchronized List / Map discovery, but a point pin alone does not explain how far a radius-based provider says they operate.

A naive client-side "near me" radius filter would be misleading because a bounded Directory page is not the complete global provider set. This slice therefore visualizes existing provider-declared radius coverage without pretending that a partial client scan is a complete geographic search.

## Bounded implementation

- Parse only the existing server-owned `publicServiceArea.mode`, `publicServiceArea.centerLabel`, and `publicServiceArea.radiusKm` fields from `dispatch_directory_entries`.
- Preserve existing approximate public `mapPoint` as the radius centre shown to Directory users.
- When a mapped company is selected and its public service-area mode is `radius`, render its published radius as an OpenStreetMap circle.
- Show a plain-language summary such as `Published service radius: within 250 km of Edmonton, Alberta.`
- State clearly that coverage is provider-declared and approximate and that exact job location, routing, permits, availability, and travel charges must be confirmed directly.
- Keep List / Map filters, pagination, provider actions, and the existing privacy boundary unchanged.

## Privacy boundary

This slice does not add precise home, yard, residence, contact, credential, Auth UID, moderation, or private carrier fields to the Directory.

The coverage circle is centred on the same approximate public point already published by the server-owned Directory projection. It must not be described as an exact business location.

## Why true radius search is not in this slice

Firestore does not provide a native radial GeoPoint query. Filtering only the currently loaded client page by distance could silently omit valid companies on later pages and would create false confidence.

True radius search should be implemented as a separate bounded server/geohash design with explicit result limits, pagination semantics, and false-positive distance verification. Do not replace that design with an unbounded client collection scan.

## Verification result

Guarded verification run `33514227499` passed:

- exact mutation scope;
- dependency restore;
- `dart analyze lib test`;
- focused Dispatch Directory tests and contracts;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations; and
- `git diff --check`.

Verified implementation commit before temporary-verifier cleanup:

```text
2369d35d26e72d5049848b2eeb5e762d13b9c48c
```

Temporary workflow and patch-script machinery were removed through the GitHub connector after the successful run.

## Permanent implementation rule

Radius coverage visualization and radius search are different concerns. A visible provider coverage circle may use the existing approximate public projection. A global "within X km" search must not be implemented by filtering only whatever Directory page happens to be loaded on the client.

For true radius search, follow the bounded Firestore geohash pattern: derive geohash query bounds, issue a small bounded set of ordered range queries, deduplicate candidates, and verify actual distance against the approximate public point to remove geohash false positives.
