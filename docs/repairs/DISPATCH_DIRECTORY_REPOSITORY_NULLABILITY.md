# Dispatch Directory repository nullability compile repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Original symptom

The Directory runtime continuation correctly stopped at strict analyzer with:

```text
The method 'loadPage' can't be unconditionally invoked because the receiver can be 'null'.
lib/marketplace/marketplace_dispatch_directory.dart:325:29
unchecked_use_of_nullable_value
```

The read-only continuation did the correct thing: it hashed production source, checked formatter stability, ran production analyzer before tests, and stopped on the concrete source diagnostic instead of rerunning earlier mutations.

## Earlier conclusion - now superseded

The first repair concluded that the State repository should always be non-null `late final` and eagerly initialized in `initState`:

```dart
late final MarketplaceDispatchDirectoryRepository _repository;
_repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();
```

That conclusion was incomplete.

Later widget acceptance proved that `seedEntries` is a real lifecycle where repository absence is meaningful. `MarketplaceDispatchDirectoryRepository()` eagerly resolves `FirebaseFirestore.instance`, so constructing it in `initState` forces Firebase initialization even when the widget is intentionally using deterministic seed data and `_load()` never needs Firestore.

All seeded Directory widget tests then failed together despite production analyzer PASS.

## Current accepted invariant

The repository is nullable **until live Firestore data is actually requested**:

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

This keeps the analyzer safe without using an unsafe unconditional nullable call, while also preserving the dependency-free seeded widget path.

## Canonical permanent repair

The current authoritative repair record is:

```text
docs/repairs/DISPATCH_DIRECTORY_SEEDED_REPOSITORY_LIFECYCLE.md
```

Use:

```powershell
.\tool\run_dispatch_directory_seed_safe_repository_repair.ps1
```

The gate must compile the exact local candidate **and run a seeded widget runtime proof without Firebase initialization before production mutation**. Analyzer-only candidate validation is insufficient for eager dependency-construction defects.

## Future rule

If a widget has `seedEntries`, fixture data, offline preview data, or another deterministic local-data mode, do not eagerly construct network/Firebase dependencies before that local-data branch is evaluated.

The stronger invariant is not always “make nullable state non-null.” The stronger invariant is “represent the real lifecycle accurately and prove every mode.”
