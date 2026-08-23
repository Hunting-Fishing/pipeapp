# P2 Dispatch subscription revenue recovery policy

Date approved for P2 cutover: 2026-08-23  
Scope: Pipe Buyer Dispatch Monthly and Yearly Stripe subscriptions

This file fixes the live Stripe Billing recovery policy for the initial P2 release. It complements `docs/P2_DISPATCH_PRODUCTION_CUTOVER.md` and removes ambiguity from its recovery-review gates.

## Approved Stripe Revenue Recovery configuration

For recurring Dispatch subscription invoices in Stripe LIVE mode:

- **Smart Retries:** enabled.
- **Retry policy:** **8 attempts within 2 weeks**.
- **Failed-payment customer emails:** enabled.
- **Payment-method recovery path:** customers update payment methods through the provider-verified Pipe Buyer Billing Portal.
- **State while Stripe is actively retrying:** `past_due`.
- **Final state after the retry policy is exhausted without recovery:** **cancel the subscription**.
- **Do not configure:** leave subscription overdue indefinitely.
- **Do not configure as the P2 target:** terminal `unpaid`.

Stripe currently recommends Smart Retries for recurring revenue recovery and documents 8 attempts within 2 weeks as its recommended default profile.

## Why cancellation is the P2 terminal policy

Pipe Buyer's Dispatch lifecycle intentionally treats states differently:

- `active` / `trialing` → entitlement ON;
- `past_due` → preserve current entitlement while Stripe is still retrying, with `paymentIssue=true`;
- successful recovery → clear payment issue and return to provider-authoritative active state;
- `canceled` → entitlement OFF and a legitimate replacement Checkout may start;
- `unpaid` → entitlement OFF, but the singleton treats the provider relationship as unresolved and does not use it as the normal replacement path.

Therefore **cancel after exhausted retries** gives the cleanest production behavior:

1. customers retain paid access while automated recovery is genuinely in progress;
2. failed recovery ends entitlement deterministically;
3. the terminal provider state is restartable by the existing Dispatch Checkout policy;
4. a customer can later begin a clean replacement subscription;
5. retired provider IDs remain protected by the bounded retired-subscription ledger.

Leaving the subscription permanently `past_due` is not approved because current entitlement policy intentionally preserves access in `past_due` while recovery is underway. Making that state indefinite could preserve access beyond the intended retry window.

`unpaid` remains supported defensively if Stripe/provider state ever reports it: Pipe Buyer revokes entitlement and flags the unresolved provider relationship. It is not the configured P2 dunning outcome.

## Operator acceptance

Before `stripeSubscriptionRecoveryVerified` may be recorded from `/admin/dispatch-billing`, an MFA administrator must verify in the Stripe LIVE Dashboard that:

- [ ] Smart Retries are enabled.
- [ ] the retry profile is 8 attempts within 2 weeks.
- [ ] failed-payment customer emails are enabled.
- [ ] exhausted retries cancel the subscription.
- [ ] payment-method recovery points customers to the reviewed Billing Portal.
- [ ] the reviewed Portal configuration still has Monthly ↔ Yearly switching disabled.

The available connected Stripe API surface does not expose these Revenue Recovery Dashboard controls as provider-readable configuration. This evidence is therefore an audited operator assertion, not provider-authored proof.

If any of these Dashboard settings change, revoke `stripeSubscriptionRecoveryVerified` and re-review the configuration before new Dispatch Checkouts are allowed.

## Controlled acceptance expectations

The live acceptance must prove:

1. `invoice.payment_failed` sets the payment-issue state.
2. provider `past_due` preserves the existing entitlement during the approved retry window.
3. successful payment recovery returns the subscription to active/trialing provider state and clears the payment issue.
4. exhausted recovery results in provider cancellation.
5. cancellation removes entitlement.
6. a subsequent legitimate replacement Checkout is allowed.
7. very late events from the retired subscription cannot mutate the replacement singleton.

## Do not repeat

- Do not leave the terminal recovery outcome unspecified.
- Do not configure `past_due` to persist indefinitely for P2.
- Do not change entitlement logic merely to match a different Stripe Dashboard dunning configuration; change/review the provider policy first.
- Do not treat an operator recovery-verification flag as permanent. Revoke and re-review after provider recovery-setting changes.
