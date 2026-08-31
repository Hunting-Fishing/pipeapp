# Pipe App Codex Guide

This repository is the Pipe Buyer / Pipe App Flutter application backed by Firebase.

## Source control and release policy

- Work on a feature branch and open a pull request. Do not push task changes directly to `main` unless the owner explicitly requests it.
- Treat `.github/workflows/deploy.yml` as the controlled Firebase release path.
- Do not trigger, bypass, weaken, or replace production deployment gates unless the owner explicitly asks for that exact change.
- Never commit Firebase, Stripe, Google Cloud, GitHub, or other private credentials, service-account JSON, CI tokens, webhook secrets, or private keys.
- Production Firebase is `flutter-flow-pipe`. Staging is `pipebuyer-5c77f`. Never mix resources between these projects.

## Development environment

- Flutter version used by the verified release workflow: `3.44.6`.
- Node.js version used for Firebase Functions: `22`.
- Java version used by CI: `21`.
- Firebase CLI version used by the verified release workflow: `15.25.0`.
- Codex cloud setup should run `bash .codex/setup.sh` during environment setup while network access is available.

## Firebase safety model

- Local development is emulator-first. Do not connect routine Codex tasks directly to production Firebase.
- Root Firebase configuration is `firebase.json`.
- Firestore rules: `firebase/firestore.rules`.
- Firestore indexes: `firebase/firestore.indexes.json`.
- Storage rules: `firebase/storage.rules`.
- Marketplace Functions: `firebase/functions`.
- Administrative/agent Functions: `firebase/agent-functions`.
- Web Hosting output is `build/web`.
- Use explicit Firebase project IDs for any cloud operation; do not depend on a local `.firebaserc` alias.

## Verification commands

Before proposing a PR for application code, run the applicable checks:

```bash
flutter pub get
dart analyze lib test
flutter test
node --test tool/release_manifest_test.mjs
node --test tool/function_parity_test.mjs
npm run lint --prefix firebase/functions
npm run check --prefix firebase/functions
npm run lint --prefix firebase/agent-functions
npm run check --prefix firebase/agent-functions
```

For Firebase security-rule work, run the emulator-backed tests:

```bash
firebase emulators:exec \
  --project demo-pipe-buyer-rules \
  --config firebase.json \
  --only firestore,storage \
  "npm test --prefix firebase/rules-tests"
```

For callable workflow integration changes, use the local Emulator Suite rather than a live Firebase project.

## Web release build

The production workflow compiles Firebase configuration into the Flutter web build using `--dart-define` values supplied by protected GitHub Environments. Do not hard-code those values into source files.

A normal Codex task should build/test locally and submit a PR. After review, the existing GitHub Actions release workflow is responsible for deploying the exact accepted commit to Firebase.

## Payments and marketplace controls

This application contains marketplace payments, subscriptions, tax, fraud, messaging, and admin workflows. Changes affecting money movement, fees, Stripe Connect, tax calculations, identity/authorization, Firebase Security Rules, or admin privileges require tests and should preserve server-side enforcement. Never move privileged payment or authorization decisions into client-only Flutter code.
