# Dispatch Directory seeded repository lifecycle repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Browser/test symptom

After the Directory repository field had been changed to non-null `late final`, production analyzer passed but all seeded Directory widget tests failed together, including:

- seeded company card rendering;
- Hotshot service dropdown;
- service filter result reduction;
- explicit empty state.

The widget tests intentionally construct `MarketplaceDispatchDirectoryPage(seedEntries: ...)` so they can exercise Directory behavior without Firebase initialization.

## Root cause

`MarketplaceDispatchDirectoryRepository` eagerly resolves `FirebaseFirestore.instance` in its constructor:

```dart
MarketplaceDispatchDirectoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
```

The previous nullability repair changed the State lifecycle to eagerly do this in `initState`:

```dart
_repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();
```

That was incorrect for seeded mode. Even though `_load()` returns seeded entries before reading Firestore, the repository constructor had already touched `FirebaseFirestore.instance`. Seed-only widget tests therefore required a Firebase app even though they were specifically designed not to.

The earlier assumption that repository absence was never meaningful was wrong. Repository absence **is meaningful while the Directory is operating from `seedEntries`**.

## Accepted lifecycle

The correct State lifecycle is lazy:

```dart
MarketplaceDispatchDirectoryRepository? _repository;

@override
void initState() {
  super.initState();
  _repository = widget.repository;
  _loadFuture = _load();
}

Future<DispatchDirectoryPageData> _load() {
  final seed = widget.seedEntries;
  if (seed != null) {
    return Future.value(...);
  }

  final repository =
      _repository ??= MarketplaceDispatchDirectoryRepository();
  return repository.loadPage(...);
}
```

Seeded mode does not initialize Firebase-backed repository state. Live mode lazily creates the repository only after the seed branch has been ruled out.

## Permanent controls

Semantic source transform:

```text
tool/dispatch_directory_seed_safe_repository_transform.mjs
```

Candidate verifier:

```text
tool/verify_dispatch_directory_seed_safe_repository_candidate.mjs
```

Bounded apply step:

```text
tool/apply_dispatch_directory_seed_safe_repository_fix.mjs
```

Focused gate:

```powershell
.\tool\run_dispatch_directory_seed_safe_repository_repair.ps1
```

Static regression:

```text
test/dispatch_directory_seed_safe_repository_contract_test.dart
```

Candidate runtime proof template:

```text
tool/templates/dispatch_directory_seed_safe_candidate_widget_test.dart.txt
```

## Required gate order

```text
sync focused controls
-> parse controls
-> normalize support tests only
-> widget-test harness hygiene
-> transform exact local production source into temporary same-directory candidate
-> format candidate
-> strict-analyze candidate
-> run candidate seeded-widget test WITHOUT Firebase initialization
-> prove production source unchanged
-> apply only the proven lifecycle correction
-> format production
-> strict-analyze production BEFORE tests
-> run seed-safe + Directory widget regressions
-> run runtime/projection regressions
-> prove Dispatch tracker unchanged
```

The candidate widget runtime proof is mandatory. Analyzer-only candidate validation would not detect eager `FirebaseFirestore.instance` access because that is a runtime initialization problem.

## Superseded rule

The earlier repair note that the Directory repository State field should always be non-null `late final` is superseded for this widget. The widget has a legitimate seed-only lifecycle where a repository must remain absent until live Firestore data is actually requested.

Do not fix this by initializing Firebase in every widget test. Do not hide the issue with `!`. Preserve the seed-only test boundary and make repository construction lazy.

## Future build rule

Any widget with deterministic `seedEntries`, fixture data, offline preview data, or injected local data must not eagerly construct network/Firebase dependencies before the seeded-data branch is evaluated.

For these widgets:

```text
seed / injected deterministic data available
    -> render using it
    -> do not initialize remote dependency

no seed data
    -> lazily initialize remote dependency
    -> perform live query
```

Candidate preflight for lifecycle changes must include a runtime test that exercises the dependency-free seeded path, not only formatter/analyzer checks.
