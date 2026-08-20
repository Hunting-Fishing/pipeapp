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

A subsequent V3 run exposed a second control contradiction. The new analyzer-driven hygiene helper had already become the owner of `UNUSED_IMPORT` and `UNUSED_ELEMENT` cleanup, but the V3 PowerShell runner still contained an older Dashboard-only step named `Letting the Dart analyzer identify the exact remaining unused import in the candidate`. That stale step accepted only `UNUSED_IMPORT`, so it rejected the same legitimate `UNUSED_ELEMENT` diagnostics that the new hygiene helper was designed to own.

In every case the gate correctly reported that production source was not changed.

## Root cause

Quote V2 replaces two independent legacy authoring surfaces: the Dashboard saved-quote editor and the Jobs carrier quote editor. Removing those surfaces can expose a dependency chain of local private declarations and imports that were only referenced by the retired implementations.

The earlier gates handled one discovered declaration at a time, the first V3 hygiene helper still contained hard-coded eager removals, and the V3 runner retained an obsolete second hygiene stage after the new helper was installed. Those overlapping owners contradicted each other.

This remains a migration-hygiene/tooling issue, not a pricing, Firebase, Firestore, Functions, browser-session, or quote-versioning defect.

## Permanent control

Quote V2 now uses exact-candidate promotion plus a single bounded analyzer-driven hygiene owner:

1. fingerprint all existing production sources;
2. build the Quote V2 candidate from the exact local source;
3. reject the candidate immediately if the retired Dashboard quote dialog or Jobs all-in quote editor still exists;
4. run `dart analyze --format=machine` against both the Dashboard and Jobs candidates inside `tool/clean_dispatch_quote_v2_candidate_hygiene.mjs`;
5. permit automatic cleanup only for analyzer-confirmed `UNUSED_IMPORT` and `UNUSED_ELEMENT` diagnostics;
6. for `UNUSED_IMPORT`, remove exactly the analyzer-identified plain import line;
7. for `UNUSED_ELEMENT`, prefer a private top-level declaration over an unused member diagnostic so removing an unused class also removes its now-irrelevant members such as `fromMap`;
8. remove only a private top-level declaration whose identifier has no remaining consumers; never automatically remove class members, public declarations, or referenced declarations;
9. rerun the analyzer after every cleanup because removing one dead declaration can expose another dead constant/helper/import;
10. never pre-delete a named helper before the analyzer proves it unused in the exact candidate;
11. reject any diagnostic outside the bounded unused-code set before production mutation;
12. after the hygiene helper reports PASS, do not run a second cleanup policy in PowerShell; perform only formatter and strict final analyzer proof on repository, Dashboard, and Jobs candidates;
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

## Why one hygiene owner matters

A candidate must not be cleaned by one tool and then reinterpreted by a stale second policy. V3 did exactly that: the Node hygiene helper accepted bounded `UNUSED_ELEMENT` cleanup, while the old PowerShell block treated any non-`UNUSED_IMPORT` diagnostic as fatal. V4 removes that duplicate stage. The helper owns cleanup; the runner owns final proof.

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

`tool/run_dispatch_quote_v2_foundation_gate_v4.ps1`

Do not use the earlier foundation, V2, or V3 promotion runners. The V4 runner must be explicitly fetched before execution so the PowerShell entry point itself cannot remain stale.
