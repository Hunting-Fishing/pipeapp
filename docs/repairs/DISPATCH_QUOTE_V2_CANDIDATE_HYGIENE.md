# Dispatch Quote V2 Candidate Hygiene

## Symptoms

The Quote V2 migration correctly stopped before production mutation several times while strict-analyzing exact transformed candidates.

The first failures were in the Dashboard candidate:

1. an `unused_import` exposed by the migration;
2. `_DispatchUnitRequirementDraft` was no longer referenced;
3. `_DispatchUnitRequirementDraft.fromMap` was no longer referenced;
4. after removing that dead class, its supporting `_dispatchQuoteUnitTypes` declaration also became unreferenced.

After those Dashboard diagnostics were removed, the exact Jobs-page candidate surfaced its own strict analyzer diagnostics because the old Jobs quote editor had been replaced by `MarketplaceDispatchQuoteForm`.

Later controls exposed additional gate-level defects: duplicated cleanup policies, Windows path-with-spaces analyzer transport, class self-reference counting, and preflight library-identity mismatches. V5 moved the cross-file compile proof into a canonical-filename package mirror.

A later V5 run passed the canonical mirror, server quote policy proof, production analyzer, and existing Dispatch policy regressions, but the Flutter integration contract still failed because the test incorrectly asserted that `_vehicleTypeFallbackIcon` must disappear with the retired Jobs quote editor. The production Jobs page still legitimately uses `_vehicleTypeFallbackIcon` in fleet-management UI, including vehicle cards and the add-vehicle type selector. The gate correctly rolled back all promoted production files after that post-promotion test failure.

## Root cause

Quote V2 replaces two independent legacy authoring surfaces: the Dashboard saved-quote editor and the Jobs carrier quote editor. Removing them exposes a dependency island of local private code, but not every helper referenced by the old editor is owned exclusively by that editor.

Candidate cleanup and regression contracts must distinguish between:

- declarations truly orphaned by the migration;
- self-references contained inside an otherwise dead declaration; and
- shared helpers that remain live in unrelated functionality.

A regression must not classify a helper as legacy merely because one retired surface used it. Live consumers elsewhere in the same production file are authoritative.

## Permanent controls

1. Fingerprint all existing production sources before migration.
2. Build Quote V2 candidates from the exact local source.
3. Reject candidates if the retired Dashboard quote dialog or Jobs all-in quote editor still exists.
4. Remove only bounded declarations proven to have no remaining external consumers.
5. For class-like declarations, count references outside the complete declaration block rather than counting constructor/factory self-references.
6. Never delete a named helper merely because the retired quote editor used it; check for live consumers elsewhere first.
7. Do not assert that a shared helper must disappear unless the migration contract proves it is Quote-V1-exclusive.
8. Compile multi-file Dart migrations in a canonical-filename mirror so all transformed files resolve to the same Dart library identities.
9. Normalize temporary preflight imports back to canonical production import identities before mirror analysis.
10. Run strict analyzer on the transformed repository, Dashboard, and Jobs page as one coherent package graph.
11. Run candidate server quote-calculation tests before promotion.
12. Prove production hashes remain unchanged before promotion.
13. Promote the exact mirror-proven candidate.
14. Strictly analyze promoted production before regressions.
15. Run Quote V2 contract tests that assert semantic retirement markers (`All-in transport price`, legacy quote dialog classes) rather than unrelated shared-helper absence.
16. Restore all pre-existing production sources automatically if any post-promotion test fails.
17. Prove the Dispatch master tracker was not modified.

## Shared-helper regression rule

Incorrect:

```text
old quote dialog used _vehicleTypeFallbackIcon
  -> quote dialog removed
  -> therefore helper must be removed
```

Correct:

```text
old quote dialog used _vehicleTypeFallbackIcon
  -> quote dialog removed
  -> inspect remaining consumers
  -> fleet management still uses helper
  -> preserve helper
  -> regression checks retired quote UI markers instead
```

## Windows path-with-spaces rule

Any Node build/migration control that invokes Dart/Flutter from a path containing spaces must use repository-relative paths with `cwd` set to the repository root, or another explicitly proven quoting strategy. A subprocess failure with zero parsed diagnostics must never be treated as a clean analyzer result.

## Canonical mirror rule

Do not prove a multi-file Dart migration by analyzing renamed candidates whose imports resolve partly to production and partly to preflight files. Build a temporary package mirror, place transformed sources under canonical filenames, normalize their internal imports to those canonical filenames, and analyze the mirror as one coherent graph.

## Current focused gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v5.ps1`

Do not use V1, V2, V3, or V4.
