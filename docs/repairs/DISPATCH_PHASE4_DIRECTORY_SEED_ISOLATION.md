# Dispatch Phase 4 Directory seed isolation repair

## Date

2026-08-17

## Symptom

The Phase 4 Directory strict analyzer passed, but the first widget tests failed with:

```text
[core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
```

The follow-on expectations for `Prairie Hotshot` and `No companies are listed yet` also failed because the widget never finished building.

## Root cause

`MarketplaceDispatchDirectoryPage` supports `seedEntries` specifically so widget tests and deterministic previews can render without Firestore. However, `initState()` always constructed `MarketplaceDispatchDirectoryRepository` before `_load()` checked `seedEntries`.

The repository constructor defaults to `FirebaseFirestore.instance`, which requires a Firebase app. Therefore the supposedly backend-free seeded path still touched Firebase during widget creation.

This was one initialization-order defect. The missing Directory cards and empty state were cascading failures, not separate UI defects.

## Permanent repair

- The Directory repository field is nullable.
- `initState()` creates the default Firestore repository only when `seedEntries == null`.
- Seeded Directory rendering never initializes Firebase when no repository was explicitly supplied.
- Non-seeded production behavior is unchanged and still creates the real Firestore-backed repository.
- `_load()` fails explicitly if a non-seeded path somehow reaches it without a repository instead of silently touching another backend path.
- Existing widget tests are retained as the regression proof: seeded cards and seeded empty state must render without Firebase initialization.

## Narrow repair tool

```text
tool/repair_dispatch_phase4_directory_seed_isolation.mjs
```

The repair is idempotent and stops if the expected source shape is not present. It changes only `lib/marketplace/marketplace_dispatch_directory.dart`.

## Do not do

- Do not initialize Firebase in these widget tests merely to suppress the failure.
- Do not remove the seeded test path.
- Do not weaken the Directory tests.
- Do not change Firestore rules, Auth, emulator fixtures, or production Firebase configuration for this failure.

The correct repair is dependency isolation: a deterministic seed path must not instantiate the production backend dependency it is designed to replace.
