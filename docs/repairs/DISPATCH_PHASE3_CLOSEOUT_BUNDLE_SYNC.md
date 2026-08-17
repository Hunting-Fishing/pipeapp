# Dispatch Phase 3 Closeout Support Bundle Sync

**Branch:** `design/formal-beautification-foundation`

**Status:** CONTROL ADDED

## Symptom

`tool/verify_dispatch_credential_intelligence.ps1` stopped before changing production source because this prerequisite file was missing locally:

```text
test/service_area_geocoder_classification_test.dart
```

The credential-intelligence verifier intentionally re-runs the immediately preceding Towns/Regions map regression before allowing the next Phase 3 slice to proceed.

## Root cause

The operator sync command fetched the new credential-intelligence files but omitted a transitive support dependency from the prior accepted service-area slice. The verifier correctly stopped instead of silently skipping the missing regression.

This was a bundle/synchronization defect, not a credential implementation failure and not a Firebase/runtime failure.

## Permanent control

`tool/sync_dispatch_phase3_closeout_bundle.ps1` now owns the support-file manifest for the complete Phase 3 closeout sequence.

The sync script:

- branch-locks to `design/formal-beautification-foundation`;
- fetches without merge or branch switching;
- synchronizes both the Towns/Regions regression support and credential-intelligence support;
- never checks out production Dart/Functions source;
- immediately unstages fetched support files;
- verifies the entire support bundle exists before returning success.

Production changes continue to be made only by the guarded fix/apply scripts and verified by the corresponding gates.

## Correct sequence

```powershell
.\tool\sync_dispatch_phase3_closeout_bundle.ps1
.\tool\verify_service_area_geocoder_classification.ps1
.\tool\verify_dispatch_credential_intelligence.ps1
```

This preserves the accepted repair discipline:

```text
support bundle sync
-> prior-slice regression proof
-> bounded current-slice migration
-> current-slice engineering gate
-> emulator/browser acceptance
```

Do not weaken or remove a prior accepted regression merely because the support file was omitted from a local sync command.
