# Engineering Control Baseline

Date: July 19, 2026

## Current controlled entry point

The production Flutter entry point routes to
`lib/marketplace/oil_gas_marketplace.dart`. The retired FlutterFlow vehicle
marketplace pages have been detached from `lib/flutter_flow/nav/nav.dart`.

The retired files remain recoverable in:

`/.codex-backups/legacy_generated_ui_2026-07-19/`

They are excluded from source control so they cannot be imported back into the
production build accidentally. The archive manifest contains restoration
instructions.

## Flutter SDK

- Supported SDK for this baseline: Flutter 3.44.6 stable
- Dart: 3.12.2
- Windows SDK location used during verification: `C:\src\flutter-sdk`
- Workspace VS Code setting: `.vscode/settings.json`

The workspace setting must point to the Flutter SDK root, not to its `bin`
directory and not to FlutterFlow's embedded SDK.

## Verification

From the workspace root:

```powershell
.\tool\verify.ps1
```

The verification gate restores dependencies, analyzes `lib` and `test`, runs
Flutter tests, checks the Firebase Functions policy module, tests Firestore
rules when Java and the Firebase CLI are installed, and builds the web release.
CI installs those emulator prerequisites and always enforces the rules tests.

## Source control

The local workspace is initialized as a Git repository. A private remote,
protected `main` branch, required pull-request checks, and reviewer ownership
must be configured before production work is shared.

Generated build output, logs, local Firebase selection, Functions
`node_modules`, secrets, and recovery archives are ignored.

## Deployment boundary

`firebase/firebase.json` serves the tested `build/web` output directly. The
legacy copied `firebase/public` folder is no longer the Hosting source of
truth.

No `.firebaserc` is committed. Copy `firebase/.firebaserc.example` to
`.firebaserc` locally and replace all placeholders only after separate
development, staging, and production Firebase projects are confirmed.

Production deployment is intentionally not performed by verification. A
deployment must name the project explicitly and use an already verified build.

## Property and rights safety state

- Canada, the United States, and Mexico have design-only baseline policies.
- Country policies never fall back to province/state policies.
- Public property publishing, property offers, rights, regulated energy
  assets, business sales, and client-funds handling remain disabled.
- Future Firestore control-plane collections deny normal client access.
- A valid subdivision licence, compliance owner, approved form set, legal
  review, effective period, and enabled feature are all required before a
  feature decision can succeed.
