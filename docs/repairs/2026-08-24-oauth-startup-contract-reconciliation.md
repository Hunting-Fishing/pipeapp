# Repair record: OAuth startup contract reconciliation

Date: 2026-08-24

## Trigger

The clean production release for tester deployment advanced through Dart analysis and all Flutter tests, then stopped in `tool/oauth_branding_test.mjs` on release SHA `f9459e89436c9abe678d3210c3ef26963b29a11a`.

The failing assertion required `web/index.html` to visibly identify the application with `<h1>Pipe Buyer</h1>` and, after that assertion, also required the pre-Flutter homepage to expose the application purpose plus Privacy and Terms links.

## Root cause

The formal service-truck/pumpjack startup redesign intentionally collapsed startup into one HTML surface. During that integration, the static OAuth/public identity block was removed from `web/index.html`.

At the same time, `test/startup_single_surface_test.dart` encoded the removal by explicitly forbidding `Application Purpose & Identity:` while `tool/oauth_branding_test.mjs` explicitly required that same phrase. The two release contracts were contradictory, so a fully green release was impossible without reconciling them.

## Repair

1. Preserve the single `#pipe-startup` surface, moving truck, pumpjack, progress bar, first-frame removal, and existing startup behavior.
2. Add a compact visible `<h1>Pipe Buyer</h1>` to that same startup surface.
3. Add a compact application identity statement containing the required B2B industrial marketplace, timed auctions, and freight trucking dispatch wording.
4. Add canonical Privacy and Terms links inside the same surface.
5. Update the single-surface Flutter test to require the identity/legal content while continuing to reject a second header/splash-card startup surface.
6. Update the OAuth verifier to accept the valid HTML-encoded ampersand (`&amp;`) as the same visible `Application Purpose & Identity:` phrase.

## What was not changed

- No second splash/loading surface was added.
- Truck/pumpjack animation and progress behavior were not removed.
- No OAuth branding requirement was disabled.
- No Firebase, Stripe, payment activation, App Check, or deployment settings changed.
- No GitHub Actions automatic runner triggers were restored.

## Verification target

The next clean production deployment must prove:

- Dart analysis green.
- Flutter test suite green, including `startup_single_surface_test.dart`.
- `tool/oauth_branding_test.mjs` green.
- Remaining repository verification green before any Firebase production deploy step executes.
