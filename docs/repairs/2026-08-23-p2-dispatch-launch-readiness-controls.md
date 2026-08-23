# Repair record — P2 Dispatch launch-readiness controls

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

## Why this repair was needed

The Dispatch subscription payment/lifecycle code was hardened, but production activation still had four concrete control-plane gaps.

### 1. Subscription recovery and lifecycle-webhook readiness were checklist items, not enforced prerequisites

`stripeSubscriptionsEnabled` could be enabled from the payment-readiness control plane without separately proving that Stripe failed-payment recovery settings had been reviewed or that the subscription-specific lifecycle webhook events were actually subscribed.

That meant application code could be correct while the provider configuration required to operate it safely was incomplete.

### 2. Lifecycle webhook readiness could have been asserted manually

A boolean alone is not provider evidence. The app must not accept an administrator's statement that the live Stripe endpoint receives the required events when Stripe itself can be queried for that fact.

### 3. Legacy activation workflows bypassed the audited readiness validator

Three older GitHub workflows created a temporary activation function and directly replaced the Firestore payment-readiness document. They could set `stripeSubscriptionsEnabled: true` without passing the current server-side readiness policy.

Leaving those workflows active would create two competing activation authorities and could reintroduce a readiness state that the current validator would reject.

### 4. Dispatch subscriptions could be opened before customer billing-management/cancellation readiness existed

The Billing Portal was implemented and pinned to an exact `bpc_...` configuration, but it was not yet a hard prerequisite for opening new Dispatch Checkouts. A production subscription should not be sold before the reviewed customer management/cancellation path exists.

A related Portal risk was also identified: the current subscription lifecycle stores the Pipe Buyer plan from Dispatch subscription metadata. It does not yet derive the authoritative Monthly/Yearly plan from the live Stripe Price ID on every subscription update. Allowing a customer to switch prices inside Billing Portal could therefore create provider/app plan drift.

### 5. The protected Dispatch Billing page existed but was not discoverable from the real account menu

The dedicated `/admin/dispatch-billing` route and page existed, but the main marketplace account shell still routed administrators into the older broad Admin Portal. Adding the shortcut only inside another secondary admin composition would not make the financial workspace reliably discoverable.

The repair therefore had to use the actual account popup menu while preserving admin/MFA protection and avoiding a large edit to `marketplace_account_hub.dart` or `marketplace_admin_dashboard.dart`.

## Exact repair

### Explicit subscription readiness gates

`firebase/functions/payment_readiness_admin.js` now tracks:

- `stripeSubscriptionRecoveryVerified`;
- `stripeSubscriptionLifecycleWebhookVerified`.

Live Dispatch subscriptions require all of:

- production Stripe mode;
- core signed webhook readiness;
- provider-verified subscription lifecycle webhook readiness;
- reviewed subscription recovery settings;
- reconciliation readiness;
- an authorized GST/HST billing state;
- an enabled reviewed Dispatch Billing Portal configuration.

`firebase/functions/dispatch_subscription_commands.js` independently re-checks the same runtime prerequisites before creating or reusing a new Dispatch Checkout. A corrupted/stale Firestore control record therefore cannot bypass the Checkout runtime gate.

### Provider-authored lifecycle event verification

Added:

`firebase/functions/dispatch_subscription_launch_readiness_commands.js`

Callable:

`verifyDispatchSubscriptionLifecycleWebhook`

The MFA-admin callable uses the Stripe production secret and re-reads `/v1/webhook_endpoints?limit=100`. It requires the exact Pipe Buyer production endpoint to be enabled in live mode and verifies:

- `invoice.paid`;
- `invoice.payment_failed`;
- `customer.subscription.updated`;
- `customer.subscription.deleted`.

The provider assessment, endpoint ID, missing-event list, revision, administrator identity, and audit record are written server-side.

`setPaymentProviderReadiness` cannot manually set `stripeSubscriptionLifecycleWebhookVerified` to `true`. Administrators may set it to `false` immediately to revoke readiness.

### Subscription recovery verification

Stripe's available API surface in this environment does not expose the live Dashboard's Smart Retry/customer-email recovery configuration. That evidence cannot be fabricated from application code.

The dedicated Dispatch Billing Operations page therefore provides an explicit MFA-admin confirmation only after the operator reviews the live Stripe Dashboard settings. The confirmation records `stripeSubscriptionRecoveryVerified` through the audited readiness callable with a reason. It can be revoked immediately.

The reviewed provider settings include:

- intended Smart Retry/retry window;
- failed-payment customer emails;
- customer payment-method update path;
- terminal state after exhausted retries.

### Billing Portal is a hard prerequisite

Before `stripeSubscriptionsEnabled` may become true, the server now requires `platform_configuration/dispatch_billing_portal` to contain:

- `enabled: true`;
- a valid reviewed `bpc_...` Stripe configuration ID;
- a reviewed Pipe Buyer HTTPS return URL.

