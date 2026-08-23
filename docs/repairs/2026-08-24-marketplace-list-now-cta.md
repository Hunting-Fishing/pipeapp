# Marketplace List Now CTA visibility — 2026-08-24

## Problem

Signed-in Marketplace users could create listings through the existing List destination and through the empty-state CTA, but once Marketplace inventory existed there was no prominent `List Now` action in the normal Browse surface. This made the primary seller action unnecessarily hard to discover.

## Root cause

The Browse page already had an `onList` path to the existing listing workflow, and the adaptive shell already mapped page index `2` to the List destination. The populated Marketplace surface simply did not expose that action prominently.

## Repair

- Added a `List Now` primary action to `MarketplaceAdaptiveShell` only while `selectedPageIndex == 1` (Marketplace/Browse).
- The CTA routes through the existing destination callback with page index `2`; no duplicate listing workflow or direct navigation logic was introduced.
- Expanded/tablet layouts place the CTA at the top-right of the constrained Marketplace content so it sits beside the Marketplace heading area.
- Compact layouts place the CTA in a small action row above the page body so it does not cover the heading or search controls.
- The control uses a 48 px minimum tap height and the existing Pipe Buyer orange primary-action styling.

## Regression coverage

`test/marketplace_adaptive_shell_test.dart` now verifies that:

1. `List Now` is visible on Marketplace/Browse.
2. Pressing it routes to page index `2`.
3. It is absent from non-Marketplace pages.
4. It remains visible on compact layouts without replacing the Marketplace body.

## Scope

UI/navigation only. No Firebase rules, Functions, Stripe configuration, billing activation, listing persistence, payment behavior, or production deployment logic is changed.
