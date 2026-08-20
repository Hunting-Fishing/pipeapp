# Dispatch Quote V2 Candidate Hygiene

## Symptoms

The Quote V2 migration correctly stopped before production mutation several times while strict-analyzing exact transformed candidates.

The first failures were in the Dashboard candidate:

1. an `unused_import` exposed by the migration;
2. `_DispatchUnitRequirementDraft` was no longer referenced;
3. `_DispatchUnitRequirementDraft.fromMap` was no longer referenced;
4. after removing that dead class, its supporting `_dispatchQuoteUnitTypes` declaration also became unreferenced.

After those Dashboard diagnostics were removed, the exact Jobs-page candidate surfaced its own strict analyzer diagnostics. The old Jobs quote editor had been replaced by `MarketplaceDispatchQuoteForm`, so private helpers and imports used only by the retired all-in quote dialog could become unreachable. The known example is `_vehicleTypeFallbackIcon`, which was only needed by the retired fleet dropdown inside the old bid editor.

In every case the gate correctly reported that production source was not changed.

## Root cause

Quote V2 replaces two independent legacy authoring surfaces: the Dashboard saved-quote editor and the Jobs carrier quote editor. Removing those surfaces can expose a dependency chain of local private declarations and imports that were only referenced by the retired implementations.

The earlier gates handled one discovered declaration at a time. That was too narrow. Candidate hygiene must cover the complete transformed candidate graph, not only the first file that reports a warning.

This remains a migration-hygiene issue, not a pricing, Firebase, Firestore, Functions, or quote-versioning defect.

## Permanent control

Quote V2 uses exact-candidate promotion plus bounded analyzer-driven hygiene:

1. fingerprint all existing production sources;
2. build the Quote V2 candidate from the exact local source;
3. remove `_DispatchUnitRequirementDraft` only when it has no references outside its own top-level declaration;
4. then remove `_dispatchQuoteUnitTypes` only when the prior removal leaves that top-level const/final declaration with zero consumers;
5. remove `_vehicleTypeFallbackIcon` only when the transformed Jobs candidate leaves that top-level helper with zero consumers;
6. run `dart analyze --format=machine` against both the Dashboard and Jobs candidates;
7. permit automatic cleanup only for analyzer-confirmed `UNUSED_IMPORT` and `UNUSED_ELEMENT` diagnostics;
8. for `UNUSED_IMPORT`, remove exactly the analyzer-identified plain import line;
9. for `UNUSED_ELEMENT`, remove only a private top-level declaration whose identifier occurs exactly once in the candidate; never automatically remove class members, public declarations, or referenced declarations;
10. rerun the analyzer after every cleanup because removing one dead declaration can expose a second dead dependency;
11. reject any other analyzer diagnostic before production mutation;
12. format and strictly analyze repository, Dashboard, and Jobs candidates;
13. run the candidate server quote-calculation tests;
14. prove production hashes are still unchanged;
15. promote the exact analyzed candidate instead of rerunning a separate transform;
16. strictly analyze promoted production before regressions;
17. restore every pre-existing production source automatically if a post-promotion gate fails;
18. prove the Dispatch master tracker was not modified.

## Why dependency-ordered cleanup matters

Dead migration artifacts can form a small dependency island:

```text
retired quote UI
  -> private draft/model
  -> supporting constant/helper
  -> import used only by that helper
```

Removing only the first node produces a new analyzer warning for the second node. Repeating manual repairs one warning at a time is unnecessary and error-prone. The permanent control now walks only analyzer-proven dead top-level dependencies until the candidate is clean or until it reaches a diagnostic outside the safe cleanup boundary.

## Why exact-candidate promotion matters

A migration can be structurally correct against the remote baseline yet expose dead private code in a user's exact local source. Re-running another generic transform after the candidate has passed analysis can reintroduce a mismatch between what was proven and what was written.

For migrations with local-source divergence, use:

```text
exact local source
  -> temporary transformed candidate
  -> bounded candidate-specific hygiene
  -> formatter/analyzer/runtime or policy proof
  -> production hash still unchanged
  -> promote that exact proven candidate
  -> production analyzer/regressions
  -> rollback on any post-promotion failure
```

Do not suppress `unused_import` or `unused_element` warnings merely to get a green gate. Remove dead migration artifacts only when their unreferenced status is proven.

## Current focused gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v3.ps1`

The V3 gate synchronizes the current candidate-hygiene helper before building the candidate, so a failed pre-mutation V3 attempt may be rerun after the helper is corrected. Do not rerun the older Quote V2 foundation or V2 gates.
