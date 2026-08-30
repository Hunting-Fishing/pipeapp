# Marketplace home background hero repair

## Problem

The Marketplace home introduction was visually behaving like a small dark hero card. The oilfield campaign photography could not read as the page background, and the right-side identity card consumed too much of the available image area on desktop and mobile.

## Root cause

`MarketplaceHomeWelcome` used the generic `PipeBuyerHeroPanel` with a 320–350 px minimum height, no photography assigned, and a large trailing identity panel. The presentation therefore read as a fixed banner even though the surrounding Marketplace home already scrolls normally.

## Repair

- Use separate desktop and mobile oilfield background assets.
- Select the portrait image below the responsive breakpoint rather than cropping the desktop image into a phone layout.
- Keep the image in a `Positioned.fill` layer inside the hero `Stack`.
- Keep the foreground content as the sizing child of the `Stack`, using **minimum height only**. Do not introduce a fixed hero height.
- Keep the Pipe Buyer logo, copy, account state, and trust features as independent Flutter widgets over the photo.
- Remove the former right-side identity card so the campaign image remains visible.
- Keep the hero inside the existing Marketplace scrolling content. The background scrolls with the section; it is not viewport-fixed or parallax.
- Centralize the image paths and responsive sizing contract in `marketplace_home_hero_assets.dart` so campaign photography can be swapped without rebuilding the layout structure.
- Store the active campaign images as standard JPEG assets for deterministic Flutter desktop/test decoding. The image file can be replaced later without changing the widget architecture.
- Keep the top-left brand row width-aware. The logo has a fixed footprint, while the Pipe Buyer wordmark/tagline uses the remaining width so narrow mobile layouts cannot overflow horizontally.

## Final campaign photography packaging

The approved final photography is the Pipe Buyer truck photo with the realistic pipe load, Pipe Buyer truck branding, PPE crew, oilfield lease/pumpjacks and sunset. A separate portrait crop is used for mobile.

The connected GitHub writer could not safely replace a binary JPEG in one contents write. To avoid substituting the old photo or repeatedly corrupting the binary, the two approved baseline JPEGs are stored losslessly as ordered base64 payload chunks under `assets/images/marketplace_home_hero_{desktop|mobile}.b64.*`. `tool/materialize_marketplace_home_hero.sh` concatenates and decodes those chunks into the normal JPEG paths before Flutter validation and before the staging web build. It also verifies JPEG SOI/EOI bytes and fails closed if a chunk is missing, misordered, or truncated.

This is a packaging repair only. Flutter still reads the normal `.jpg` paths and the visual/layout architecture is unchanged. When a direct binary GitHub write path is available, the chunk transport may be replaced by equivalent committed JPEGs only after the same responsive render evidence proves the approved artwork is preserved.

## Validation repair

The first staging browser smoke test was a false positive for this specific visual change. The deployed root route is authentication-gated, so an unauthenticated headless browser correctly rendered the sign-in screen instead of `MarketplaceHomeWelcome`. That test proved that Firebase Hosting and the Flutter app shell loaded, but it did **not** prove that the new Marketplace hero pixels rendered correctly.

The durable validation is now split into two independent gates:

- `MarketplaceHomeDiscoveryHero` is a Firebase-free presentation widget. Widget tests render it directly at `1440x1000` and `390x844`, assert that the correct desktop/mobile campaign asset is selected, check critical overlay copy, and retain PNG render evidence.
- The deployed staging browser smoke remains an authentication-gated **hosting/app-shell** check only. Its screenshots must not be used as evidence that the Marketplace hero itself passed visual acceptance.

This separation avoids weakening or bypassing the application's authentication gate merely to inspect a design component.

## Validation failures and permanent fixes

Two failures from the dedicated responsive test were useful and are recorded here so the same repair cycle is not repeated:

1. The original generated WebP campaign file produced `Codec failed to produce an image` on the Linux Flutter test runner. The campaign assets were re-encoded as JPEG and the centralized asset paths and CI path filters were updated to the JPEG files. Do not revert to the failed WebP files unless a replacement is independently verified by the same Flutter test runner.
2. The 390 px mobile render exposed a 1.4 px `RenderFlex` overflow in the brand row. The fixed-width logo remains unchanged, but the wordmark/tagline column now expands only into the remaining row width and can wrap/ellipsis safely. Do not restore `mainAxisSize: MainAxisSize.min` with an unconstrained text column in this brand row.

## Regression rule

Do not convert this hero back to a fixed-height image/banner or a viewport-fixed background. The page owns scrolling; the photo is scenery; the Pipe Buyer UI remains an independent overlay layer. Desktop and mobile photography must remain independently selectable.

Do not treat an unauthenticated screenshot of the app root as Marketplace-hero visual evidence. Validate the hero through the dedicated responsive widget render tests, and use the deployed root smoke only for hosting/app-shell health.

Do not bypass `tool/materialize_marketplace_home_hero.sh` while the chunk packaging is in use. A build that skips materialization can silently fall back to an older checked-in JPEG and therefore is not valid evidence for this campaign.
