# Dispatch Phase 4 Directory Widget Scroll Repair

## Symptom

After the Firebase seed-isolation repair, the Phase 4 Directory model tests passed but the two widget tests still failed to find:

- `Prairie Hotshot`
- `No companies are listed yet`

The test runner reported the failures at the direct `find.text(...)` expectations.

## Root cause

The Directory is intentionally implemented as a vertically scrollable `ListView`. Its header and filter controls occupy enough vertical space that company cards and empty-state content may be below the default Flutter widget-test viewport. `ListView` builds children lazily, so a child below the current viewport may not exist in the element tree yet.

This was a test-harness defect, not a Directory rendering, Firestore, Firebase initialization, filter, or data-model defect.

## Permanent repair

`test/marketplace_dispatch_directory_test.dart` now scrolls the real Directory `Scrollable` with `tester.dragUntilVisible(...)` before asserting content that may be lazily built below the viewport. The test also scrolls back to the service filter before interacting with it.

The product Directory widget was not changed for this repair.

## Permanent rule

For long Pipe Buyer forms, directories, and result lists:

1. Keep representative test viewport sizes.
2. Do not enlarge the viewport merely to make lower controls appear.
3. Use `ensureVisible` for an already-built off-screen target.
4. Use `dragUntilVisible` when a lazy `ListView` child may not yet be built.
5. Fix the test harness when the product scroll behavior is intentional and analyzer/product logic are already green.

This is the same class of test-harness issue previously seen in the Phase 3 Company Profile form and should not be diagnosed as a Firebase or product-data failure again.
