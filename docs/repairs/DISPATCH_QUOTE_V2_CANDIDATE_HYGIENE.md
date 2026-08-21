# Dispatch Quote V2 Candidate Hygiene

## Symptoms

The Quote V2 migration correctly stopped before production mutation several times while strict-analyzing exact transformed candidates.

The first failures were in the Dashboard candidate:

1. an `unused_import` exposed by the migration;
2. `_DispatchUnitRequirementDraft` was no longer referenced;
3. `_DispatchUnitRequirementDraft.fromMap` was no longer referenced;
4. after removing that dead class, its supporting `_dispatchQuoteUnitTypes` declaration also became unreferenced.

After those Dashboard diagnostics were removed, the exact Jobs-page candidate surfaced its own strict analyzer diagnostics because the old Jobs quote editor had been replaced by `MarketplaceDispatchQuoteForm`.

A later V3 attempt then failed inside the candidate-hygiene helper itself before the formatter/analyzer stage. The helper had started to pre-delete named helpers before asking the analyzer whether they were actually unused in the exact transformed file.

A subsequent V3 run exposed a second control contradiction. The new analyzer-driven hygiene helper owned `UNUSED_IMPORT` and `UNUSED_ELEMENT` cleanup, but the V3 PowerShell runner still contained an older Dashboard-only cleanup stage that accepted only `UNUSED_IMPORT`.

V4 removed that duplicate stage, but the first V4 run still reported the same three Dashboard warnings after the helper had claimed the candidate was clean. The reason was analyzer transport, not source semantics.

## Root cause

The repository lives under a Windows path containing a space:

`D:\Game Development\pipeapp`

`tool/clean_dispatch_quote_v2_candidate_hygiene.mjs` invoked:

`dart analyze --format=machine <absolute candidate path>`

through a Windows shell. The absolute candidate path was therefore vulnerable to being split at `D:\Game Development`. The analyzer process could fail before reaching the intended candidate, while the helper filtered for machine-format diagnostics only. Because it saw no `INFO|...`, `WARNING|...`, or `ERROR|...` records, it incorrectly interpreted analyzer transport failure as a clean candidate.

The outer V4 `flutter analyze` then analyzed the real candidate correctly and rediscovered the untouched warnings.

This was a tooling transport defect. It was not Firebase, Flutter runtime state, Chrome, quote pricing, Firestore, Functions, or user procedure.

## Permanent control

Quote V2 now uses exact-candidate promotion plus a single bounded analyzer-driven hygiene owner:

1. fingerprint all existing production sources;
2. build the Quote V2 candidate from the exact local source;
3. reject the candidate immediately if the retired Dashboard quote dialog or Jobs all-in quote editor still exists;
4. inside the hygiene helper, invoke Dart analyzer against a path relative to the repository working directory instead of passing the absolute Windows path through the shell;
5. run an analyzer-transport probe under the same repository path before candidate cleanup and require an expected `UNUSED_ELEMENT` diagnostic;
6. if Dart analyzer exits non-zero and no machine diagnostics were captured, stop explicitly instead of treating the candidate as clean;
7. run `dart analyze --format=machine` against both Dashboard and Jobs candidates;
8. permit automatic cleanup only for analyzer-confirmed `UNUSED_IMPORT` and `UNUSED_ELEMENT` diagnostics;
9. for `UNUSED_IMPORT`, remove exactly the analyzer-identified plain import line;
10. for `UNUSED_ELEMENT`, prefer a private top-level declaration over an unused member diagnostic so removing an unused class also removes members such as `fromMap`;
11. remove only private top-level declarations with no remaining consumers; never automatically remove class members, public declarations, or referenced declarations;
12. rerun analyzer after every cleanup because removing one dead declaration can expose another dead constant/helper/import;
13. never pre-delete a named helper before analyzer proves it unused in the exact candidate;
14. reject diagnostics outside the bounded unused-code set before production mutation;
15. after the hygiene helper reports PASS, run only formatter and strict final analyzer proof in the PowerShell gate; do not run a second cleanup policy;
16. run candidate server quote-calculation tests;
17. prove production hashes are still unchanged;
18. promote the exact analyzed candidate instead of rerunning a separate transform;
19. strictly analyze promoted production before regressions;
20. restore every pre-existing production source automatically if a post-promotion gate fails;
21. prove the Dispatch master tracker was not modified.

## Windows path-with-spaces rule

Any Node-based build or migration control that shells out to Dart/Flutter from a repository path containing spaces must either:

- pass repository-relative file paths with `cwd` set to the repository root; or
- quote/escape the absolute path with a proven transport self-test.

A subprocess exit failure with zero parsed diagnostics must never be interpreted as a green analyzer result.

## Why analyzer-driven cleanup matters

Dead migration artifacts can form a small dependency island:

```text
retired quote UI
  -> private draft/model
  -> supporting constant/helper
  -> import used only by that helper
```

The analyzer should identify the dead chain. The hygiene pass removes only what analyzer proves dead, reruns analysis, and stops if the next diagnostic requires semantic engineering rather than mechanical cleanup.

## Why exact-candidate promotion matters

For migrations with local-source divergence, use:

```text
exact local source
  -> temporary transformed candidate
  -> analyzer transport proof
  -> analyzer-driven bounded hygiene
  -> formatter/analyzer/runtime or policy proof
  -> production hash still unchanged
  -> promote that exact proven candidate
  -> production analyzer/regressions
  -> rollback on any post-promotion failure
```

Do not suppress `unused_import` or `unused_element` warnings merely to get a green gate.

## Current focused gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v4.ps1`

Do not use the earlier foundation, V2, or V3 promotion runners. V4 synchronizes the corrected hygiene helper before candidate creation.
