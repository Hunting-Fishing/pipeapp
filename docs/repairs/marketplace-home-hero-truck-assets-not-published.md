# Marketplace home hero truck assets were not published

## Symptom

The Marketplace home hero deployed successfully and the overlay became lighter, but production still showed a bland grey/old background instead of the approved truck photography. Mobile likewise did not show the intended portrait truck hero.

## Root cause

Commit `4c40dea7610b01009223a01f7c6826fab1e14155` changed the hero presentation code and removed obsolete base64 payload chunks, but it did **not** replace the tracked binary files:

- `assets/images/marketplace_home_hero_desktop.jpg`
- `assets/images/marketplace_home_hero_mobile.jpg`

The widget already referenced those two tracked JPEG paths, so production correctly rendered the files that existed in the repository — they were simply the old artwork.

A second release-process gap was also present: `.github/workflows/publish-marketplace-home-hero.yml` did not include the two JPEG paths in its `pull_request.paths` or `push.paths` filters. A future image-only update therefore would not automatically run the protected hero release workflow.

## Repair

1. Replace the two tracked JPEG files with the approved truck hero payloads.
2. Add both JPEG paths to the hero workflow path filters.
3. Add SHA-256 validation for the approved payloads before Flutter validation and before production deployment.
4. Continue to use Flutter `3.44.6` for validation and production builds; do not alter `intl` merely to satisfy a newer local Flutter SDK.

Approved payloads:

- Desktop: 1600x900 JPEG, SHA-256 `88e37978e9617db1cce7d94693353b44a4474c6f496b98160be03ae24d622ef1`
- Mobile: 900x1600 JPEG, SHA-256 `49d8091744a1f57f79ad04bfb2caee96a2d4340ab9da06340d26883647785c40`

## Permanent rule

A visual-asset release is not complete unless the actual binary asset blob changed in Git history and the protected release workflow watches that asset path. Code that references an asset is not evidence that the intended artwork was published.

For this hero, image-only changes must trigger the same Flutter analysis, full Flutter test suite, production web build, guarded Firebase Hosting deploy, and production smoke checks as code changes.