The Checkout runtime also re-reads this Portal record and refuses new Dispatch Checkout when Portal readiness is missing or disabled.

For first production release, the reviewed Stripe Billing Portal configuration must:

- allow payment-method updates;
- allow invoice/billing-history access;
- allow cancellation according to the approved paid-through-period policy;
- **disable Monthly ↔ Yearly subscription price/plan switching**.

Plan switching stays off until Pipe Buyer has a separate provider-price-to-plan synchronization and proration policy with tests. Do not infer plan changes from stale subscription metadata.

### Legacy direct-write activation paths retired

The following workflows are retained only as manual deprecated guards and intentionally fail with instructions to use the audited control plane:

- `.github/workflows/activate-live-billing-pending-tax.yml`;
- `.github/workflows/retry-live-billing-activation.yml`;
- `.github/workflows/finalize-live-billing-activation.yml`.

They no longer:

- run on push;
- create `productionBillingActivation`;
- directly set `stripeSubscriptionsEnabled: true`.

### Production-readiness audit strengthened

`.github/workflows/production-readiness-audit.yml` now checks the live provider for:

- expected live Stripe account;
- exact enabled production webhook endpoint;
- all required Dispatch subscription lifecycle events;
- at least one live Billing Portal configuration;
- deployment of `verifyDispatchSubscriptionLifecycleWebhook` alongside the payment surface.

The workflow is still subject to the repository's separate GitHub Actions runner/billing infrastructure blocker. Zero-step hosted-runner failures are not payment-code acceptance evidence.

### Smaller Dispatch-specific operator surface

Added:

`lib/marketplace/marketplace_dispatch_subscription_launch_readiness_panel.dart`

Integrated into:

`lib/marketplace/marketplace_dispatch_subscription_admin_page.dart`

Route:

`/admin/dispatch-billing`

The page is MFA-admin protected. The readiness panel shows Portal, webhook, lifecycle events, recovery, reconciliation, GST/HST, and subscription-enabled state separately. It can verify provider lifecycle events and record/revoke the manual recovery review, but **it cannot activate public subscriptions**.

This keeps Dispatch-specific launch controls out of the already-large general Billing Readiness/Admin files.

### Admin navigation was completed without editing the oversized dashboard

The first safe integration added a `Dispatch Billing` destination to `marketplace_admin_transaction_portal.dart`, but repository inspection showed the real marketplace shell exposes `MarketplaceAdminDashboard` through the account experience and does not rely on that secondary portal for primary discovery.

The final integration therefore updates the existing small `marketplace_account_menu.dart` instead of reconstructing either large admin file.

The account menu now:

- evaluates `marketplaceAdministratorState()`;
- shows `Dispatch Billing Operations` only when the state is `authorized`;
- routes directly to `/admin/dispatch-billing` with GoRouter;
- contains no direct Firestore financial writes.

The destination page independently re-checks the administrator role and MFA, so menu visibility is not the security boundary.

## Verification added

Repository tests/contracts now cover:

- payment-readiness recovery/lifecycle prerequisites;
- Checkout runtime recovery/lifecycle prerequisites;
- Billing Portal activation prerequisite;
- provider-backed lifecycle endpoint/event assessment;
- provider verification persistence and audit;
- manual lifecycle `true` assertion rejection and revocation;
- retirement of the three legacy direct-write activation workflows;
- production-readiness audit requirements;
- stable authenticated `/admin/dispatch-billing` route;
- callable-only launch-readiness UI and absence of a subscription-activation action;
- Administration portal Dispatch shortcut;
- real account-menu Dispatch entry is visible only for `MarketplaceAdministratorState.authorized` and routes to the protected page.

Full Flutter/Functions/emulator acceptance remains required from a complete toolchain. These code/contracts do not replace that release gate.

## Do not repeat

- Do not enable `stripeSubscriptionsEnabled` because Checkout code exists; provider recovery, lifecycle events, reconciliation, tax state, and customer billing-management readiness must all be proven.
- Do not manually assert provider-verifiable webhook readiness; re-read Stripe and record provider evidence.
- Do not restore a workflow or script that directly writes production payment-readiness state around the audited validator.
- Do not sell a new Dispatch subscription when the reviewed Billing Portal is unavailable.
- Do not use Stripe's mutable/default Portal configuration; always pin the reviewed `bpc_...` ID.
- Do not enable Monthly ↔ Yearly plan switching in Portal until the application derives/validates the provider Price and has an approved proration/change policy.
- Do not treat the Smart Retry/email flag as provider-authored evidence; it is an audited operator assertion because the current provider API surface does not expose those Dashboard settings.
- Do not edit the oversized account hub/admin dashboard merely to add a small financial shortcut when a smaller authenticated navigation seam exists.
- Do not treat menu visibility as authorization; the destination financial page/callables must continue to enforce administrator role + MFA.
- Do not mark Monthly/Yearly financially accepted until each controlled payment reconciles `BALANCED` with zero unexplained provider/Firestore difference.
