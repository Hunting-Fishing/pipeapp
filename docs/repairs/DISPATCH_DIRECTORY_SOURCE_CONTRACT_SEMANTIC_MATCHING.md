# Dispatch Directory source-contract semantic matching repair

## Date

2026-09-01

## Context

Release 3 added cursor pagination to the existing Dispatch Directory without changing the server-owned `dispatch_directory_entries` projection, privacy boundaries, provider actions, quote flow, messaging, Firestore rules, or Functions.

During verification, the new pagination behavior passed its focused tests, but two older source-contract tests failed because they encoded exact source formatting/body shapes rather than the behavior they intended to protect.

## Failure 1: projection collection formatting

Verification run `33507065767` failed this existing assertion:

```text
_firestore.collection('dispatch_directory_entries')
```

`dart format` wrapped the same Firestore collection expression across lines. The Directory still read the same server-owned projection, and the new pagination tests passed.

### Root cause

The source contract coupled the test to one formatter layout instead of the protected semantics: use the Firestore repository and the `dispatch_directory_entries` collection.

### Permanent repair

The contract now checks those semantic markers independently:

- `_firestore` is present;
- `'dispatch_directory_entries'` is present.

It no longer requires one exact formatted expression.

## Failure 2: reload setState body shape

Verification run `33507356266` passed the focused pagination suite and the Directory runtime-stability contracts, then the full Flutter regression failed `dispatch_directory_filter_setstate_void_contract_test.dart`.

The old test required this exact callback body:

```text
setState(() { _loadFuture = nextLoad; });
```

Pagination correctly added two related reload-state resets inside the same block before assigning `_loadFuture`:

- clear the load-more error;
- clear the load-more busy state;
- assign the new first-page future.

### Root cause

Again, the contract was testing an obsolete exact source body instead of the intended behavior: use a block-form `setState` callback, keep the refresh assignment inside it, and do not regress to the arrow assignment form that previously caused the void-callback problem.

### Permanent repair

The contract now:

- isolates `_reload()` from `_loadMore()`;
- verifies the debounce cancel and `_load()` call remain;
- verifies a block-form `setState(() {` is used;
- verifies `_loadFuture = nextLoad;` remains inside the reload region;
- rejects the arrow-form `setState(() => ...)` regression;
- applies the same semantic approach to the debounced filter refresh.

The existing runtime-stability contract remains in the gate and independently verifies stale-filter invalidation and retained results.

## Infrastructure interruption

Run `33507861995` attempt 1 stopped at `flutter pub get` because the Dart package service returned HTTP 403 while fetching security advisories. The branch and lockfile were unchanged. Re-running the exact same job succeeded through dependency restore, proving this was external registry infrastructure rather than an application or dependency repair.

Do not modify application dependencies or runtime code in response to that isolated advisory-endpoint failure.

## Formatter-only diff cleanup

The successful `33507861995` implementation was functionally correct, but PR patch review showed that the newer Dart formatter had also rewritten unrelated pre-existing Directory formatting.

That formatting churn was not needed for pagination and would make the release harder to review and maintain.

The four implementation/test files were therefore reset to the exact verified production formatting, only the intended pagination and semantic contract repairs were reapplied, and the full gate was run again without formatting unrelated existing lines.

Clean-diff verification run:

```text
33508729866
```

It passed:

- exact four-file implementation/test mutation scope;
- Flutter dependency restore;
- `dart analyze lib test`;
- focused Dispatch Directory pagination tests;
- semantic source-contract tests;
- filter runtime-stability tests;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations;
- `git diff --check`.

Minimal verified implementation commit:

```text
e90107a77735b10b7191f26b127cdd8cf8de27c6
```

## Do not do

- Do not change functioning Directory runtime code merely to restore an old one-line source shape.
- Do not make source-contract tests depend on `dart format` line wrapping.
- Do not weaken privacy/projection checks; assert the semantic source markers instead.
- Do not remove the runtime-stability contract when changing filter or pagination state.
- Do not treat an isolated Pub advisory HTTP error as evidence that app dependencies must be changed.
- Do not accept large formatter-only churn in a bounded repair when the intended behavior can be reviewed as a smaller diff.

The durable rule is: **source-contract tests protect behavior and architectural markers, not incidental formatting; bounded releases should also keep unrelated formatting out of the final diff.**
