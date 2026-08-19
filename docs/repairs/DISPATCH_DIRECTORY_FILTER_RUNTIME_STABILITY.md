# Dispatch Directory filter runtime stability repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Browser symptom

After the Phase 4 Directory query/list engineering gate passed, browser acceptance exposed a runtime UX failure:

- open Dispatch -> Directory;
- select a structured service such as Hotshot;
- the Directory body disappears into a mostly white/loading surface;
- the Flutter client appears to repeatedly refresh instead of keeping usable results on screen.

## Root cause

The Directory page replaced `_loadFuture` immediately on every filter change. `FutureBuilder` then returned a full-page loading widget whenever the replacement query entered `ConnectionState.waiting`.

That meant a normal filter action temporarily discarded the entire visible Directory. Search typing could trigger the same pattern repeatedly because each character created another remote refresh.

The original widget tests used immediate seeded data, so they did not reproduce a real asynchronous Firestore refresh. The engineering gate therefore passed while the browser exposed the lifecycle defect.

## Accepted repair design

Filter interaction and remote refresh are now separated:

1. update the filter state immediately;
2. continue filtering the last successful server-owned Directory page locally;
3. debounce remote refreshes briefly (180 ms);
4. keep the last successful page visible while the refreshed query is waiting;
5. use a generation counter so stale async query completions cannot replace newer results;
6. show a small inline `Updating Directory results...` state instead of replacing the page;
7. if a refresh fails after prior data exists, keep the usable prior data visible and show an inline Retry warning;
8. retain the original full loading/error states only when no successful Directory data has ever loaded.

## Permanent implementation control

Canonical transform:

```text
tool/dispatch_directory_filter_runtime_transform.mjs
```

Focused continuation repair for an already-installed Phase 4 query/list source:

```text
tool/apply_dispatch_phase4_directory_filter_stability.mjs
```

Regression contract:

```text
test/dispatch_directory_filter_runtime_stability_contract_test.dart
```

## Future build rule

A filter/search interaction must never replace a usable Directory screen with a blank full-page loading state merely because a new remote query is running.

For data-backed filtering screens:

```text
last successful data
    -> user changes filter
    -> update visible/local match immediately
    -> debounce bounded remote refresh
    -> retain prior results while waiting
    -> accept only newest async completion
    -> inline refresh/error status
```

The canonical Phase 4 query/list installer must apply this lifecycle automatically so a fresh checkout does not recreate the defect.
