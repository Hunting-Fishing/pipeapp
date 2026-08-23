# Dispatch Directory mouse-tracker freeze repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Symptom

During browser acceptance, selecting a Dispatch Directory filter caused a repeating Flutter scheduler assertion and the browser UI froze:

```text
package:flutter/src/rendering/mouse_tracker.dart
Assertion failed
MouseTracker._deviceUpdatePhase
MouseTracker.updateAllDevices
RendererBinding._scheduleMouseTrackerUpdate
```

Once the cascade started, the user could no longer change the filter selection.

## Classification

This is not a Firestore query failure, Auth failure, Firebase emulator failure, or the previously repaired Future-returning `setState` callback.

The stack is Flutter framework mouse/hover tracking during a scheduler callback. Flutter has a long-running reproducible desktop/web issue class where rapid widget/hit-test changes under a mouse can re-enter the mouse tracker and produce `_debugDuringDeviceUpdate` / `_deviceUpdatePhase` assertions, followed by repeated exceptions and UI freeze.

The Directory filter bar still used three `DropdownButtonFormField<String>` controls. Those controls use popup/overlay routes and mouse-aware menu items. Selecting an item tears down the popup hit-test tree while the pointer remains active, exactly the type of geometry churn implicated by the framework issue class.

## Proper application-level solution

Do not suppress the assertion and do not run the app in release mode merely to hide debug assertions.

For the Directory filter hot path, remove overlay dropdown selectors entirely and use same-tree inline selectors:

```text
Service
Availability
Business type
```

Each selector:

- renders choices inside the existing Directory filter card rather than an Overlay/Route;
- uses `GestureDetector` instead of dropdown/menu hover machinery;
- defers pointer-triggered geometry changes until a post-frame callback;
- closes the inline selector first;
- applies parent filter state on the following frame;
- preserves the accepted 180 ms Directory remote-refresh debounce;
- preserves retained Directory results while the refresh runs.

This intentionally reduces pointer/hit-test churn around the active mouse device.

## Why a Flutter SDK upgrade is not the primary repair

The `_deviceUpdatePhase` / `_debugDuringDeviceUpdate` freeze class has existed across multiple Flutter stable releases and remains represented by open/reproducible framework issues. Upgrading Flutter may still be useful independently, but it is not a deterministic fix for this Directory interaction and must not replace an application-level stable interaction design.

## Permanent controls

Canonical transform:

```text
tool/dispatch_directory_pointer_stable_filter_transform.mjs
```

Exact-local candidate verifier:

```text
tool/verify_dispatch_directory_pointer_stable_candidate.mjs
```

Bounded apply step:

```text
tool/apply_dispatch_directory_pointer_stable_filter_fix.mjs
```

Candidate mouse-interaction runtime proof:

```text
tool/templates/dispatch_directory_pointer_stable_candidate_widget_test.dart.txt
```

Static contract:

```text
test/dispatch_directory_pointer_stable_filter_contract_test.dart
```

Focused gate:

```powershell
.\tool\run_dispatch_directory_pointer_stable_filter_repair.ps1
```

The older dropdown layout transform has also been made pointer-stable aware. Once inline selectors are installed, that older transform must return without recreating `DropdownButtonFormField`.

## Required proof before production mutation

```text
exact current local Directory source
-> pointer-stable transform in memory
-> second-pass idempotency
-> temporary candidate only
-> formatter
-> strict analyzer
-> seeded Directory runtime
-> repeated mouse-kind Service selection
-> repeated open/close and filter changes
-> require zero Flutter exceptions
-> prove production source hash unchanged
-> only then apply production repair
```

## Future build rule

When a web/desktop interaction freezes with Flutter `MouseTracker._deviceUpdatePhase`, do not keep adjusting business logic, Firestore queries, or debounce timing unless the first exception points there.

First classify whether the trigger is overlay/hit-test/mouse geometry churn. For frequently used filters, prefer same-tree interaction controls over transient mouse-heavy overlays when a framework mouse-tracker reentrancy issue has been reproduced.
