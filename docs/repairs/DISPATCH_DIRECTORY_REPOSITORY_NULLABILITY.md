# Dispatch Directory repository nullability compile repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Symptom

After the Directory filter runtime mutation had already been applied, the read-only continuation correctly stopped at strict analyzer with:

```text
The method 'loadPage' can't be unconditionally invoked because the receiver can be 'null'.
lib/marketplace/marketplace_dispatch_directory.dart:325:29
unchecked_use_of_nullable_value
```

## Root cause

The active local Directory candidate carried a nullable state field for the repository even though `initState` deterministically assigns either the injected repository or a new `MarketplaceDispatchDirectoryRepository()` before `_load()` is used.

The accepted Directory source shape is therefore:

```dart
late final MarketplaceDispatchDirectoryRepository _repository;

@override
void initState() {
  super.initState();
  _repository = widget.repository ?? MarketplaceDispatchDirectoryRepository();
  _loadFuture = _load();
}
```

The state repository must not remain nullable merely because the widget injection point is nullable.

## Why the saved controls mattered

The read-only continuation did the correct thing at this stage:

```text
production source hash
-> production formatter check
-> production analyzer BEFORE tests
-> STOP on the first concrete source diagnostic
```

It did not rerun the Directory mutation and it exposed the exact source defect instead of another vague test-load failure.

The missing earlier protection was candidate compilation before the original runtime mutation. That has already been added to the canonical runtime repair gate.

## Permanent repair control

Semantic transform:

```text
tool/dispatch_directory_repository_nullability_transform.mjs
```

Candidate verifier:

```text
tool/verify_dispatch_directory_repository_nullability_candidate.mjs
```

Bounded source repair:

```text
tool/apply_dispatch_directory_repository_nullability_fix.mjs
```

Focused gate:

```powershell
.\tool\run_dispatch_directory_repository_nullability_repair.ps1
```

Regression:

```text
test/dispatch_directory_repository_nullability_contract_test.dart
```

## Required gate behavior

```text
sync focused controls
-> parse controls
-> format support tests only
-> transform exact local source into temporary candidate
-> format + strict-analyze candidate BEFORE production write
-> prove production source unchanged by candidate preflight
-> apply only repository nullability correction
-> format production source
-> strict-analyze production source BEFORE tests
-> run nullability + runtime + existing Directory regressions
-> prove Dispatch tracker unchanged
```

## Future rule

If a widget accepts a nullable dependency injection parameter but `initState` always resolves a concrete implementation, the corresponding State field should be non-null and `late final` unless there is a real lifecycle state where absence is meaningful.

Do not use `?.` or `!` to silence this analyzer error when the stronger invariant is already guaranteed by initialization. Encode the invariant in the field type and protect it with a regression contract.
