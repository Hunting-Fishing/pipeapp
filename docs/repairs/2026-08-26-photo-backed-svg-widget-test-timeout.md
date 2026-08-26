# Photo-backed SVG widget-test timeout repair — 2026-08-26

## Release context

- Blocked production candidate: `0f7539e0813c0b63771d1f34388ed8d62b74044b`
- Release: Marketplace photographic icon update
- Production deploy helper stopped inside `tool/verify.ps1` during `flutter test`.
- The failure occurred before the Firebase deploy command, so this attempt did not publish the icon release.

## Observed failure

`dart analyze lib test` completed with `No issues found!`, then three tests in `test/industrial_icon_assets_test.dart` failed with `pumpAndSettle timed out`:

1. `fleet type dropdown fits a narrow mobile viewport`
2. `representative industrial SVGs render through Flutter`
3. `all 59 expansion SVGs render through Flutter`

The rest of the suite continued, including the 132 Phase 2 SVG render coverage.

## Root cause

The approved photographic release keeps existing semantic `.svg` asset paths stable, but some replaced files are SVG wrappers containing an embedded optimized JPEG through a `data:image/jpeg;base64,...` `<image>` element.

`IndustrialAssetIcon` intentionally displays an animated `CircularProgressIndicator` while `SvgPicture.asset` is loading. Flutter widget tests run with a fake clock. `pumpAndSettle()` rapidly advances that fake clock while the raster decoder still needs real asynchronous wall-clock time. Because the loading spinner keeps scheduling frames, `pumpAndSettle()` can reach its virtual timeout before the embedded raster decode completes.

This was a test-harness timing mismatch introduced by the new asset representation. It was not an analyzer failure, missing asset, Firebase failure, or evidence that the production icon resolver was broken.

## Repair

`test/industrial_icon_assets_test.dart` now uses `_waitForIndustrialArtwork()` for icon-rendering tests. The helper:

- pumps the widget tree,
- grants the engine bounded real wall-clock time in 50 ms increments for embedded raster decoding,
- pumps each completed frame,
- returns as soon as all industrial loading indicators are gone,
- fails after 2 seconds of wall-clock decoder time if artwork still has not completed.

The dropdown test also advances the Material dropdown route animation explicitly before waiting for its artwork.

## Scope safeguards

- No production widget behavior changed.
- No icon artwork changed.
- No resolver path changed.
- No Firebase, Firestore, Storage, Functions, Stripe, Dispatch billing, or catalog data changed.
- No dependency upgrade or analyzer suppression was introduced.
- No automatic GitHub Actions workflow was enabled.

## Verification required before production

From a clean production checkout on the repaired `main` SHA:

1. Run `flutter test test/industrial_icon_assets_test.dart`.
2. Run `powershell -ExecutionPolicy Bypass -File .\tool\verify.ps1`.
3. Only if the full verifier is green, run `powershell -ExecutionPolicy Bypass -File .\tool\deploy_production_local.ps1`.
4. Confirm Firebase function parity and the production HTTP checks printed by the controlled deploy helper.
5. Inspect Marketplace icon selectors at narrow mobile and desktop widths after deployment.

## Do not repeat

Do not remove the production loading indicator solely to make widget tests settle. Do not replace the release gate with an unconditional fixed fake-time pump. For photo-backed SVGs, provide bounded wall-clock decoder time and still assert that loading completes.
