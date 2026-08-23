# Dispatch credential Dart format normalization

Date: 2026-08-18
Branch: `design/formal-beautification-foundation`

## Symptom

The credential reminder and notification checks passed, then the source-read-only verifier stopped at formatter stability:

```text
Changed lib/marketplace/marketplace_dispatch_credentials.dart
Changed test/marketplace_dispatch_credential_intelligence_test.dart
Credential intelligence Dart source is not formatter stable.
```

## Root cause

The credential intelligence migration materialized Dart source from a template but did not normalize that generated source through the pinned Dart formatter before handing control to the read-only verifier. The synchronized credential intelligence test could also arrive in a formatter-unstable state.

The verifier was correct to refuse an unformatted source set, but formatting was missing from the bounded preparation stage.

## Permanent control

`tool/normalize_dispatch_credential_dart_format.ps1` now owns deterministic formatting for only these credential targets:

- `lib/marketplace/marketplace_dispatch_credentials.dart`
- `test/marketplace_dispatch_credentials_test.dart`
- `test/marketplace_dispatch_credentials_privacy_contract_test.dart`
- `test/marketplace_dispatch_credential_intelligence_test.dart`

The normalizer:

1. branch-locks to the formal branch;
2. confirms credential-intelligence markers before touching production source;
3. backs up the exact four targets;
4. runs the pinned Dart formatter only on those targets;
5. immediately proves formatter stability;
6. does not touch the Dispatch tracker or unrelated production source.

`tool/run_dispatch_phase3_credential_gate.ps1` now runs this bounded formatter normalization before the source-read-only verifier.

## Future rule

Any migration or generator that materializes Dart source must run `dart format` on the exact files it creates or changes before declaring the source ready. A read-only verifier should check formatter stability but should not be responsible for fixing formatting drift.
