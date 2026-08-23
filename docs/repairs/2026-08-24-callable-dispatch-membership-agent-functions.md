# Repair: callable Dispatch membership fixture + agent Functions verification

Date: 2026-08-24

## Release blocker

The controlled local production release reached the authenticated callable emulator integration after all prior Dart, Flutter, OAuth, manifest, Functions unit, and Firestore/Storage rules tests passed.

The integration failed when `submitDispatchQuote` returned `FAILED_PRECONDITION` because the test carrier had been approved and given a vehicle but the fixture never created the required `dispatch_memberships/{uid}` entitlement.

The same emulator run also reported that `firebase/agent-functions` could not load because its declared `firebase-functions` dependency had not been restored before starting the Functions emulator.

## Root cause

Two release-verification fixtures had drifted from the current production contract:

1. Dispatch bidding now correctly requires an owned active membership with a future `currentPeriodEnd`, but the positive callable integration scenario did not provision one.
2. `tool/verify.ps1` restored and validated `firebase/functions` but not the second configured Functions codebase, `firebase/agent-functions`.

## Repair

- Keep the production Dispatch membership gate unchanged.
- Seed a realistic active monthly membership for the approved integration carrier before the quote scenario.
- Restore, lint, check/test, and production-audit `firebase/agent-functions` during complete local release verification before emulator integration.

## Safety

This repair does not enable paid billing, weaken Dispatch access control, bypass App Check in production, alter Stripe configuration, or skip emulator tests.

The positive integration fixture now satisfies the same membership shape the server creates from a paid Dispatch invoice, while separate unit tests continue to verify that missing, inactive, expired, and wrong-owner memberships are rejected.

## Re-run expectation

A clean release run should now:

1. validate both Functions codebases,
2. load both codebases in the emulator,
3. allow the entitled integration carrier to submit a Dispatch quote,
4. continue through the remaining callable integration, web build, manifest, Firebase deploy, parity, and smoke checks.
