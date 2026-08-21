# Dispatch Quote V2 Candidate Hygiene

## Symptoms

The Quote V2 migration correctly stopped before production mutation several times while strict-analyzing exact transformed candidates.

The first failures were in the Dashboard candidate:

1. an `unused_import` exposed by the migration;
2. `_DispatchUnitRequirementDraft` was no longer referenced;
3. `_DispatchUnitRequirementDraft.fromMap` was no longer referenced;
4. after removing that dead class, its supporting `_dispatchQuoteUnitTypes` declaration also became unreferenced.

After those Dashboard diagnostics were removed, the exact Jobs-page candidate surfaced its own strict analyzer diagnostics because the old Jobs quote editor had been replaced by `MarketplaceDispatchQuoteForm`.

A later V3 attempt failed because the hygiene helper pre-deleted named helpers before analyzer proof. Another V3 attempt failed because the PowerShell runner still contained a stale second cleanup policy. V4 removed that duplicate policy.

The first V4 run exposed a Windows analyzer-transport defect under `D:\Game Development\pipeapp`; that was corrected by using repository-relative analyzer paths plus a transport probe.

The next V4 hygiene run exposed a final bounded-cleanup bug: the analyzer correctly identified `_DispatchUnitRequirementDraft` as an unused top-level class, but the cleanup helper counted the class name inside its own declaration body. Constructors, named constructors and `fromMap` can repeat the class name internally, so the helper mistook self-references inside an already-unused class for external consumers and refused removal.

In every case the gate correctly reported that production source was not changed.

## Root cause

Quote V2 replaces two independent legacy authoring surfaces: the Dashboard saved-quote editor and the Jobs carrier quote editor. Removing them exposes a dependency island of local private code. Candidate cleanup therefore has to distinguish between:

- real references from outside a declaration; and
- self-references contained inside a declaration that analyzer has already proven unused.

For a class-like declaration, counting every occurrence of the class name in the whole source is incorrect. A constructor such as `_DispatchUnitRequirementDraft(...)`, a named constructor such as `_DispatchUnitRequirementDraft.fromMap(...)`, or a factory return can repeat the class name without representing any external consumer.

This remains a migration-control defect, not Firebase, Flutter runtime state, Chrome, Firestore, Functions, quote pricing, or user procedure.

## Permanent control

Quote V2 now uses exact-candidate promotion plus one bounded analyzer-driven hygiene owner:

1. fingerprint all existing production sources;
2. build Quote V2 candidates from the exact local source;
3. reject candidates if the retired Dashboard quote dialog or Jobs all-in quote editor still exists;
4. invoke Dart analyzer using repository-relative paths from the repository working directory;
5. prove analyzer transport with an intentional `UNUSED_ELEMENT` probe;
6. stop if analyzer exits unsuccessfully without machine diagnostics;
7. analyze both Dashboard and Jobs candidates;
8. permit automatic cleanup only for analyzer-confirmed `UNUSED_IMPORT` and `UNUSED_ELEMENT`;
9. remove exactly the analyzer-identified plain import for `UNUSED_IMPORT`;
10. for `UNUSED_ELEMENT`, prefer an unused private top-level declaration over an unused member diagnostic;
11. for a class/enum/mixin/extension that analyzer has identified as unused, locate its complete balanced declaration block and count references only in the source outside that block;
12. constructor, named-constructor, factory and internal return-type occurrences inside that unused declaration do not count as external consumers;
13. remove the class-like declaration only when its external occurrence count is zero;
14. for top-level values/functions, retain the stricter single-occurrence safety rule;
15. rerun analyzer after every cleanup because removing one dead declaration may expose the next dead constant/helper/import;
16. never pre-delete a named helper before analyzer proof;
17. reject diagnostics outside the bounded unused-code set before production mutation;
18. after hygiene PASS, run only formatter and strict final analyzer proof in PowerShell; do not run a second cleanup policy;
19. run candidate server quote-calculation tests;
20. prove production hashes remain unchanged;
21. promote the exact analyzed candidate;
22. strictly analyze promoted production before regressions;
23. restore all pre-existing production sources automatically if a post-promotion gate fails;
24. prove the Dispatch master tracker was not modified.

## Windows path-with-spaces rule

Any Node build/migration control that invokes Dart/Flutter from a path containing spaces must use repository-relative paths with `cwd` set to the repository root, or another explicitly proven quoting strategy. A subprocess failure with zero parsed diagnostics must never be treated as a clean analyzer result.

## Class self-reference rule

For analyzer-proven unused class-like declarations, safety is determined by references outside the complete declaration block, not by total identifier occurrences in the file.

Correct reasoning:

```text
analyzer: _DispatchUnitRequirementDraft is unused
  -> locate complete class block
  -> class name repeats in constructor/fromMap inside block: allowed self-reference
  -> count class name outside block
  -> zero outside references: safe bounded removal
```

Incorrect reasoning:

```text
count class name in whole file
  -> constructor + fromMap make count > 1
  -> falsely conclude class has live consumers
```

## Why exact-candidate promotion matters

For local-source-divergent migrations:

```text
exact local source
  -> temporary transformed candidate
  -> analyzer transport proof
  -> analyzer-driven bounded hygiene
  -> formatter/analyzer/runtime or policy proof
  -> production hash still unchanged
  -> promote exact proven candidate
  -> production analyzer/regressions
  -> rollback on post-promotion failure
```

Do not suppress `unused_import` or `unused_element` warnings merely to get a green gate.

## Current focused gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v4.ps1`

Do not use the earlier foundation, V2, or V3 promotion runners. V4 synchronizes the corrected hygiene helper before candidate creation.
