# Repair record — Dispatch subscription singleton, lifecycle, and billing management

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`  
Base: `p3-external-settlement-checkout`

## Root cause

The original Dispatch subscription Checkout command used an idempotency key containing `Date.now()`:

`pipebuyer-dispatch-${uid}-${plan}-${Date.now()}`

Every repeated tap, browser retry, or concurrent callable invocation therefore became a different Stripe operation. The application also had no single authoritative per-user Dispatch subscription record. Checkout Sessions and paid invoices were recorded separately, but there was no one server-owned state that could answer whether the user already had an open Checkout, an active subscription, a payment problem, or a canceled subscription.

Additional lifecycle and financial audit found five related integrity defects:

1. `invoice.paid` could activate Dispatch access from invoice metadata without re-reading the current Stripe Subscription status;
2. `customer.subscription.updated` could apply an out-of-order event snapshot and overwrite a newer provider state;
3. a legitimate replacement subscription after cancellation could be mistaken for a second live subscription because the retired `sub_` id remained in the singleton state when the new Checkout began;
4. after that retired id was cleared for a replacement Checkout, a very late Checkout/invoice/subscription webhook from the retired subscription could still overwrite the new replacement attempt because there was no durable way to identify the old provider subscription as retired; and
5. a referred Dispatch invoice could accrue a 20% affiliate commission liability even while `affiliatePayoutsEnabled` was false. Payout execution was gated, but accrual was not, so launching Dispatch subscriptions before affiliate economics were approved could silently create an obligation that Pipe Buyer did not intend to owe yet.

Finally, the existing membership UI only displayed informational Dispatch cards. It did not start the server Checkout command, expose provider-authoritative status, or provide a controlled billing-management/cancellation path.

## Repair

### One authoritative Dispatch subscription record

Added server-owned singleton state:

`dispatch_subscriptions/{uid}`

This record owns the current Checkout attempt, provider Session, subscription/customer identity, plan, provider lifecycle status, entitlement state, payment-issue flag, operational-review state, and a bounded retired-subscription ledger used only for stale-event rejection.

Clients do not read or write this document directly. A sanitized callable projection is used for the UI.

### Stable Checkout attempts and idempotency

Added `dispatch_subscription_checkout_policy.js`.

- Checkout attempts are server-owned integers.
- Stripe idempotency is stable per logical attempt:
  `pipebuyer-dispatch-${uid}-attempt-${attempt}`.
- An open provider Checkout is reused instead of duplicated.
- An expired provider Checkout may advance to the next attempt.
- A different plan cannot start while another Dispatch Checkout is open.
- An unresolved existing Stripe subscription blocks creation of a second subscription.
- Provider/write races preserve newer processing/subscription state instead of overwriting it with stale `checkout_created` state.
- Stripe Checkout links must use exact HTTPS `checkout.stripe.com`.
- When a canceled or `incomplete_expired` subscription legitimately starts a replacement Checkout, the prior subscription id is moved into `retiredStripeSubscriptionIds` before `stripeSubscriptionId` is cleared.
- The retired-id ledger is normalized, deduplicated, and bounded to the 10 most recent Stripe subscription ids.
- `unpaid` and other unresolved subscription states are not silently replaceable.
- User-facing Checkout responses no longer return Stripe subscription IDs.

The previous timestamp-based idempotency pattern has been removed.

### Webhook-authoritative entitlement lifecycle

Added `dispatch_subscription_lifecycle_policy.js`, `dispatch_subscription_state.js`, and `dispatch_subscription_webhook_wrapper.js`.

Provider lifecycle behavior:

- `active` / `trialing` => entitlement ON.
- `past_due` => payment issue; preserve the current entitlement while Stripe is still retrying.
- `unpaid`, `canceled`, `incomplete`, `incomplete_expired`, `paused` => entitlement OFF.
- unknown/conflicting subscription states => operational review, not a guessed entitlement transition.

Checkout browser return does **not** grant membership.

`invoice.paid` is now treated as necessary payment evidence, not sufficient entitlement evidence. Every paid invoice re-reads the current Stripe Subscription. Access is activated only when the current provider status is explicitly entitlement-eligible (`active` or `trialing`). A paid invoice whose current Subscription is `unpaid` does not grant access; an unknown current provider status is quarantined for review.

Stripe does not guarantee webhook delivery order. Therefore `customer.subscription.updated` does not trust the potentially stale event snapshot for entitlement. The server re-reads the current Stripe Subscription before changing access. `customer.subscription.deleted` remains a terminal cancellation signal for the current subscription id.

Every Dispatch Checkout-completion, paid-invoice, failed-invoice, subscription-update, and subscription-deletion path now checks the bounded retired-subscription ledger before mutating the singleton. Events belonging to a retired provider subscription return `ignored_retired`; a late retired Checkout Session is retained as `retired_ignored` audit evidence but cannot change the replacement Checkout/subscription state.

The lifecycle wrapper executes inside the already claimed/signed Stripe webhook path. If the Dispatch state update or provider re-read fails, the webhook event is marked failed and returns HTTP 500 so Stripe can retry; the inner financial webhook is not allowed to mark that failed lifecycle event processed.

### Tax/readiness binding

Dispatch Checkout uses the same runtime Canadian small-supplier evidence guard as Pipe Buyer marketplace-fee billing. If Canadian small-supplier billing is the active federal GST/HST state, Checkout re-reads the audited threshold assessment and requires the exact readiness-bound revision before calling Stripe.

The live Dispatch Monthly and Yearly Products both use Stripe service tax code `txcd_10103001`. During the production catalog audit, Monthly Price `price_1U2SYGDkO07WMXyRm6xbprUn` was normalized from `tax_behavior=unspecified` to `tax_behavior=exclusive`, matching the Yearly Price. The live account had zero subscriptions and zero Checkout Sessions at the time, so no existing subscriber behavior was changed. Monthly also received stable lookup key `pipe_buyer_dispatch_monthly_cad` and the same Pipe Buyer/Dispatch/Canada metadata pattern used by Yearly.

### Affiliate commission accrual readiness

Dispatch subscription revenue is no longer allowed to create an unapproved affiliate liability merely because an invoice contains an affiliate referrer.

Added `affiliateCommissionAccrualDecision` in `subscription_monetization.js`:

- no referrer => `no_referrer`, commission 0;
- `affiliatePayoutsEnabled=false` => `disabled_by_readiness`, commission 0;
- affiliate program enabled but commission base 0 => `zero_base`, commission 0;
- affiliate program enabled + positive commission base => `accrued`, using the configured 20% share.

`handleDispatchInvoicePaid` now re-reads `platform_configuration/payment_provider_readiness` and creates an `affiliate_commission_ledger` entry only when `affiliatePayoutsEnabled === true` and the calculated commission is positive.

The Dispatch invoice accounting record always persists the decision as `affiliateCommissionAccrualStatus` and `affiliateCommissionMinor`, so reconciliation can distinguish intentionally disabled accrual from a missing write.

This allows Dispatch subscription revenue to be enabled independently while affiliate economics remain unresolved. Enabling `affiliatePayoutsEnabled` is now the explicit audited act that authorizes both accrual and payout processing.

### Safe user status projection

Added `getDispatchSubscriptionStatus`.

The callable returns only UI-safe state such as plan, provider status, entitlement, payment issue, review state, Checkout availability, Billing Portal availability, and the configured Monthly/Yearly billing catalog.

It does **not** expose Stripe customer IDs, subscription IDs, Checkout provider identifiers, or the retired-subscription ledger.

Monthly/Yearly displayed prices are read from the server Stripe catalog instead of duplicated as authoritative client constants.

### Client data protection

Firestore rules currently default-deny `dispatch_subscriptions` and `subscription_checkout_sessions` because no client allow rule exists. Dedicated rules tests now assert that subscriber, unrelated user, and MFA administrator clients cannot directly read provider identity records or forge Dispatch entitlement/provider state.

### Billing Portal / cancellation path

Added a gated Stripe Billing Portal path:

- audited MFA admin readiness document: `platform_configuration/dispatch_billing_portal`;
- server-only `createDispatchBillingPortalSession` callable;
- portal availability requires explicit readiness plus server-owned `cus_` and `sub_` identity and no subscription-conflict review;
- returned links must use exact HTTPS `billing.stripe.com`;
- Flutter shows `Manage billing or cancel in Stripe` only when the sanitized server status says the portal is available;
- the emergency disable path does not require a return URL, so the portal kill switch cannot be blocked by incomplete configuration.

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

Focused Node 22 execution of the pure Dispatch safety policies: **17 tests passed, 0 failed** before the retired-event extension.

That focused run covers:

- deterministic attempt idempotency;
- open Checkout reuse classification;
- expired Checkout advancement;
- existing subscription duplicate prevention;
- provider/write race preservation;
- active/trialing entitlement;
- past-due payment issue behavior;
- unpaid/canceled entitlement revocation;
- unknown lifecycle review;
- conflicting live subscription quarantine;
- canceled-subscription replacement allowance;
- unresolved `unpaid` replacement refusal;
- safe public status projection with no provider IDs;
- clean restart after cancellation;
- open Checkout duplicate blocking;
- exact Stripe Billing Portal host validation;
- explicit portal readiness/provider-identity gating.

Additional executable retired-subscription harness after the final stale-event repair: **6 tests passed, 0 failed**. It proves:

- retired subscription ids remain bounded;
- a late retired Checkout completion cannot overwrite the replacement Checkout;
- a late retired paid invoice cannot activate the replacement state;
- a late retired failed invoice cannot set the replacement payment-issue state;
- a late retired subscription deletion cannot cancel the replacement Checkout; and
- a late retired subscription update cannot replace the current Checkout state.

The updated Checkout policy separately executed **9 tests passed, 0 failed**.

Affiliate accrual readiness decision executed **4 focused checks passed, 0 failed**:

- referred positive revenue + affiliate disabled => zero liability;
- referred positive revenue + affiliate enabled => configured 20% accrual;
- 100%-discount invoice => zero commission even when affiliate enabled; and
- no referrer => zero commission.

The repository test `subscription_monetization.test.js` also contains the zero-dollar commission-base regression and the controlled 1-year/5-year coupon mapping tests. Functions `npm run check` syntax-checks `subscription_monetization.js` and then executes `node --test test/*.test.js`.

Node syntax checks also passed for the updated Checkout policy, lifecycle policy, and the exercised Dispatch subscription state module in the focused harness.

Repository tests have also been added/expanded for the real Dispatch Checkout command, retired-id persistence, paid-invoice current-provider status re-read, stale subscription-update protection, retired webhook rejection, replacement lifecycle, lifecycle state writer, webhook wrapper, public status projection, Billing Portal policy, Flutter client parsing/URL validation, memberships integration, Firestore provider-state denial, and affiliate accrual readiness.

The repository-wide tests are **committed but not represented as fully executed** until the exact branch is run through `tool/verify.ps1` / Firebase emulators / Flutter in a complete local checkout. This ChatGPT execution sandbox still cannot resolve `github.com`, so a native clone cannot be created here even though the repository is currently public. GitHub-hosted Financial Safety, Callable Safety, iOS, and Quality job shells are currently failing before any step starts and expose no job logs; that remains tracked separately as repository Actions infrastructure issue #91 and is not payment-code evidence.

## Live Stripe production evidence

At the latest read-only audit:

- live Dispatch Monthly Price is active at CAD 25/month;
- live Dispatch Yearly Price is active at CAD 300/year;
- both Prices use exclusive tax behavior after the Monthly normalization;
- both Products use service tax code `txcd_10103001`;
- `PIPEBUYER_FREE_1Y` is a valid 100% repeating coupon for 12 months with zero redemptions;
- `PIPEBUYER_FREE_5Y` is a valid 100% repeating coupon for 60 months with zero redemptions;
- live Stripe had zero subscriptions and zero Checkout Sessions;
- the production webhook is enabled but still lacks `invoice.payment_failed`, `customer.subscription.updated`, and `customer.subscription.deleted`;
- Stripe Billing Portal currently has zero configurations.

The Stripe integration planner recommendation for this use case is hosted Checkout, flat-rate subscriptions, pay up front, Customer Portal self-management, cancel at period end, and Stripe Smart Retries / normal recovery emails. Portal plan switching is intentionally deferred.

## Acceptance still required

Before enabling live Dispatch subscriptions:

1. Run the complete repository `tool/verify.ps1` gate from the final P2 commit.
2. Execute Auth/Firestore/Functions/rules emulator integration.
3. Configure the live Stripe Billing Portal with payment-method updates, invoice history, and cancel-at-period-end; do not enable plan switching yet. Then enable the audited Pipe Buyer portal readiness record.
4. Deploy the accepted lifecycle code before adding live webhook subscriptions for:
   - `invoice.payment_failed`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Keep `affiliatePayoutsEnabled=false` until the affiliate economics are explicitly approved; this now prevents both accrual and payout liability.
6. Run controlled Monthly and Yearly Stripe subscription payments.
7. Prove repeated taps/retries produce one logical Checkout/subscription.
8. Prove `invoice.paid` plus an entitlement-eligible current Subscription activates access and browser return alone does not.
9. Prove failed payment, recovery, cancellation, replacement, retired-event rejection, and deletion lifecycle behavior.
10. Reconcile the controlled invoice/Charge/provider fee evidence with Firestore.
11. Complete web/mobile colleague visual acceptance before production activation.

## Do not repeat

- Do not use timestamps/random values as Stripe idempotency keys for retries of the same logical operation.
- Do not infer paid subscription access from browser redirects or from `invoice.paid` alone without checking current Subscription state.
- Do not trust webhook delivery order for entitlement state when a current provider read is available.
- Do not store separate Checkout/invoice records without one authoritative per-user subscription state.
- Do not merely clear a retired subscription id when replacement starts; retain a bounded retired-id ledger so delayed provider events can be rejected deterministically.
- Do not let the Flutter client directly write Dispatch entitlement or Stripe provider identity.
- Do not create a second subscription while an existing subscription or open Checkout is unresolved.
- Do not expose Stripe customer/subscription IDs or retired provider identities in user-facing status or Checkout responses.
- Do not accrue affiliate commission merely because a referrer exists; accrual and payout readiness must both be explicitly authorized by the audited affiliate readiness control.
- Do not enable the Billing Portal button until Stripe Portal configuration and the audited Pipe Buyer readiness control both agree.
- Do not add subscription lifecycle webhook events before the receiving lifecycle code is deployed.
- Do not mark P2 financially complete until the controlled provider lifecycle and reconciliation evidence are recorded.
