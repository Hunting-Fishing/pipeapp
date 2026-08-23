# Repair record — P2 Dispatch billing UI composition refactor

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

## Root cause

As P2 gained real production controls, several Flutter files accumulated both asynchronous billing orchestration and substantial presentation logic.

The highest-change files reached roughly 500–650 lines and repeatedly needed whole-file GitHub replacement because the connected repository write API does not support small in-place patches.

That created a concrete repair risk:

- a visual copy/layout change could accidentally alter Checkout or Billing Portal orchestration;
- a readiness UI change could accidentally alter audited callable actions;
- long whole-file replacements made unrelated regressions harder to spot;
- repeated edits to the same mixed-responsibility file increased the chance of stale-copy restoration.

This was not a reason to split every long file. The repair was limited to UI surfaces where state mutation and pure presentation were changing frequently together.

## Exact repair

### Customer Dispatch membership surface

Created:

`lib/marketplace/marketplace_dispatch_subscription_components.dart`

It owns pure presentation for:

- current membership state;
- Monthly/Yearly plan cards;
- billing-management unavailable state;
- inline errors / load failure;
- plan benefits and customer status presentation.

`lib/marketplace/marketplace_dispatch_subscription_panel.dart` now owns only:

- authenticated server-status loading through the client;
- latest-request generation ordering;
- app-resume refresh;
- Stripe Checkout launch;
- Stripe Billing Portal launch;
- working/error state;
- responsive composition of the extracted widgets.

The stateful panel no longer contains its own private plan-card/status presentation classes.

### Dispatch Launch Readiness surface

Created:

`lib/marketplace/marketplace_dispatch_subscription_readiness_view.dart`

It owns pure presentation for:

- provider-bound Portal readiness display;
- six-prerequisite progress;
- readiness gate rows;
- BILLING ON / BILLING OFF status;
- recommended-next-action ordering;
- result/error presentation;
- provider/recovery action buttons.

`lib/marketplace/marketplace_dispatch_subscription_launch_readiness_panel.dart` now owns only:

- loading payment/Portal readiness through audited callables;
- provider-backed lifecycle webhook verification;
- audited Smart Retry/email recovery assertion/revocation;
- working/error/result state;
- composition of the extracted readiness view.

### Overlapping customer refreshes hardened

Returning from external Stripe Checkout/Portal and manual refresh can create overlapping status requests.

The customer stateful panel now uses a monotonically increasing `_loadGeneration`. Only the newest request is allowed to update status/error/loading state. A slower older response can no longer overwrite a newer server-authoritative refresh in the UI.

This does not change financial authority; it only prevents stale presentation.

## Intentionally not refactored

The following files were reviewed but not split merely because of line count:

- `firebase/functions/dispatch_subscription_state.js`;
- `firebase/functions/dispatch_subscription_reconciliation_commands.js`;
- `lib/marketplace/marketplace_dispatch_billing_portal_control.dart`;
- `lib/marketplace/marketplace_dispatch_subscription_admin_panel.dart`.

Their responsibilities remain reasonably cohesive. Splitting them without a concrete repeated-change or policy-drift problem would add indirection without reducing financial risk.

The Billing Portal control remains one bounded stateful workflow: load provider proof → verify exact live configuration → display evidence → revoke/disable. It should only be split later if independent responsibilities actually emerge.

## Verification contracts

Flutter source contracts now require:

- customer stateful panel imports the extracted components file;
- customer stateful panel no longer defines `_DispatchPlanCard` or `_CurrentDispatchMembership`;
- plan-card billing-availability/tax presentation lives in the component file;
- readiness controller imports and delegates to `MarketplaceDispatchSubscriptionReadinessView`;
- readiness controller no longer owns progress/gate-row/status-pill presentation;
- extracted UI + orchestration contain no direct authoritative Firestore financial writes;
- customer app-resume refresh and server-callable boundaries remain intact.

A source-review pass also caught and repaired a contract-test string that accidentally interpolated `_operationsRevision` inside the test itself. The expected-source string is now a raw literal.

Full Flutter analyzer/tests/rendered acceptance remain required from the complete toolchain.

## Do not repeat

- Do not put plan-card visual changes back into the stateful Checkout/Portal orchestration file.
- Do not put readiness progress/layout changes back into the audited callable controller.
- Do not split backend financial/lifecycle files merely to satisfy a line-count target; require a concrete responsibility or repair boundary.
- Do not use refactoring as an excuse to change financial behavior and presentation behavior in the same commit without explicit tests.
- Do not allow an older async status request to overwrite a newer refresh after returning from Stripe.
- When whole-file replacement is unavoidable, review the resulting diff for unrelated changes before continuing.
