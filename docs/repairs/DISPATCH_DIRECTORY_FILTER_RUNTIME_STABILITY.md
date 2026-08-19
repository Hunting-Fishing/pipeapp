# Dispatch Directory filter runtime stability repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Browser symptom

After the Phase 4 Directory query/list engineering gate passed, browser acceptance exposed a runtime UX failure:

- open Dispatch -> Directory;
- select a structured service such as Hotshot;
- the Directory body disappears into a mostly white/loading surface;
- the Flutter client appears to repeatedly refresh instead of keeping usable results on screen.

## Product root cause

The Directory page replaced `_loadFuture` immediately on every filter change. `FutureBuilder` then returned a full-page loading widget whenever the replacement query entered `ConnectionState.waiting`.

That meant a normal filter action temporarily discarded the entire visible Directory. Search typing could trigger the same pattern repeatedly because each character created another remote refresh.

The original widget tests used immediate seeded data, so they did not reproduce a real asynchronous Firestore refresh. The engineering gate therefore passed while the browser exposed the lifecycle defect.

## First repair-control failure

The first focused runtime repair did **not** write the production Directory file. The apply script computes and validates the complete transformed source before it creates a backup or writes the file.

The attempt stopped inside the transform because the transform still depended on an exact multiline Dart source anchor around the result-header insertion point. The local Directory file had already been run through `dart format`, so the semantic UI section was present but its physical whitespace/layout did not match the transform's literal anchor.

This is the same class of failure previously seen in credential tooling: a repair that claims formatter tolerance cannot keep formatter-sensitive self-targeting or validation.

## Second repair-control failure

A later attempt successfully passed the text-level dry-run and applied the runtime transform, but the post-mutation Flutter test stage failed while loading Directory tests.

Three control gaps were found:

1. the dry-run proved that the transform could target and validate the exact local source text, but it did **not compile/analyze the transformed candidate before production mutation**;
2. the post-mutation gate ran Flutter tests before strict analyzer, so a source load/compile problem surfaced as a less useful `loading <test file>` test failure;
3. the runtime regression itself still contained a stale implementation-shape assertion for `setState(() => _filters = value);` even though the accepted lifecycle intentionally changed that block to invalidate `_loadGeneration` before the debounced refresh.

This violated the project's saved sequence:

```text
bounded source change
-> formatter
-> analyzer
-> tests
```

and repeated the same stale-test-contract class already encountered in credential analytics.

## Third continuation-control failure

After the source mutation had already succeeded, the first read-only continuation synchronized corrected test files and then ran one formatter-stability command across **both production source and freshly fetched support tests**.

A fetched support test was not yet in canonical `dart format` layout, so the continuation stopped with:

```text
Changed .\test\dispatch_directory_filter_runtime_stability_contract_test.dart
STOP: Directory runtime source/tests are not formatter-stable.
```

This was not a production-source failure. It was a verifier-boundary mistake.

The project had already established the correct pattern in the credential analytics read-only verifier: production source formatter stability is checked read-only, while support/test files are not treated as immutable production artifacts.

### Permanent correction

For read-only continuation gates:

```text
production source
    -> hash
    -> formatter stability check with --output=none
    -> analyzer
    -> never rewrite

synchronized support/test files
    -> may be normalized with dart format
    -> then formatter-stability checked
    -> run hygiene/tests/analyzer

final
    -> production hash unchanged
    -> tracker hash unchanged
```

**Read-only means production/source-of-record immutability, not that freshly synchronized test/support files can never be normalized.**

The canonical continuation now separates these two classes explicitly.

## Accepted repair design

Filter interaction and remote refresh are separated:

1. update the filter state immediately;
2. continue filtering the last successful server-owned Directory page locally;
3. invalidate older in-flight refresh generations as soon as the filter changes;
4. debounce remote refreshes briefly (180 ms);
5. keep the last successful page visible while the refreshed query is waiting;
6. use a generation counter so stale async query completions cannot replace newer results;
7. show a small inline `Updating Directory results...` state instead of replacing the page;
8. if a refresh fails after prior data exists, keep the usable prior data visible and show an inline Retry warning;
9. retain the original full loading/error states only when no successful Directory data has ever loaded.

## Permanent implementation controls

Canonical formatter-tolerant transform:

```text
tool/dispatch_directory_filter_runtime_transform.mjs
```

The transform uses semantic method/field boundaries and whitespace-tolerant regular expressions for formatted Dart rather than a generic exact multiline result-header anchor.

Pre-mutation dry-run against the **exact current local Directory source**:

```text
tool/verify_dispatch_directory_filter_runtime_transform_dryrun.mjs
```

The dry-run must:

- recognize the accepted `dispatch_directory_entries` query layer;
- execute the complete runtime transform in memory;
- execute a second in-memory pass and prove idempotency;
- prove the production Directory file was not changed;
- optionally emit a same-directory temporary transformed candidate so relative imports resolve exactly as production does.

Before production mutation, the focused gate must format and strict-analyze that transformed candidate. A text-valid transform is not sufficient if the candidate does not compile.

Regression contract:

```text
test/dispatch_directory_filter_runtime_stability_contract_test.dart
```

Regression-contract hygiene:

```text
test/dispatch_directory_runtime_contract_hygiene_test.dart
```

The hygiene test prevents the known stale implementation-shape assertion from returning and requires the regression to follow the accepted semantic lifecycle markers.

Read-only continuation after a successful mutation followed by a later failure:

```text
tool/verify_dispatch_phase4_directory_filter_runtime_continuation.ps1
```

That continuation hashes the production Directory source, normalizes only synchronized support tests, checks production formatter stability read-only, runs strict analyzer **before** tests, runs the corrected regression suite, and proves the production Directory source and Dispatch tracker remain unchanged.

## Required focused gate order

```text
parse controls
-> regression-contract hygiene
-> transform exact local source in memory
-> emit temporary same-directory candidate
-> format + strict-analyze candidate
-> prove production bytes unchanged
-> apply already-proven transform
-> format production source
-> strict analyzer BEFORE tests
-> runtime + existing Directory regressions
-> browser acceptance
```

If mutation has already succeeded and a later stage fails:

```text
DO NOT rerun mutation
-> use read-only continuation
-> normalize synchronized support tests if needed
-> check production formatter stability read-only
-> analyze production source first
-> if analyzer passes, repair/continue only at test/runtime layer
-> if analyzer fails, repair only the concrete source diagnostic
-> prove production hash discipline throughout
```

## Future build rule

A filter/search interaction must never replace a usable Directory screen with a blank full-page loading state merely because a new remote query is running.

For data-backed filtering screens:

```text
last successful data
    -> user changes filter
    -> update visible/local match immediately
    -> invalidate older async refresh
    -> debounce bounded remote refresh
    -> retain prior results while waiting
    -> accept only newest async completion
    -> inline refresh/error status
```

A source-transform repair must validate against the exact current local source **and compile the transformed candidate before it writes anything**. Parse-only and text-only preflight are not enough.

Read-only continuation gates must distinguish immutable production files from synchronized support/test files so formatting of a helper test can never be misreported as a production regression.

The canonical Phase 4 query/list installer must carry this lifecycle and preflight discipline automatically so a fresh checkout does not recreate the browser defect or the repair-loop failure.