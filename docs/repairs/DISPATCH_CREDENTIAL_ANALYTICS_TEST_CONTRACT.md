# Dispatch credential analytics semantic test contract

**Date:** 2026-08-18
**Branch:** `design/formal-beautification-foundation`

## Symptom

The analytics interaction migration completed and formatting succeeded, but the Flutter contract failed on the visible `View details` label.

## Root cause

The regression test still assumed `Text('View details')` had no additional constructor arguments. The actual valid widget includes a `style:` argument, so the test produced a false negative even though the label and interaction were present.

## Permanent correction

The analytics action contract now validates behavior-oriented semantic markers instead of the physical spelling of the `Text` constructor:

- visible `'View details'` label;
- `Semantics(button: true)`;
- `InkWell`;
- `onTap`;
- metric drill-down methods;
- record collections behind each metric;
- metadata/evidence actions.

A read-only continuation verifier is provided at:

```text
tool/verify_dispatch_credential_analytics_actions_readonly.ps1
```

It is used after a migration has already completed but a later contract failed. It hashes the production Dart source before and after verification and fails if the verifier modifies that source.

## Rule going forward

When a bounded mutation has completed successfully and a later verifier/test fails, do not rerun the mutation by default. Fix the verifier/test contract, then continue with a read-only verifier against the already-applied source.
