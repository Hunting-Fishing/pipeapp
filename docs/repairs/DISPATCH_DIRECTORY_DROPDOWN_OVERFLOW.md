# Dispatch Directory dropdown overflow repair

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Symptom

A first-exception diagnostic against the exact local seed-safe Directory candidate reported:

```text
PIPEBUYER_FIRST_EXCEPTION_PHASE=firstPump
PIPEBUYER_FIRST_EXCEPTION_CLASS=LAYOUT_OVERFLOW
PIPEBUYER_FIRST_EXCEPTION_TYPE=FlutterError
A RenderFlex overflowed by 141 pixels on the right.
```

The rendering stack identified `DropdownButtonFormField<String>` in the Directory filter card. The overflow occurred before any user interaction and before Firebase was needed.

## Root cause

The desktop Directory filter card places Service, Availability, and Business type dropdowns in one row when the card is wide enough. Each `DropdownButtonFormField` was created with the Flutter default `isExpanded: false`.

With `isExpanded: false`, the dropdown button can size itself from the intrinsic width of its menu-item content. The structured Dispatch service taxonomy includes long labels, so the Service dropdown attempted to exceed the width allocated by its `Expanded` parent. At the diagnostic width the field had about 408 px available, but its internal Row wanted roughly 141 px more.

This is why the previous widget tests failed together even after repository/Firebase lifecycle work: the first rendering exception was a layout overflow, not a Firebase exception.

## Accepted fix

All three responsive Directory filter dropdowns must explicitly opt into the width provided by their parent:

```dart
DropdownButtonFormField<String>(
  isExpanded: true,
  ...
)
```

Required fields:

```text
Service
Availability
Business type
```

## Combined lifecycle rule

The seeded Directory acceptance path has two independent invariants and both must be proven in the same candidate before production mutation:

```text
seedEntries present
    -> do not construct Firebase-backed repository

responsive filter row
    -> all dropdowns consume only allocated width
```

A candidate that fixes only one invariant is insufficient.

## Permanent controls

Dropdown semantic transform:

```text
tool/dispatch_directory_dropdown_layout_transform.mjs
```

Combined seed-safe + layout candidate verifier:

```text
tool/verify_dispatch_directory_seed_safe_layout_candidate.mjs
```

Combined bounded apply step:

```text
tool/apply_dispatch_directory_seed_safe_layout_fix.mjs
```

Candidate widget runtime proof:

```text
tool/templates/dispatch_directory_seed_safe_layout_candidate_widget_test.dart.txt
```

Static contract:

```text
test/dispatch_directory_dropdown_layout_contract_test.dart
```

Focused gate:

```powershell
.\tool\run_dispatch_directory_seed_safe_layout_repair.ps1
```

## Required gate order

```text
sync focused controls
-> parse all Node/PowerShell controls
-> normalize support tests only
-> transform exact local production source into temporary candidate
-> apply seed-safe repository lifecycle to candidate
-> apply responsive dropdown width control to candidate
-> second candidate pass must be idempotent
-> format candidate
-> strict-analyze candidate
-> run candidate widget at 1400, 1000, and 820 px widths WITHOUT Firebase initialization
-> no Flutter exception permitted
-> prove production source unchanged by candidate preflight
-> apply the already-proven combined transform to production
-> format production
-> strict-analyze production BEFORE regressions
-> run seed-safe, dropdown-layout, widget, runtime-stability, and projection/query regressions
-> prove Dispatch tracker unchanged
```

## Future rule

For `DropdownButton` / `DropdownButtonFormField` used inside `Expanded`, `Flexible`, responsive Rows, or constrained filter panels, do not rely on intrinsic menu-item width. Use `isExpanded: true` whenever the control is expected to consume the width assigned by the layout.

Runtime candidate tests must exercise the actual responsive widths where controls share a row. Formatter/analyzer success cannot detect RenderFlex overflows.
