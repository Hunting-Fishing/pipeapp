# Repair record — Dispatch subscription production readiness

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`  
Base: `p3-external-settlement-checkout`

## Root causes

The original Dispatch subscription flow had several independent financial-state defects:

1. Stripe Checkout idempotency included `Date.now()`, so repeated taps/retries were different Stripe operations.
2. There was no single server-owned per-user Dispatch subscription state.
3. Browser/`invoice.paid` evidence could be treated too strongly without re-reading the current Stripe Subscription lifecycle.
4. Out-of-order `customer.subscription.updated` delivery could roll entitlement backward.
5. A canceled subscription replacement could conflict with the retired provider subscription, and later webhooks from that retired subscription could overwrite the replacement attempt.
6. The user UI had informational Dispatch cards but no authoritative subscription status/Checkout/management path.
7. Billing Portal availability was not separately readiness-gated.
8. Dispatch affiliate commission accrual was not independently authorized. A referred paid invoice could create a 20% liability even though the affiliate business economics were still unresolved.
9. Live Monthly and Yearly Stripe tax behavior was inconsistent (`unspecified` vs `exclusive`).

## Repairs

### Singleton and Checkout safety

Server-owned state: `dispatch_subscriptions/{uid}`.

- Stable idempotency: `pipebuyer-dispatch-${uid}-attempt-${attempt}`.
- Open Checkout is reused.
- Expired Checkout may advance to the next attempt.
- A different plan cannot start while another Checkout is unresolved.
- An unresolved Stripe subscription blocks a second subscription.
- Post-provider Firestore persistence preserves newer webhook/provider state.
- Checkout URLs must be exact HTTPS `checkout.stripe.com`.
- Client responses do not expose Stripe subscription/customer IDs.

### Provider-authoritative entitlement

- `active` / `trialing` => access ON.
- `past_due` => payment issue while preserving the current access state during Stripe retry.
- `unpaid`, `canceled`, `incomplete`, `incomplete_expired`, `paused` => access OFF.
- Unknown/conflicting state => review, not a guessed transition.
- Browser return from Checkout never grants access.
- `invoice.paid` always re-reads the current Stripe Subscription and only activates access when the current status is entitlement-eligible.
- `customer.subscription.updated` re-reads the current Subscription so stale webhook snapshots cannot roll access backward.

### Replacement and retired-provider protection

A restart is permitted only for genuinely restartable states (`canceled`, `incomplete_expired`).

The prior subscription ID is moved to normalized `retiredStripeSubscriptionIds`, bounded to the 10 most recent IDs, before the replacement live ID is cleared. Checkout completion, paid invoice, failed invoice, subscription update, and subscription deletion events belonging to a retired ID return `ignored_retired` and cannot mutate the replacement state. A late retired Checkout is retained as `retired_ignored` audit evidence.

### Webhook execution

Dispatch lifecycle processing is composed inside the existing signed + transactionally claimed Stripe webhook. A Dispatch lifecycle failure marks the event failed and returns HTTP 500 before the inner financial handler can mark it processed.

### Tax/readiness safety

Dispatch Checkout re-checks the current audited Canadian small-supplier assessment revision immediately before Stripe when small-supplier mode is active.

If an audited threshold assessment exceeds the small-supplier threshold, the automatic readiness shutdown now clears:

- `canadaGstHstSmallSupplier`
- `stripeFeeBillingEnabled`
- `stripeSubscriptionsEnabled`
- `dispatchAffiliateCommissionAccrualEnabled`

This prevents an internally inconsistent readiness state after billing is shut down for tax review.

### Separate Dispatch affiliate accrual and payout controls

These are now different financial authorities:

- `dispatchAffiliateCommissionAccrualEnabled` = business authorization to incur **new Dispatch affiliate commission obligations**.
- `affiliatePayoutsEnabled` = operational authorization to send eligible affiliate payouts/Transfers.

`dispatchAffiliateCommissionAccrualEnabled` defaults false and may only be enabled when live Dispatch subscriptions, production mode, verified webhooks, and reconciliation readiness are active.

`subscription_monetization.js` records an explicit `affiliateCommissionAccrualStatus` on every paid Dispatch invoice:

- `no_referrer` => 0
- `disabled_by_readiness` => 0
- `zero_base` => 0
- `accrued` => configured commission (currently 20%)

No `affiliate_commission_ledger` record is created unless Dispatch accrual is explicitly enabled and the commission is positive.

This means Pipe Buyer can launch Dispatch subscriptions with `dispatchAffiliateCommissionAccrualEnabled=false` while affiliate economics are still unresolved. If commissions are later contractually approved, accrual can be enabled independently. A temporary payout pause does not erase or stop approved accrual because payout execution is a separate control.

### Free subscription promotions

Live coupons are verified as:

- `PIPEBUYER_FREE_1Y` — 100% repeating for 12 months.
- `PIPEBUYER_FREE_5Y` — 100% repeating for 60 months.

Both had zero redemptions at the audit time. Code treats a 100%-discount invoice as commission base 0, so it cannot create false affiliate revenue/commission.

### Live Stripe catalog normalization

Live Dispatch objects are:

- Monthly: CAD 25/month, active.
- Yearly: CAD 300/year, active.
- Both Products: service tax code `txcd_10103001`.

During this repair, while the live account had zero subscriptions and zero Checkout Sessions:

- Monthly Price tax behavior was changed from `unspecified` to `exclusive`, matching Yearly.
- Monthly Price received stable lookup key `pipe_buyer_dispatch_monthly_cad`.
- Monthly metadata was normalized to Pipe Buyer / Dispatch / Canada / monthly subscription.

No charge or subscription was created by these catalog changes.

### Safe user UX and Billing Portal

- `getDispatchSubscriptionStatus` returns only bounded UI-safe state and server catalog prices.
- `Memberships & upgrades` now presents Dispatch Monthly/Yearly Checkout actions and current provider-authoritative state.
- Flutter never writes authoritative subscription/provider state.
- Billing Portal session creation is server-only and accepts only exact HTTPS `billing.stripe.com` URLs.
- Portal UI appears only when the audited Pipe Buyer portal readiness record and server-owned subscription/customer identity agree.
- Portal emergency disable does not require a return URL.

The live Stripe account currently has zero Billing Portal configurations, so Pipe Buyer portal readiness remains OFF.

## Verification evidence

Focused executable evidence completed during this work:

- Earlier P2 pure safety set: **17/17 passed**.
- Updated Checkout policy: **9/9 passed**.
- Retired-provider event harness: **6/6 passed**.
- Dedicated Dispatch affiliate accrual/readiness decisions: **6/6 passed**.
- Earlier affiliate decision slice: **4/4 passed** before the accrual/payout controls were split; superseded by the dedicated accrual control above.

Repository tests additionally cover:

- real Dispatch Checkout provider stubs;
- paid-invoice current-Subscription re-read;
- stale subscription-update protection;
- replacement/retired event behavior;
- Billing Portal policy;
- public status projection;
- Flutter model/URL/route contracts;
- Firestore provider-state denial;
- zero-dollar commission base;
- 1-year/5-year coupon mapping;
- dedicated Dispatch affiliate accrual readiness;
- readiness validation.

`firebase/functions/package.json` syntax-checks the P2 Functions modules and runs `node --test test/*.test.js` as part of `npm run check`.

The complete repository gate has **not** been represented as passing: GitHub-hosted Financial Safety, Callable Safety, iOS, and Quality job shells currently terminate before any step runs and provide no logs. This is tracked under Issue #91. The ChatGPT execution sandbox also cannot resolve `github.com` for a native clone, so `tool/verify.ps1` / Flutter / Firebase emulator execution still requires a complete external checkout or restored runner execution.

## Current live Stripe evidence

At the latest audit:

- zero live Stripe Subscriptions;
- zero live Checkout Sessions;
- production webhook enabled;
- production webhook still missing:
  - `invoice.payment_failed`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
- zero Billing Portal configurations.

Recommended Stripe production behavior for P2: hosted Checkout, flat-rate pay-up-front subscriptions, Customer Portal, cancel at period end, payment-method management, invoice history, Smart Retries / standard failed-payment recovery, and no Portal plan switching yet.

## Acceptance still required before production activation

1. Run the exact final P2 commit through `tool/verify.ps1` / Flutter / Functions / rules / Firebase emulator gates.
2. Deploy the accepted lifecycle code.
3. Only after deployment, add the three missing live Stripe subscription lifecycle webhook events.
4. Configure Stripe Billing Portal for payment method updates, invoice history, and cancel-at-period-end; keep plan switching disabled initially.
5. Enable the audited Pipe Buyer portal readiness record only after the Stripe Portal configuration exists.
6. Keep `dispatchAffiliateCommissionAccrualEnabled=false` until affiliate economics are explicitly approved.
7. Keep `affiliatePayoutsEnabled=false` until payout operations are explicitly approved.
8. Run controlled Monthly and Yearly subscriptions.
9. Prove double-tap/retry creates one logical subscription.
10. Prove success, failed payment/recovery, renewal, cancellation, replacement, and retired-event behavior.
11. Reconcile the controlled Stripe invoice/Charge/provider fee evidence to Firestore with zero unexplained difference.
12. Complete web/mobile colleague acceptance.

## Do not repeat

- Do not use timestamps/randomness for idempotency of the same logical payment attempt.
- Do not grant entitlement from a browser redirect or `invoice.paid` alone.
- Do not trust webhook event order where a current provider read can resolve state.
- Do not clear a retired subscription identity without retaining bounded stale-event evidence.
- Do not let clients write Dispatch entitlement or provider identity.
- Do not expose Stripe subscription/customer IDs to the user status API.
- Do not treat affiliate **accrual** and affiliate **payout execution** as the same financial control.
- Do not create affiliate liabilities while Dispatch accrual readiness is disabled.
- Do not add lifecycle webhook events before the receiving code is deployed.
- Do not enable Billing Portal UI before Stripe Portal + Pipe Buyer readiness agree.
- Do not mark P2 financially complete until controlled provider lifecycle and exact reconciliation evidence are recorded.
