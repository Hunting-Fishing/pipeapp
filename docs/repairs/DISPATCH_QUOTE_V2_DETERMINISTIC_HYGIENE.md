# Dispatch Quote V2 deterministic candidate hygiene

## Why this supersedes analyzer-mutating hygiene

Repeated Quote V2 preflight failures occurred inside the candidate-hygiene helper itself. The helper was trying to invoke Dart analyzer, interpret analyzer machine output, mutate candidate source, then rely on a second outer strict analyzer. That created too many failure surfaces inside the migration control: Windows subprocess transport, machine-output parsing, declaration selection and source mutation were all coupled together.

The production source was not changed by these failures.

## Current rule

The hygiene helper is now deterministic and bounded. It does not invoke Dart or Flutter and does not interpret analyzer output.

For the already-proven Quote V1 dependency island it may only:

- remove the transformed Dashboard `_DispatchUnitRequirementDraft` class when it has zero references outside its own balanced class block;
- remove `_dispatchQuoteUnitTypes` only when it has become a single unreferenced top-level const/final declaration;
- remove `marketplace_location.dart` only when the transformed Dashboard has no `MarketplaceLocation` consumer token;
- remove `_vehicleTypeFallbackIcon` from the transformed Jobs page only when the symbol occurs once and is therefore unreferenced;
- reject the candidate if the retired Dashboard quote editor or retired Jobs all-in quote editor still exists.

The helper writes temporary candidate files only. It never writes production source.

## Analyzer boundary

Analyzer is read-only authority again:

```text
exact local production
  -> build temporary Quote V2 candidates
  -> deterministic bounded legacy-island cleanup
  -> dart format candidates
  -> strict flutter analyze repository + Dashboard + Jobs candidates
  -> server Quote V2 calculation tests
  -> prove production hashes unchanged
  -> promote the exact candidate that passed
  -> strict production analyzer + regressions
  -> rollback on any post-promotion failure
```

No helper is allowed to both infer source semantics from analyzer output and mutate source in the same stage for this migration.

## Permanent repair rule

When a migration has a small, already-isolated retired dependency island, prefer deterministic structural cleanup with explicit guards and a separate read-only analyzer proof. Do not build a generic analyzer-driven source rewriter into an acceptance gate unless that rewriter has independent tests proving its parser, transport and mutation behavior.

## Current gate

Use `tool/run_dispatch_quote_v2_foundation_gate_v4.ps1`. It synchronizes `tool/clean_dispatch_quote_v2_candidate_hygiene.mjs` before building the temporary candidate. The local V4 PowerShell entry point does not need to be replaced for this helper correction.
