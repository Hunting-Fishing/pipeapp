# P2 Dispatch feature-flag default parity repair

Date: 2026-08-23
Scope: Flutter/Functions Phase-1 feature control parity for paid Dispatch production readiness.

## Root cause

The server Phase-1 feature normalizer failed closed when `platform_configuration/phase1_features` was missing: `dispatch`, `paidFeatures`, and `auctions` all defaulted to false.

The Flutter client had different missing-document defaults: `dispatch` and `auctions` defaulted to true. After adding explicit production build approval for Dispatch, a production artifact could therefore expose Dispatch UI when the remote feature document was absent even though Functions would reject Dispatch commands. Paid Features still defaulted false, so this did not authorize a payment, but it created an inconsistent and confusing control-plane state.

A related production-build defect had already been repaired: paid features were previously hard-disabled in production even when explicitly requested, and the release pipeline did not record Dispatch/Paid build approvals.

## Repair

1. Flutter `Phase1FeatureFlags.safeDefaults` now matches the Functions safe defaults for controlled features:
   - `auctions: false`
   - `dispatch: false`
   - `paidFeatures: false`
   - `regulatedListings: false`
2. Marketplace/Wanted/Offers retain their reviewed existing defaults.
3. Production Dispatch and Paid Features remain separate compile-time approvals, both defaulting OFF.
4. Remote `dispatch` and `paidFeatures` remain independent runtime kill switches.
5. Dispatch subscription activation additionally requires the centralized financial readiness policy.
6. Flutter regression tests now prove:
   - missing remote configuration fails closed;
   - a locked production artifact cannot be overridden remotely;
   - an approved production artifact still requires remote enablement;
   - missing remote configuration remains OFF even in an approved artifact.

## Required production invariant

For P2 Dispatch purchasing to be available, all of the following must agree:

1. exact release artifact compiled with Dispatch approval;
2. exact release artifact compiled with Paid Features approval;
3. remote `dispatch == true`;
4. remote `paidFeatures == true`;
5. centralized Dispatch launch-readiness prerequisites pass;
6. audited `stripeSubscriptionsEnabled == true`;
7. Checkout performs its immediate provider/tax runtime checks.

Missing or stale remote feature configuration must never be interpreted as permission to expose a controlled feature.

## Verification

Repository contracts were updated in `test/phase1_feature_flags_test.dart` to reflect the fail-closed defaults and two-key production model.

Full Flutter analyzer/test execution remains part of the exact-branch repository gate and must not be represented as passed until it runs in a complete Flutter/Firebase environment.

## Do not repeat

- Do not give Flutter more permissive missing-document defaults than Functions for a controlled feature.
- Do not use compile-time approval as a substitute for the remote kill switch.
- Do not use a remote feature flag as a substitute for financial readiness.
- Do not infer a paid Dispatch production artifact from workflow intent; verify the release manifest records both build approvals for the exact accepted SHA.
