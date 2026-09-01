# Release 3 — Dispatch Directory synchronized List / Map

## Date

2026-09-01

## Production baseline

This slice starts from verified production application SHA:

```text
f980358ca136202daca5617c94fa8fff7f3c64d0
```

Production verification for that baseline is GitHub Actions run `33509965140` with App Check enforced.

## User problem

The Directory can now page through companies, but discovery is list-only even though the server-owned public projection already publishes an approximate `mapPoint` when a provider has a public mappable location.

For non-technical users, the next useful step is a simple two-mode Directory: **List** or **Map**. Both modes must show the same filtered provider set and must not create a second location source.

## Bounded implementation

- Add a simple List / Map segmented control.
- Keep List as the default view.
- Build map pins only from filtered entries whose projected `homeBasePoint` came from the public Directory `mapPoint`.
- Use the existing `flutter_map` dependency and `pipeBuyerTileUrl`, which defaults to OpenStreetMap tiles.
- Keep OpenStreetMap attribution visible.
- Recompute map center/zoom from the currently mapped public results when the result set changes.
- Selecting a provider pin shows that same provider's existing Directory company card below the map.
- Pagination remains available in Map mode; newly loaded public companies automatically join the same filtered map data set.
- If no filtered providers publish a public map point, explain that clearly and offer a one-tap return to List.

## Privacy boundary

This slice does **not** read or publish a private yard, residence, exact address, credential, contact, Auth UID or moderation field. The map uses only the existing server-owned `dispatch_directory_entries.mapPoint` projection already parsed as `homeBasePoint`.

The UI explicitly states that map locations are approximate and are for provider discovery, not private-yard routing.

## Not in this slice

- Radius filtering.
- Device-location permission or "near me" behavior.
- Geocoding new provider coordinates.
- A new map vendor or paid map API.
- Changes to provider profile persistence or projection Functions.
- Changes to quote, messaging, Stripe, membership or Dispatch payment flows.

## Verification

Guarded verification run:

```text
33511099244
```

Verified implementation commit:

```text
624b26ad420e195b339d3db49ed578a3add79e65
```

The gate passed:

- exact three-file durable mutation scope;
- Flutter dependency restore;
- `dart analyze lib test`;
- focused Directory projection, filter, runtime-stability and map/list source contracts;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations;
- `git diff --check`.

Temporary verification workflow and patch machinery were removed through the GitHub connector after the successful run.

## Next after this slice

After the synchronized List / Map experience is published, evaluate geography/radius filtering using only public approximate locations and service-area data. Do not expose private home-base coordinates to implement radius search.
