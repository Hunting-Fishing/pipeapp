# Repair record — Dispatch subscription singleton, lifecycle, and billing management

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`  
Base: `p3-external-settlement-checkout`

## Root cause

The original Dispatch subscription Checkout command used an idempotency key containing `Date.now()`:

`pipebuyer-dispatch-${uid}-${plan}-${Date.now()}`

Every repeated tap, browser retry, or concurrent callable invocation therefore became a different Stripe operation. The application also had no single authoritative per-user Dispatch subscription record. Checkout Sessions and paid invoices were recorded separately, but there was no one server-owned state that could answer whether the user already had an open Checkout, an active subscription, a payment problem, or a canceled subscription.

A second lifecycle gap followed from that architecture: access could not be governed reliably from Stripe subscription events. The live webhook handled `invoice.paid`, but the Dispatch entitlement model did not yet consume `invoice.payment_failed`, `customer.subscription.updated`, or `customer.subscription.deleted` into a central subscription state.

Finally, the existing membership UI only displayed informational Dispatch cards. It did not start the server Checkout command, expose provider-authoritative status, or provide a controlled billing-management/cancellation path.

## Repair

### One authoritative Dispatch subscription record

Added server-owned singleton state:

`dispatch_subscriptions/{uid}`

This record owns the current Checkout attempt, provider Session, subscription/customer identity, plan, provider lifecycle status, entitlement state, payment-issue flag, and operational-review state.

Clients do not read or write this document directly. A sanitized callable projection is used for the UI.

### Stable Checkout attempts and idempotency

Added `dispatch_subscription_checkout_policy.js`.

- Checkout attempts are server-owned integers.
- Stripe idempotency is stable per logical attempt:
  `pipebuyer-dispatch-${uid}-attempt-${attempt}`.
- An open provider Checkout is reused instead of duplicated.
- An expired provider Checkout may advance to the next attempt.
- A different plan cannot start while another Dispatch Checkout is open.
- An existing Stripe subscription blocks creation of a second subscription.
- Provider/write races preserve newer processing/subscription state instead of overwriting it with stale `checkout_created` state.
- Stripe Checkout links must use exact HTTPS `checkout.stripe.com`.

The previous timestamp-based idempotency pattern has been removed.

### Webhook-authoritative entitlement lifecycle

Added `dispatch_subscription_lifecycle_policy.js`, `dispatch_subscription_state.js`, and `dispatch_subscription_webhook_wrapper.js`.

Provider lifecycle behavior:

- `active` / `trialing` => entitlement ON.
- `past_due` => payment issue; preserve the current entitlement while Stripe is still retrying.
- `unpaid`, `canceled`, `incomplete`, `incomplete_expired`, `paused` => entitlement OFF.
- unknown/conflicting subscription states => operational review, not a guessed entitlement transition.

Checkout browser return does **not** grant membership. `invoice.paid` / Stripe subscription lifecycle evidence drives the authoritative state.

The lifecycle wrapper executes inside the already claimed/signed Stripe webhook path. If the Dispatch state update fails, the webhook event is marked failed and returns HTTP 500 so Stripe can retry; the inner financial webhook is not allowed to mark that failed lifecycle event processed.

### Tax/readiness binding

Dispatch Checkout uses the same runtime Canadian small-supplier evidence guard as Pipe Buyer marketplace-fee billing. If Canadian small-supplier billing is the active federal GST/HST state, Checkout re-reads the audited threshold assessment and requires the exact readiness-bound revision before calling Stripe.

### Safe user status projection

Added `getDispatchSubscriptionStatus`.

The callable returns only UI-safe state such as plan, provider status, entitlement, payment issue, review state, Checkout availability, Billing Portal availability, and the configured Monthly/Yearly billing catalog.

It does **not** expose Stripe customer IDs, subscription IDs, or Checkout provider identifiers.

Monthly/Yearly displayed prices are read from the server Stripe catalog instead of duplicated as authoritative client constants.

### Client data protection

Firestore rules currently default-deny `dispatch_subscriptions` and `subscription_checkout_sessions` because no client allow rule exists. Dedicated rules tests now assert that subscriber, unrelated user, and MFA administrator clients cannot directly read provider identity records or forge Dispatch entitlement/provider state.

### Billing Portal / cancellation path

Added a gated Stripe Billing Portal path:

- audited MFA admin readiness document: `platform_configuration/dispatch_billing_portal`;
- server-only `createDispatchBillingPortalSession` callable;
- portal availability requires explicit readiness plus server-owned `cus_` and `sub_` identity and no subscription-conflict review;
- returned links must use exact HTTPS `billing.stripe.com`;
- Flutter shows `Manage billing or cancel in Stripe` only when the sanitized server status says the portal is available.

The live Pipe Buyer Stripe account currently has no Billing Portal configuration. Therefore this readiness remains OFF and no live portal mutation was made during this repair.

### User experience

The existing account menu `Memberships & upgrades` entry now opens a small combined memberships dialog:

- VIP continues to its existing detail flow;
- Dispatch Monthly and Yearly use the authoritative status callable and server Checkout command;
- existing open Checkout is continued instead of restarted;
- processing state instructs the user not to start another payment;
- active, past-due, canceled, review, and inactive-existing subscription states are shown distinctly;
- client code never marks membership active because a browser returned from Checkout.

## Verification executed

Focused Node 22 execution of the pure Dispatch safety policies: **15 tests passed, 0 failed**.

This focused run covers:

- deterministic attempt idempotency;
- open Checkout reuse classification;
- expired Checkout advancement;
- existing subscription duplicate prevention;
- provider/write race preservation;
- active/trialing entitlement;
- past-due payment issue behavior;
- unpaid/canceled entitlement revocation;
- unknown lifecycle review;
- conflicting subscription quarantine;
- safe public status projection with no provider IDs;
- clean restart after cancellation;
- open Checkout duplicate blocking;
- exact Stripe Billing Portal host validation;
- explicit portal readiness/provider-identity gating.

Repository tests have also been added for the real Dispatch Checkout command, lifecycle state writer, webhook wrapper, public status projection, Billing Portal policy, Flutter client parsing/URL validation, memberships integration, and Firestore provider-state denial.

These repository tests are **committed but not represented as fully executed** until the exact branch is run through `tool/verify.ps1` / Firebase emulators / Flutter in a complete local checkout.

## Acceptance still required

Before enabling live Dispatch subscriptions:

1. Run the complete repository `tool/verify.ps1` gate from the final P2 commit.
2. Execute Auth/Firestore/Functions/rules emulator integration.
3. Configure the live Stripe Billing Portal with the reviewed cancellation/payment-method features, then enable the audited Pipe Buyer portal readiness record.
4. Add and verify live webhook subscriptions for:
   - `invoice.payment_failed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Run controlled Monthly and Yearly Stripe subscription payments.
6. Prove repeated taps/retries produce one logical Checkout/subscription.
7. Prove `invoice.paid` activates access and browser return alone does not.
8. Prove failed payment, recovery, cancellation, and deletion lifecycle behavior.
9. Reconcile the controlled invoice/Charge/provider fee evidence with Firestore.
10. Complete web/mobile colleague visual acceptance before production activation.

## Do not repeat

- Do not use timestamps/random values as Stripe idempotency keys for retries of the same logical operation.
- Do not infer paid subscription access from browser redirects.
- Do not store separate Checkout/invoice records without one authoritative per-user subscription state.
- Do not let the Flutter client directly write Dispatch entitlement or Stripe provider identity.
- Do not create a second subscription while an existing subscription or open Checkout is unresolved.
- Do not expose Stripe customer/subscription IDs in the user status API.
- Do not enable the Billing Portal button until Stripe Portal configuration and the audited Pipe Buyer readiness control both agree.
- Do not mark P2 financially complete until the controlled provider lifecycle and reconciliation evidence are recorded.
