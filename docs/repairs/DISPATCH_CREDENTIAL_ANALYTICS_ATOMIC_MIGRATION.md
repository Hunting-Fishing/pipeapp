# Dispatch credential analytics atomic migration control

**Date:** 2026-08-18
**Branch:** `design/formal-beautification-foundation`

## Symptom

The first credential analytics action migration stopped after reporting:

```text
Removed 2 legacy Records-view Analytics shortcut card(s)
STOP: Expected exactly one source target for 'create drill-down record collections', found 0.
```

## Root cause

The migration used exact multiline Dart source anchors. `dart format` is allowed to wrap assignments and widget calls without changing behavior, so a semantically valid credential source no longer matched the migration's physical whitespace/layout assumptions.

This was a tooling/control defect, not a Credential Analytics application defect.

## Permanent correction

Normal credential analytics action work now uses:

```text
tool/apply_dispatch_credential_analytics_actions_v4.mjs
tool/run_dispatch_credential_analytics_actions_gate.ps1
```

The V4 migration:

1. validates the formal branch;
2. reads both the live credential Dart source and its canonical template;
3. performs all planned transformations in memory first;
4. uses semantic section boundaries rather than exact multiline formatting;
5. refuses ambiguous/missing boundaries instead of guessing;
6. writes nothing unless both source transformations reach the required contract;
7. creates backups immediately before the bounded write;
8. is resumable/idempotent when some UI cleanup was already applied;
9. leaves the Dispatch tracker untouched.

The gate additionally runs `node --check`, Dart formatting, the interaction contract, the credential persistence regression, formatter-stability proof, and strict analysis.

## Rule going forward

Dart migrations must not depend on formatter-controlled whitespace or line wrapping. Use semantic markers and bounded section identities, preflight the complete planned transformation before mutation, then verify the resulting behavior separately.
