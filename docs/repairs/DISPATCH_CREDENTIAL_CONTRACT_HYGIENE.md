# Dispatch credential source-contract hygiene

**Date:** 2026-08-19
**Branch:** `design/formal-beautification-foundation`

## Symptom

The read-only credential analytics verifier reached the persistence regression and failed even though the already-applied production analytics interaction source was present and the analytics-specific interaction contract had passed.

The failing assertion was:

```dart
source.contains("const Text('View details')")
```

The production widget had been formatted across multiple lines and also contained additional widget arguments, so the exact physical source spelling was not a valid behavior contract.

## Root cause

A secondary regression test retained the same formatter-sensitive source-layout assumption that had already been removed from the primary analytics action contract.

This was a test-control defect, not a credential persistence or analytics application defect.

## Permanent correction

1. `test/marketplace_dispatch_credential_persistence_discoverability_test.dart` now uses a whitespace-tolerant semantic check for the `View details` text and additionally requires `button: true` and `InkWell(`.
2. `test/marketplace_dispatch_credential_contract_hygiene_test.dart` now rejects exact `source.contains("const Text(...")` style assertions in the credential source-contract tests.
3. `tool/verify_dispatch_credential_analytics_actions_readonly.ps1` runs the contract-hygiene test before the feature regressions.
4. The verifier remains source-read-only and proves the production credential Dart hash is unchanged after verification.

## Rule going forward

When source-inspection tests validate Dart UI behavior, they must assert semantic markers and interactions, not formatter-controlled widget layout. A fixed primary test is not sufficient; all sibling regression tests in the same verification path must be audited together.
