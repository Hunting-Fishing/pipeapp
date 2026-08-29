# Firebase Production App Check Pointer Contract Repair — 2026-08-29

## Incident

Production release pointer `release/firebase-production` was moved to verified commit `d9edbf7d33d354f69018aa5d455705967efe58fb`, which dispatched GitHub Actions run `33253986768` (`Deploy verified Firebase release`).

The run passed application analysis, Flutter tests, release-control tests, Firebase Functions validation, Firestore/Storage rules tests, authenticated callable integration tests, and the production web build. It then stopped at `Record exact release manifest`, before Firebase deployment credentials were used and before any production publish occurred.

## Root cause

`.github/workflows/firebase-release-pointer.yml` dispatched production with:

- `environment=production`
- `app_check_mode=disabled`

The verified manifest generator `tool/release_manifest.mjs` intentionally fails closed for production unless `app_check_mode=enforce`.

Therefore the release pointer and the production release manifest had contradictory contracts. The manifest was correct; the pointer was stale.

## Repair

Changed only the production release pointer behavior:

- staging continues to dispatch `app_check_mode=disabled`
- production now dispatches `app_check_mode=enforce`

Updated `docs/FIREBASE_RELEASE_POINTERS.md` to make the production App Check invariant explicit.

## Why the manifest was not weakened

Production App Check enforcement is a launch security control. Allowing `disabled` or `observe` in the manifest would turn a safe fail-closed control into a bypass. The repair therefore aligns the caller with the existing production invariant instead of reducing the invariant.

## Verification procedure

1. Merge this repair to `main`.
2. Move `release/firebase-production` to the resulting exact `main` SHA.
3. Confirm the pointer dispatches `deploy.yml` with `environment=production` and `app_check_mode=enforce`.
4. Confirm protected production environment validation succeeds, including `PIPE_APP_CHECK_WEB_RECAPTCHA_KEY` availability.
5. Require all analysis, tests, Functions checks, security-rule tests, callable integration tests, web build, and release-manifest generation to pass.
6. Only after those gates pass may Firebase deployment execute.
7. Require deployed Function parity and visual acceptance to pass before treating the release as verified.

## Reuse rule

If a future production release fails at manifest generation with an App Check mode error, do not modify Stripe, Firebase Functions, payment code, or the manifest policy first. Check the release-dispatch input. Production must arrive at `deploy.yml` with `app_check_mode=enforce`.
