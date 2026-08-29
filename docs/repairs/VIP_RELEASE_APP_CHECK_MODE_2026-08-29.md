# VIP production release App Check repair — 2026-08-29

## Symptom

Production release run `33245480074` for runtime source `a2ab6ca51eb1eb56e1f167cfd9ca702658a999d0` passed analysis, Flutter tests, Firebase Functions validation, Firestore rules tests, authenticated callable integration, and the web build, then failed at `Record exact release manifest`. Firebase deployment did not run.

## Root cause

The VIP release dispatcher `.github/workflows/release-vip-monthly-live-20260829.yml` launched `deploy.yml` with `app_check_mode=observe`.

The production release manifest policy in `tool/release_manifest.mjs` intentionally requires `app_check_mode=enforce` for production. The launcher input therefore contradicted the production manifest security policy.

## Repair

Keep the production manifest policy unchanged. Change only the VIP release dispatcher input from `app_check_mode=observe` to `app_check_mode=enforce`.

This is a release-control repair; it does not change the verified VIP runtime source SHA.

## Validation required

The repaired dispatcher must launch the standard `Deploy verified Firebase release` workflow for the exact runtime source SHA above. The release is accepted only if manifest generation, Firebase deployment, deployed Function parity, and production visual acceptance all complete successfully.

## Do not repeat

Do not launch a production release with App Check `disabled` or `observe`. Production release dispatchers must use `enforce`; staging/non-production rollout modes are separate concerns.
