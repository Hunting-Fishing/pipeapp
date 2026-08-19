# Dispatch Directory widget-test harness repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Symptom

After the Directory repository nullability source repair reached production analyzer PASS, the remaining failure moved to `test/marketplace_dispatch_directory_test.dart`.

The final failing test reported:

```text
directory has an explicit empty state
Multiple exceptions were detected during the running of the current test
```

The source gate correctly said not to rerun the source repair because production analyzer had already passed.

## Existing project pattern that should have been reused

Pipe Buyer already has responsive widget-test harness controls in tests such as:

```text
test/marketplace_dispatch_onboarding_test.dart
test/marketplace_grid_density_test.dart
```

Those tests explicitly set the Flutter test surface before exercising responsive UI and restore it afterward:

```dart
await tester.binding.setSurfaceSize(const Size(1200, 1000));
addTearDown(() => tester.binding.setSurfaceSize(null));
```

The Dispatch Directory widget test did not use that established control. It relied on Flutter's default test viewport and used `dragUntilVisible`, making a large responsive Directory surface sensitive to viewport/layout/scroll behavior unrelated to the source repair being verified.

The Directory runtime repair also intentionally introduced a 180 ms debounced filter refresh. The old widget test relied on generic `pumpAndSettle` behavior instead of deliberately pumping past the accepted debounce boundary.

## Permanent correction

Canonical Directory widget test:

```text
test/marketplace_dispatch_directory_test.dart
```

It now:

1. sets a deterministic 1200 x 1000 desktop surface;
2. restores the test surface with `addTearDown`;
3. uses `scrollUntilVisible` on the page Scrollable rather than repeated drag gestures;
4. pumps 220 ms after a filter change to cross the accepted 180 ms debounce boundary deterministically;
5. keeps the empty-state, seeded-card, Hotshot dropdown, and filter-result assertions.

Harness hygiene contract:

```text
test/dispatch_directory_widget_test_harness_hygiene_test.dart
```

The hygiene test prevents the Directory suite from regressing back to:

- the implicit default viewport;
- missing surface cleanup;
- `dragUntilVisible` for the Directory acceptance suite;
- generic settling without acknowledging the 180 ms debounce contract.

Read-only continuation:

```text
tool/verify_dispatch_directory_widget_test_continuation.ps1
```

The continuation follows the late-failure rule:

```text
already-applied production source
-> hash source and tracker
-> synchronize corrected tests only
-> format support/tests only
-> check production formatter stability without writing
-> production analyzer BEFORE tests
-> widget-test harness hygiene
-> Directory widget tests in isolation with expanded reporter
-> retained runtime/nullability/projection tests
-> strict analyzer on support tests
-> prove production source hash unchanged
-> prove tracker hash unchanged
```

## Future rule

Responsive Flutter widget tests must not depend on the framework's implicit default viewport when the page has desktop/mobile breakpoints or large scrollable content.

Before adding a new page-level widget test, reuse the existing Pipe Buyer test harness pattern:

```dart
await tester.binding.setSurfaceSize(const Size(...));
addTearDown(() => tester.binding.setSurfaceSize(null));
```

If the production interaction intentionally uses debounce/throttle timing, the widget test must explicitly pump past that timing boundary rather than relying on an unrelated generic settle loop.

Most importantly, once production analyzer passes after a bounded source repair, a later widget-test harness failure is a test-layer issue until concrete browser/runtime evidence proves otherwise. Do not rerun the already-successful source mutation.
