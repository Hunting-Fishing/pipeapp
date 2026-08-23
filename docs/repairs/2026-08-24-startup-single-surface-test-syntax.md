# Repair Record — startup single-surface test syntax

Date: 2026-08-24
Release attempt SHA: `379a0ee1cbf156f9710d88a647a5c3619cc6d264`

## Symptom

The local production deployment stopped during `dart analyze lib test` before Flutter tests, web build, or Firebase deployment.

Analyzer error:

`test/startup_single_surface_test.dart:37:67 • Expected to find ')' • expected_token`

## Root cause

The OAuth/startup contract reconciliation added a test assertion with one missing closing parenthesis:

Incorrect:

```dart
expect(source, isNot(contains('Duration(milliseconds: 3000)'));
```

Correct:

```dart
expect(source, isNot(contains('Duration(milliseconds: 3000)')));
```

This was a test-source syntax typo only. The service-truck/pumpjack startup HTML, OAuth identity content, Firebase configuration, Stripe configuration, application runtime, and payment activation were not implicated.

## Repair

Added the missing closing parenthesis only. No analyzer suppression, dependency change, runtime change, or release-gate bypass.

## Release safety

The deployment script stopped before `flutter build web` and before any Firebase publish command, so production remained unchanged by the failed attempt.

## Future diagnostic rule

If `dart analyze` reports `expected_token` in a release-contract test immediately after a test edit, inspect the exact test syntax first. Do not modify application/runtime behavior or weaken the deployment gate to work around a test parser error.
