# Flutter Web MouseTracker Debug Assertion

## Symptom

During formal browser acceptance in Flutter debug mode, ordinary mouse-driven navigation or selection can trigger a repeating framework assertion in:

`packages/flutter/lib/src/rendering/mouse_tracker.dart`

The console repeatedly reports an assertion during a scheduler callback from `MouseTracker._deviceUpdatePhase`. Chrome can become greyed/frozen and every additional pointer movement can produce more exceptions.

This has been observed while changing Dispatch Directory filters and again while selecting Dispatch -> Request Service. The target page can already be visibly rendered when the exception flood starts.

## Classification

This is a Flutter debug-runtime/framework assertion path, not evidence by itself of:

- Firebase emulator failure;
- Firestore/Functions/Auth failure;
- Quote V2 business logic failure;
- Dispatch Request Service data corruption;
- stale Quote V2 source;
- a requirement to rerun source migrations.

Do not mutate application source merely because this debug assertion repeats.

## Permanent acceptance rule

Use the normal debug client for development diagnostics when needed:

`tool/launch_formal_flutter_client.ps1`

Use the release-mode formal client for browser interaction acceptance when the debug `MouseTracker._deviceUpdatePhase` assertion recurs:

`tool/launch_formal_flutter_client_release.ps1`

The release launcher uses the same canonical local origin and emulator definitions:

- App: `http://127.0.0.1:5050`
- Auth: 19099
- Firestore: 18080
- Functions: 15001
- Storage: 19199

It also runs `ensure_formal_acceptance_ready.ps1` before launching, so deterministic fixtures and credentials remain part of acceptance.

## Procedure after the assertion appears

1. Stop only the frozen Flutter client with `q` in its Flutter terminal.
2. Keep the Firebase emulator window running.
3. Confirm port 5050 is free.
4. Launch `tool/launch_formal_flutter_client_release.ps1`.
5. Use only `http://127.0.0.1:5050`.
6. If an old Chrome tab survives, perform one hard refresh (`Ctrl+Shift+R`).
7. Repeat the exact interaction that froze debug mode.

## Decision boundary

- If release mode completes the same interaction normally, record the debug assertion as an environment/framework limitation and continue feature acceptance in release mode.
- If release mode also freezes or the feature behaves incorrectly, treat that as a real application/runtime defect and investigate the first application-level error or failed behavior. Do not infer root cause from the debug `MouseTracker` stack alone.

## Repair discipline

Do not rerun successful migrations or modify previously-green production source to address this assertion. Preserve green layers and change only the layer proven to be defective.
