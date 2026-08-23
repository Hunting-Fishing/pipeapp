# Dispatch credential analytics V4 self-validation repair

**Date:** 2026-08-18
**Branch:** `design/formal-beautification-foundation`

## Symptom

The atomic V4 migration passed its PowerShell and Node syntax preflight, transformed the credential analytics source entirely in memory, then stopped before writing with:

```text
STOP: marketplace_dispatch_credentials.dart: transformed source is missing 'const Text(\'View details\')'.
```

## Root cause

The V4 production transformation was formatter-tolerant, but its own final self-validation still required the exact one-line Dart spelling:

```dart
const Text('View details')
```

The generated Dart intentionally used the formatter-safe multiline equivalent:

```dart
const Text(
  'View details',
  ...
)
```

So V4 rejected its own valid generated source before any production write occurred.

## Permanent correction

The normal gate now uses:

```text
tool/apply_dispatch_credential_analytics_actions_v5.mjs
```

V5 preserves the already-reviewed V4 atomic transformation unchanged and hardens only the two known formatter-sensitive self-validation literals in memory before executing it. The UI contract test now uses a whitespace-tolerant regular expression for the `View details` label as well.

The gate still performs:

1. PowerShell parse preflight;
2. Node syntax preflight;
3. atomic in-memory transformation of live source and canonical template;
4. bounded backup/write only after both transformations validate;
5. Dart formatting;
6. credential analytics interaction contract;
7. credential persistence regression;
8. formatter stability proof;
9. strict analyzer.

## Rule going forward

A formatter-tolerant migration must also have formatter-tolerant self-validation and formatter-tolerant regression tests. Validation must assert semantic markers rather than one physical Dart line layout.
