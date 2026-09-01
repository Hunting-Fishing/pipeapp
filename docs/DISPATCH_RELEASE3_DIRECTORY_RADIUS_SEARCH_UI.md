# Release 3 — Dispatch Directory radius search UI

## Date

2026-09-01

## Backend production baseline

```text
54e1a3c100d528eecdf4acdb4c7858644fb0576d
```

Protected production workflow `33519388582` / run #62 deployed the bounded radius-search backend and passed Firebase deployment, post-deploy Function parity, and responsive mobile/desktop visual acceptance with App Check enforced.

Backend evidence artifacts:

- Firebase release evidence: `9805447988`
- Visual acceptance evidence: `9805481206`

## Verified UI production release

```text
b54edc4b17a2feee67f67faaeb0aa1a78721d822
```

PR #176 (`Release 3: add simple Dispatch Directory radius search UI`) was squash merged from the exact reviewed feature head `443e5d68badaad0430e2e5ad5f0852b140338e02`.

Protected production workflow `33530088768` / run #63 deployed the exact merged application SHA with App Check `enforce` and passed:

- exact release identity validation;
- analyzer and full Flutter regression;
- dynamic release-manifest controls;
- pre-deploy Function parity controls;
- both Firebase Functions codebase validations;
- Firestore Rules tests;
- authenticated callable workflow/retry tests;
- exact web build and notification-worker verification;
- Firebase production deployment;
- post-deploy Function parity proof; and
- responsive mobile/desktop visual acceptance.

Production evidence artifacts:

- Firebase release evidence: `9809595669`
- Visual acceptance evidence: `9809629706`

The verified deployed application SHA is `b54edc4b17a2feee67f67faaeb0aa1a78721d822`. Later documentation-only commits must not replace that application SHA unless a new protected application deployment actually occurs.

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

Verifier run `33521641225` / run #3 passed every gate above before temporary verification machinery was removed.

## Verification repair record

Two verifier failures occurred before run #3 passed. Neither required a change to the runtime feature design.

1. The temporary Python patch script embedded triple-quoted markers inside another Python string and failed with an unterminated-string `SyntaxError` before durable app files were modified. The repair was to keep the staged patch auditable and apply a narrowly scoped in-memory quoting repair from a temporary runner.
2. The first in-memory repair emitted invalid Dart string quoting in generated source-contract test assertions. Analyzer rejected those generated assertions while the Directory runtime code itself was not flagged. The repair was to emit explicitly escaped Dart string literals for the three affected assertions.

Permanent lesson: when temporary release tooling must generate source assertions containing nested quotes, do not layer raw/triple-quoted delimiters blindly. Generate the target-language escaping explicitly, keep exact mutation-scope guards in front of analysis/tests, and do not redesign runtime code for a verifier-generation defect.

## Current slice checklist

- [x] Protected radius-search backend deployed from `54e1a3c100d528eecdf4acdb4c7858644fb0576d`.
- [x] Simple place + distance Directory UX implemented.
- [x] Distance parsing and company distance display implemented.
- [x] Search-radius map overlay implemented.
- [x] Truncation warning implemented.
- [x] Existing Directory filters retained as local refinements.
- [x] Focused tests, analyzer, full Flutter regression, release contracts, Functions validation, and diff hygiene passed.
- [x] Temporary verifier and patch tooling removed from the feature branch.
- [x] Four-file feature PR #176 merged to `main`.
- [x] Exact merged SHA `b54edc4b17a2feee67f67faaeb0aa1a78721d822` deployed through protected production workflow #63.
- [x] Post-deploy Function parity and responsive visual acceptance confirmed.
- [x] Final production SHA and evidence artifacts recorded here.

## Permanent implementation rule

Do not replace the server-owned radius query with a client-side scan of loaded Directory pages. Geographic search results must come from `searchDispatchDirectoryRadius`; local filters may refine those returned results, and a truncated server response must remain visibly identified as incomplete.
