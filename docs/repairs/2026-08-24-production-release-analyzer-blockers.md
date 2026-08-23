# Repair record — production release analyzer blockers

Date: 2026-08-24
Original release SHA: `fa61ffad78abc916f71d8fe2d857eea0ab4a949f`
Repair branch: `fix/release-analyzer-blockers-20260824`

## Context

The client requested the latest coherent Pipe Buyer tester build be promoted for broad web/mobile bug finding. The canonical formal + Dispatch GREEN tester stack was merged into `main` at `fa61ffad78abc916f71d8fe2d857eea0ab4a949f`.

Production deployment was attempted from a separate clean checkout using `tool/deploy_production_local.ps1`. The script synchronized exact `main`, validated production configuration and Firebase project `flutter-flow-pipe`, then ran the complete local release verification.

The verifier stopped during `dart analyze lib test` before the production web build or any Firebase deployment command ran.

## Root cause

Dart 3.47.1 reported exactly two analyzer findings:

1. `lib/marketplace/profile_photo_uploader_io.dart:29:5` — `unawaited_return_in_try_block`.
   - The upload method returned `reference.getDownloadURL()` directly from inside a `try` that also has a `finally` block.
   - Returning the Future without awaiting it permits the `finally` block to run before that Future completes.

2. `lib/core/design/pipe_buyer_design.dart:1:1` — `dangling_library_doc_comments`.
   - The design barrel began with `///` library-style documentation but had no library directive for the documentation to attach to.

The release script correctly treated the analyzer exit code as a hard stop.

## Exact repair

### Profile photo uploader

Changed:

```dart
return reference.getDownloadURL();
```

to:

```dart
return await reference.getDownloadURL();
```

This preserves the existing return value while ensuring the Future completes inside the `try` before `finally` cancels the snapshot subscription.

### Design barrel

Converted the introductory `///` documentation comments to ordinary `//` source comments. No exports or runtime behavior changed.

## Safety / release impact

- No analyzer rule was suppressed.
- No dependency was upgraded.
- No Firebase configuration was changed.
- No Stripe/payment activation state was changed.
- No application feature behavior was redesigned.
- The failed release attempt did not reach `flutter build web` or `firebase deploy`; therefore it published nothing.

## Verification procedure

After this repair is merged to `main`, use the existing clean production checkout and run:

```powershell
git pull --ff-only origin main
git status
git rev-parse HEAD
powershell -ExecutionPolicy Bypass -File ".\tool\deploy_production_local.ps1"
```

The deployment remains gated by the complete local verifier. If another real source defect is discovered, stop and repair that root cause rather than bypassing verification.

## Do not repeat

- Do not disable analyzer warnings to make a production deployment pass.
- Do not edit the production checkout manually; repair source through Git and fast-forward the clean release checkout.
- Do not switch/reset/clean the active dirty Beautification workspace for deployment purposes.
