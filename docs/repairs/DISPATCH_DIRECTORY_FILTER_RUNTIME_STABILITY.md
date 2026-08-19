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

The transform now uses semantic method/field boundaries and whitespace-tolerant regular expressions for formatted Dart rather than a generic exact multiline result-header anchor.

Pre-mutation dry-run against the **exact current local Directory source**:

```text
tool/verify_dispatch_directory_filter_runtime_transform_dryrun.mjs
```

The dry-run must:

- recognize the accepted `dispatch_directory_entries` query layer;
- execute the complete runtime transform in memory;
- execute a second in-memory pass and prove idempotency;
- prove the production Directory file was not changed.

Focused continuation repair for an already-installed Phase 4 query/list source:

```text
tool/apply_dispatch_phase4_directory_filter_stability.mjs
```

Regression contract:

```text
test/dispatch_directory_filter_runtime_stability_contract_test.dart
```

Focused gate order:

```text
parse controls
-> dry-run complete transform against exact local source
-> prove dry-run changed no production bytes
-> apply already-proven transform
-> format
-> runtime + existing Directory regressions
-> strict analyzer
-> browser acceptance
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

A source-transform repair must also validate against the exact current local source before it writes anything. Parse-only preflight is not enough to prove that a semantic migration can target formatted source.

The canonical Phase 4 query/list installer must carry this lifecycle automatically so a fresh checkout does not recreate the browser defect.
