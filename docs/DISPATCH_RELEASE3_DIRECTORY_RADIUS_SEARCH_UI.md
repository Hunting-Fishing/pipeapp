# Release 3 — Dispatch Directory radius search UI

## Date

2026-09-01

## Verified production baseline

```text
54e1a3c100d528eecdf4acdb4c7858644fb0576d
```

Protected production workflow `33519388582` / run #62 passed Firebase deployment, post-deploy Function parity, and responsive mobile/desktop visual acceptance with App Check enforced.

Evidence artifacts:

- Firebase release evidence: `9805447988`
- Visual acceptance evidence: `9805481206`

## User problem

The Directory has a correct server-owned radius-search callable, but ordinary users still need a simple way to choose a place and distance without understanding geohashes, Firestore query bounds, or map internals.

## Bounded UI implementation

- Add a visible `Search near a place` card above existing Directory filters.
- Use the existing OpenStreetMap/Photon place autocomplete and settlement results.
- Keep distance choices simple and oilfield-appropriate: 50, 100, 250, 500, and 1000 km.
- Require an explicit `Search this area` action so results never change unexpectedly while a user is still typing.
- Call only the protected `searchDispatchDirectoryRadius` backend and request its approved maximum of 60 bounded public results.
- Parse callable map points without changing the Firestore projection contract.
- Show returned `distanceKm` on company cards when available.
- Draw the selected search radius on the existing Directory map while preserving provider-declared coverage circles.
- Once a geographic search is active, collapse the control to a clear summary and `Change area` action. This prevents stale results while users edit search parameters.
- Keep existing service, availability, business type, emergency, and remote-site filters as local refinements of the bounded geographic result.
- Disable ordinary cursor pagination while radius-search results are active.

## Completeness rule

The server can return `truncated: true` when a bounded geohash range or result cap is saturated. The UI must then state that more companies may exist and ask the user to reduce the distance before relying on additional filters.

A truncated result must never be described as a complete list of every provider within the selected radius.

## Meaning of the search

`Search near a place` means the provider's **approximate public Directory point** is within the selected radius. It does not assert that every returned provider serves the exact job location, nor does it search private yards, homes, or precise carrier addresses.

Users must still confirm service coverage, exact job location, route, permits, availability, and travel charges directly with the company.

## Existing safety boundaries preserved

- No private carrier data is requested or displayed.
- No Firestore rules/schema changes.
- No direct unbounded Directory scan.
- No payment, subscription, listing, messaging, or provider persistence changes.
- The existing Directory list/map, provider actions, published provider radius visualization, and normal cursor browsing remain available.

## Verification gate

Before merge, this slice must pass:

- exact four-file durable mutation scope;
- `dart analyze lib test`;
- focused Dispatch Directory parser/widget tests;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations; and
- `git diff --check`.

## Permanent implementation rule

Do not replace the server-owned radius query with a client-side scan of loaded Directory pages. Geographic search results must come from `searchDispatchDirectoryRadius`; local filters may refine those returned results, and a truncated server response must remain visibly identified as incomplete.
