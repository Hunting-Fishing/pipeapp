# Marketplace command client lazy Firebase initialization — 2026-08-30

## Scope

This repair closes the protected production Flutter-test failure that blocked the unified membership release at commit `bec9c62d48a059a3627388facf62baea32319bfe`.

The failed production workflow was run `33308967311`, job `99250440029`. The release stopped in `flutter test` before Firebase deployment. The suite reported 451 tests passed and 3 failed; all three failures were the same responsive membership-plan test at 390px, 768px, and 1440px.

No Stripe, Firebase production data, subscription, Connect, payout, promotion-code, or marketplace transaction behavior was changed by the failed release or by this repair.

## Root cause

The failures were not caused by artwork sizing.

`NativeMembershipPlanButton` is designed to fail closed on unsupported platforms. Its `_loadView()` checks the runtime platform and returns `supported: false` for web and non-iOS/non-Android targets before any native billing command should run.

However, constructing the widget state also constructed `MarketplaceCommandClient()`. The shared command client's constructor immediately resolved both `FirebaseFunctions.instance` and `FirebaseAuth.instance`. On the Linux Flutter test runner there is intentionally no default Firebase app, so widget construction threw:

`[core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()`

Expanded diagnostic run `33318476685`, job `99276136514`, proved the stack:

1. `FirebaseFunctions.instance`
2. `MarketplaceCommandClient()` constructor
3. `_NativeMembershipPlanButtonState`
4. `VipSubscriptionCheckoutButton` / `DispatchSubscriptionCheckoutButton`
5. `membership_plan_artwork_responsive_test.dart`

The test's final `tester.takeException()` assertion then received the accumulated Firebase exceptions at every tested viewport width.

## Repair

`MarketplaceCommandClient` now keeps optional injected Firebase dependencies without resolving defaults in its constructor.

The default `FirebaseAuth.instance` and `FirebaseFunctions.instance` objects are resolved lazily only when `execute()` is actually called.

This preserves all existing command behavior while making construction side-effect free. Platform-gated presentation can therefore render on unsupported targets without bootstrapping Firebase merely because a command client exists below the widget tree.

A regression test now requires `MarketplaceCommandClient()` construction to succeed without an initialized Firebase app.

## Validation

Repair code SHA validated: `9d74b969c5f42e37473d3679e78b159a992ffeb3`.

Isolated no-deploy validation workflow:

- run `33318724910`
- job `99276782818`
- Flutter `3.44.6`
- `dart analyze lib test` — passed
- command-client regression + responsive membership artwork + native subscription policy/contract tests — passed
- full `flutter test` suite — passed

The validation workflow checked out the exact repair SHA explicitly. It contained no Firebase deployment step and no production mutation.

## Do not repeat

- Do not resolve `Firebase*.instance` or other platform services in constructors for shared clients when the object may be created before runtime/platform gating.
- Do not repair presentation tests by initializing Firebase when the rendered unsupported-platform path should require no backend service at all.
- Keep native membership billing fail closed outside iOS/Android and until the existing store-readiness gates are satisfied.
- Do not weaken Stripe, subscription, promotion, Customer Portal, Connect, or marketplace payment policy to address UI lifecycle failures.
- Do not rerun a failed production workflow that is pinned to a known-broken SHA. Repair first, validate the exact repair SHA, then start a new protected release from the repaired commit.
- Run the full Flutter suite before promoting membership/UI refactors to production; selective PR checks are not sufficient evidence for this surface.
