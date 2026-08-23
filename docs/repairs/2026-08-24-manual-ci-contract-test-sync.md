# Repair record — manual CI contract test synchronization

Date: 2026-08-24

## Trigger

The clean production release verification for `4254891eda55f7802c460db9ab059051f8274fe8` passed Dart analysis and then failed two Flutter tests in `test/product_identity_test.dart`.

The failing tests asserted that `.github/workflows/quality.yml` must contain an automatic macOS `ios-compile` job and the old pull-request/ref concurrency key.

## Root cause

Those assertions described the repository's previous high-cost CI architecture. On 2026-08-23, the project intentionally changed Quality to a manual Linux-first workflow to stop every development edit from launching Windows/macOS/mobile builds. The signed Android/iOS release workflow remains separate and manual in `.github/workflows/mobile-release-candidate.yml`.

The workflow was correct; the test contract had not been updated with the CI cost-control repair.

## Exact repair

Update `test/product_identity_test.dart` so it verifies the intended current architecture:

- Quality is explicitly manual through `workflow_dispatch`;
- Quality runs its normal verification on Ubuntu/Linux;
- Quality does not contain a macOS/iOS compile job;
- Quality uses the manual-ref concurrency key `quality-manual-${{ github.ref }}` and still cancels superseded runs;
- the separate manual mobile release-candidate workflow owns the signed Apple/iOS build on `macos-15`;
- existing pinned mobile package identity checks remain intact.

## Safety

Do not restore automatic macOS/iOS compilation merely to satisfy the stale test. That would reintroduce the GitHub Actions cost problem that was already root-caused and repaired.

No application behavior, Firebase provider state, Stripe state, payment activation, or deployment configuration is changed by this repair.

## Deployment status

The production deploy stopped during `flutter test`, before Flutter web build and before the Firebase deploy operation. Production was not modified by the failed attempt.
