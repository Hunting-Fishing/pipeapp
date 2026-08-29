# Callable payment completion gate repair — 2026-08-29

## Production release blocker

The verified production deployment for main commit `a1cb5bcbd154aaf88fe6ac3829024e87a051a195` stopped at the authenticated callable integration step before web build or Hosting deployment.

## Root cause

Marketplace payment hardening merged in PR #131 intentionally changed both Marketplace and Timed Buying settlement commands so `confirm_completion` is rejected until the authoritative payment state is either `paid` or `external_agreed`.

The authenticated emulator integration fixture still reflected the older behavior: immediately after accepting an offer or finalizing an auction it called the completion command and expected success while no payment state existed. The release test therefore contradicted the new security requirement.

This is a test-fixture regression, not a reason to weaken the production payment gate.

## Repair

The integration test now verifies both sides of the invariant:

1. Completion before payment must return `FAILED_PRECONDITION`.
2. The emulator fixture then marks the authoritative Marketplace payment transaction as `external_agreed` to represent a confirmed non-Stripe settlement in the isolated emulator.
3. Completion is retried and must succeed idempotently.
4. The same sequence is required for the mirrored Timed Buying transaction `auction_<listingId>`.

The production callable policy remains unchanged.

## Launch rule retained

Production buyer-to-seller Checkout must still create a paid authoritative transaction before either participant can confirm completion. Seller proceeds remain pending until both participants complete the transaction and the delayed seller-release lifecycle succeeds.

Validation is executed on the isolated repair branch before this change can return to `main`.
