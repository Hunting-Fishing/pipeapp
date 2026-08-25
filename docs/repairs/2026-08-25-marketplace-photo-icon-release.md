# Marketplace photographic icon release — 2026-08-25

## Release intent

Refresh the Marketplace catalog artwork with the approved Pipe Buyer gold/navy photographic icon set while preserving the current production taxonomy, payment configuration, Firebase data model, Dispatch billing, and CI cost controls.

## Base

- Base main SHA: `55add568ba5280322b5abbacbf43dc81251bee53`
- Release branch: `feat/marketplace-photo-icons-final-20260825`

## Asset handling

- Temporary ChatGPT/upload filenames are not used as production asset names.
- Artwork is normalized against the existing semantic industrial asset paths already referenced by `IndustrialIconAssets`.
- SVG-backed catalog assets use compact SVG wrappers with an embedded optimized 128x128 JPEG rendition of the approved artwork.
- Existing PNG-backed Heavy Equipment slots receive optimized PNG renditions at their existing semantic paths.
- This keeps the existing Flutter asset manifest stable and prevents selector-only artwork work from changing Firebase, Stripe, or listing records.

## Scope

- 61 approved artwork replacements total.
- 56 SVG-backed photographic replacements.
- 5 PNG-backed Heavy Equipment replacements.
- No Firebase schema/rules/index changes.
- No Stripe or Dispatch billing changes.
- No package/dependency upgrades.
- No automatic GitHub Actions workflows restored.

## Verification

Before production deployment:

1. Run `flutter pub get`.
2. Run `dart analyze lib test`.
3. Run `flutter test test/industrial_icon_assets_test.dart`.
4. Run `powershell -ExecutionPolicy Bypass -File .\tool\verify.ps1`.
5. Inspect Marketplace category/product selectors at compact mobile and desktop widths.
6. Confirm no missing-asset/fallback errors.

Production must use the controlled local deployment helper from a clean `main` checkout. Do not substitute hosting-only deployment.

## Rollback

Revert the Marketplace photo-icon release commit. No data migration or provider rollback is required.
