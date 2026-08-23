# Windows Firebase CLI fallback control

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Symptom

A bounded Dispatch engineering gate reached a Firebase Emulator Rules proof and then failed with:

```text
The term 'firebase' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

The application source, focused Node tests, and Functions syntax had already passed. The failure was the Windows tool invocation layer.

## Previously proven repair

`tool/start_live_test_sandbox.ps1` had already solved this exact machine-compatibility problem:

1. Check `Get-Command firebase`.
2. If the globally installed Firebase CLI exists, invoke `firebase` directly.
3. Otherwise require `npx` and invoke `npx --yes firebase-tools`.
4. Run `--version` before starting emulator work so CLI availability is proven before later stages.

The Phase 4 Directory gate regressed by bypassing that proven fallback and calling bare `firebase` directly.

## Permanent repair

The resolution logic is centralized in:

```text
tool/pipebuyer_firebase_cli.ps1
```

New Windows PowerShell engineering gates that require Firebase CLI must:

- synchronize/source `tool/pipebuyer_firebase_cli.ps1`;
- run `Assert-PipeBuyerFirebaseCli` before any product mutation that depends on later Firebase CLI work;
- call `Invoke-PipeBuyerFirebaseCli` instead of invoking bare `firebase`;
- never assume a global Firebase CLI is on PATH when `npx firebase-tools` is an accepted project fallback.

## Continuation rule after a late tooling failure

If application/source mutation and its focused tests have already passed, and a later environment/tooling stage fails, do not rerun the mutation automatically.

Instead:

1. fingerprint the already-applied production files;
2. fix only the tooling layer;
3. continue from the nearest read-only verification stage;
4. prove production hashes are unchanged by the continuation verifier.

For the Phase 4 Directory projection this continuation is:

```powershell
.\tool\verify_dispatch_phase4_directory_projection_continuation.ps1
```

## Accepted proof

On 2026-08-20 the continuation gate passed on the Windows development machine with:

```text
PIPE BUYER PHASE 4 DIRECTORY PROJECTION CONTINUATION PASSED
Previously applied Directory source: PASS
Projection/privacy contracts: PASS
Functions syntax: PASS
Firebase CLI global-or-npx fallback: PASS
Firestore Rules emulator proof: PASS
Phase 3: 15/15 GREEN
Phase 4: IN PROGRESS
Production source modified by continuation: NO
Ready for next Phase 4 slice: YES
```

This is the canonical proof that the fallback and continuation pattern works in the real Pipe Buyer local workflow.

## Why this control exists

A machine-specific PATH difference must not create a repair loop or be misdiagnosed as a Flutter, Firebase data, Firestore Rules, Dispatch, or application-code failure.

The gate should fail during preflight if neither `firebase` nor `npx` can start. Once preflight passes, later stages use the same resolved invocation path.
