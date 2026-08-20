# Dispatch Directory Future-returning setState callback repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Symptom

After the seed-safe repository and dropdown-overflow candidate passed analyzer and responsive runtime proof, the real service-filter interaction test failed after the 180 ms debounce with:

```text
setState() callback argument returned a Future.
The setState() method ... was called with a closure or method that returned a Future.
```

The failure occurred in `_MarketplaceDispatchDirectoryPageState._setFilters` when the debounce timer fired.

## Root cause

The retained-results runtime transform generated this callback shape in both `_reload` and the debounced filter refresh:

```dart
setState(() => _loadFuture = _load());
```

In Dart an assignment expression evaluates to the assigned value. `_load()` returns `Future<DispatchDirectoryPageData>`, so the arrow callback itself returned that Future. Flutter `State.setState` requires a synchronous void callback and throws at runtime when the callback returns a Future.

This explains why strict analyzer passed while the widget interaction failed: the code is valid Dart, but violates Flutter's runtime `setState` callback contract.

## Correct lifecycle

Compute the next Future outside `setState`, then synchronously install it:

```dart
final nextLoad = _load();
setState(() {
  _loadFuture = nextLoad;
});
```

This is required in both:

- `_reload()`;
- the 180 ms filter debounce callback.

Do not replace this with `async` inside `setState`, and do not use another arrow assignment that returns a non-void value.

## Why earlier candidate proof missed it

The combined seed-safe/layout candidate runtime proof rendered the Directory at multiple widths but did not actually change a filter and wait for the 180 ms debounce. Therefore it proved:

- no eager Firebase initialization;
- no initial dropdown overflow;

but it did not exercise the delayed filter callback.

A candidate runtime test must exercise the interaction/lifecycle being changed, not only initial rendering.

## Permanent controls

Canonical callback transform:

```text
tool/dispatch_directory_filter_setstate_transform.mjs
```

Exact-local candidate verifier:

```text
tool/verify_dispatch_directory_filter_setstate_candidate.mjs
```

Bounded apply step:

```text
tool/apply_dispatch_directory_filter_setstate_fix.mjs
```

Focused gate:

```powershell
.\tool\run_dispatch_directory_filter_setstate_repair.ps1
```

Static regression:

```text
test/dispatch_directory_filter_setstate_void_contract_test.dart
```

Interactive candidate runtime proof:

```text
tool/templates/dispatch_directory_filter_setstate_candidate_widget_test.dart.txt
```

## Required gate order

```text
sync focused controls
-> parse controls
-> transform exact current local source into temporary candidate
-> verify transform idempotency
-> format candidate
-> strict-analyze candidate
-> run seeded Hotshot filter interaction
-> wait past the 180 ms debounce
-> rapidly switch filters to exercise timer cancellation
-> require zero Flutter exceptions
-> prove production source unchanged
-> apply only the proven callback correction
-> format/analyze production before regressions
-> rerun the exact previously failing Directory widget suite first
-> run seed-safe/layout/runtime/projection sibling regressions
-> prove Dispatch tracker unchanged
```

## Future build rule

A Flutter candidate test for a debounced, delayed, timer-driven, callback-driven, or asynchronous UI lifecycle must exercise the delayed callback itself before production mutation.

Initial-render-only widget tests are insufficient for lifecycle repairs.

For `setState`, never pass a callback whose expression returns a Future or another non-void value. Prefer a block callback and keep asynchronous work outside the state mutation callback.
