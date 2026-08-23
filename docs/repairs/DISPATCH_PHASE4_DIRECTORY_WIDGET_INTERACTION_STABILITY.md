# Dispatch Phase 4 Directory widget interaction stability

## Symptom

After the Firebase seed-isolation repair and after the empty-state scroll repair, the combined widget test `directory renders public cards and filters by service` still failed while the explicit empty-state test passed.

The failure was isolated to one long widget test that performed all of these actions in a single run:

1. scroll down through two lazy Directory cards;
2. scroll back up to the service dropdown;
3. open a long dropdown overlay;
4. tap a text finder for `Hotshot`;
5. scroll back down and assert the filtered result set.

That sequence mixed three independent contracts: list rendering, dropdown option exposure, and application filter wiring. It also depended on a generic text finder inside a Flutter overlay after multiple bidirectional scroll operations.

## Root cause class

This is a widget-test interaction stability problem, not evidence of a Directory filtering defect.

The model filter test already proves that `DispatchDirectoryEntry.matches` reduces entries by the structured service code. The remaining widget coverage should prove the application wiring without making the test depend on Flutter's internal dropdown overlay layout or on a long down/up/down scroll path.

## Permanent repair

The Directory widget coverage is decomposed into independent tests:

- seeded public cards render in the lazy Directory list;
- the service dropdown opens and exposes a hit-testable `Hotshot` taxonomy option;
- the Directory's public `DropdownButtonFormField.onChanged` callback is wired to the app filter state and reduces the result set;
- the explicit empty state renders after scrolling into the lazy viewport.

The tests now use the Directory `ListView` as the explicit scroll target instead of relying on whichever `Scrollable` happens to be first in the widget tree.

## Rules going forward

- Do not combine multiple long bidirectional scroll paths and dropdown-overlay selection into one acceptance test when each behavior can be proven independently.
- Do not use `.last` on a text finder to guess which dropdown overlay item is tappable. Use a hit-testable finder when testing the overlay itself.
- Test Flutter framework mechanics only as far as Pipe Buyer needs them. The application test must primarily prove our callback wiring and resulting Directory state.
- Keep the model filter test separate from the widget binding test.
- Do not change production Firebase, Firestore rules, provider data, or Directory filtering logic to repair this test harness failure.
