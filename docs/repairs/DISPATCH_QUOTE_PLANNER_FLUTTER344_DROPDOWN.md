# Dispatch quote planner Flutter 3.44 DropdownButtonFormField repair

## Symptom

The Dispatch quote planner implementation, formatter, and generator checks completed, but strict Dart analysis failed with two `deprecated_member_use` infos in `marketplace_dispatch_dashboard.dart`.

The reported API was `DropdownButtonFormField.value`.

## Root cause

Flutter 3.44 deprecates the `value` constructor argument for `DropdownButtonFormField` in favor of `initialValue`. The quote-planner generator was authored with the older constructor argument for:

- the selected Marketplace listing dropdown;
- the requested unit/equipment type dropdown.

The application behavior was not the failing layer. The strict analyzer intentionally treats infos as fatal so SDK compatibility drift is corrected before browser acceptance.

## Proven source fix

Replace only these constructor arguments in the Dispatch quote planner:

```text
value: selectedValue
-> initialValue: selectedValue

value: requirement.typeCode
-> initialValue: requirement.typeCode
```

Then run formatter stability, strict analyzer, the quote-planner contract, and Dispatch navigation/auth regressions.

## Permanent control change

`tool/verify_dispatch_quote_planner_source_map_units.ps1` is now verification-only. It no longer executes the implementation generator during every verification run. Once the source implementation exists, the Dart source is authoritative and the verifier only checks markers, formatting, strict analysis, and focused regressions.

This prevents a historical generator from repeatedly becoming part of the runtime repair path.
