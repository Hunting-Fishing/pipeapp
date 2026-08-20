# Dispatch Quote V2 Candidate Hygiene

## Symptoms

The Quote V2 migration correctly stopped before production mutation several times while strict-analyzing exact transformed candidates.

The first failures were in the Dashboard candidate:

1. an `unused_import` exposed by the migration;
2. `_DispatchUnitRequirementDraft` was no longer referenced;
3. `_DispatchUnitRequirementDraft.fromMap` was no longer referenced;
4. after removing that dead class, its supporting `_dispatchQuoteUnitTypes` declaration also became unreferenced.

After those Dashboard diagnostics were removed, the exact Jobs-page candidate surfaced its own strict analyzer diagnostics because the old Jobs quote editor had been replaced by `MarketplaceDispatchQuoteForm`.

A later V3 attempt then failed inside the candidate-hygiene helper itself before the formatter/analyzer stage. The helper had started to pre-delete named helpers such as `_vehicleTypeFallbackIcon` before asking the analyzer whether they were actually unused in the exact transformed file. That made the hygiene tool itself too opinionated: a named helper may still have another valid consumer in a user's local source.

In every case the gate correctly reported that production source was not changed.

## Root cause

Quote V2 replaces two independent legacy authoring surfaces: the Dashboard saved-quote editor and the Jobs carrier quote editor. Removing those surfaces can expose a dependency chain of local private declarations and imports that were only referenced by the retired implementations.

The earlier gates handled one discovered declaration at a time, and the first V3 hygiene helper still contained hard-coded eager removals. Both approaches were too narrow. Candidate hygiene must follow the analyzer across the complete transformed candidate graph and must not assume that a named helper is dead merely because one known consumer was removed.

This remains a migration-hygiene/tooling issue, not a pricing, Firebase, Firestore, Functions, browser-session, or quote-versioning defect.

## Permanent control

Quote V2 now uses exact-candidate promotion plus bounded analyzer-driven hygiene:

1. fingerprint all existing production sources;
2. build the Quote V2 candidate from the exact local source;
3. reject the candidate immediately if the retired Dashboard quote dialog or Jobs all-in quote editor still exists;
4. run `dart analyze --format=machine` against both the Dashboard and Jobs candidates;
5. permit automatic cleanup only for analyzer-confirmed `UNUSED_IMPORT` and `UNUSED_ELEMENT` diagnostics;
6. for `UNUSED_IMPORT`, remove exactly the analyzer-identified plain import line;
7. for `UNUSED_ELEMENT`, prefer a private top-level declaration over an unused member diagnostic so removing an unused class also removes its now-irrelevant members such as `fromMap`;
8. remove only a private top-level declaration whose identifier occurs exactly once in the candidate; never automatically remove class members, public declarations, or referenced declarations;
9. rerun the analyzer after every cleanup because removing one dead declaration can expose another dead constant/helper/import;
10. never pre-delete a named helper before the analyzer proves it unused in the exact candidate;
11. reject any diagnostic outside the bounded unused-code set before production mutation;
12. format and strictly analyze repository, Dashboard, and Jobs candidates;
13. run candidate server quote-calculation tests;
14. prove production hashes are still unchanged;
15. promote the exact analyzed candidate instead of rerunning a separate transform;
16. strictly analyze promoted production before regressions;
17. restore every pre-existing production source automatically if a post-promotion gate fails;
18. prove the Dispatch master tracker was not modified.

## Why analyzer-driven cleanup matters

Dead migration artifacts can form a small dependency island:

```text
retired quote UI
  -> private draft/model
  -> supporting constant/helper
  -> import used only by that helper
```

The correct control is not to maintain a growing list of identifiers to delete. The analyzer already knows which declarations are unused after each transformation step. The hygiene pass therefore removes only what the analyzer proves dead, reruns analysis, and stops if the next diagnostic requires semantic engineering rather than mechanical cleanup.

This avoids both failure modes:

- leaving cascading dead code behind; and
- deleting a helper that still has a valid consumer elsewhere in the local source.

## Why exact-candidate promotion matters

A migration can be structurally correct against the remote baseline yet expose dead private code in a user's exact local source. Re-running another generic transform after the candidate has passed analysis can reintroduce a mismatch between what was proven and what was written.

For migrations with local-source divergence, use:

```text
exact local source
  -> temporary transformed candidate
  -> analyzer-driven bounded hygiene
  -> formatter/analyzer/runtime or policy proof
  -> production hash still unchanged
  -> promote that exact proven candidate
  -> production analyzer/regressions
  -> rollback on any post-promotion failure
```

Do not suppress `unused_import` or `unused_element` warnings merely to get a green gate. Do not pre-delete named helpers just because a known consumer was retired.

## Current focused gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v3.ps1`

The V3 gate synchronizes the current candidate-hygiene helper before building the candidate, so a failed pre-mutation V3 attempt may be rerun after the helper is corrected. Do not rerun the older Quote V2 foundation or V2 gates.
