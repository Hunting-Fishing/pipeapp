# Pipe Buyer Payment Configuration — Repository Reconciliation

Status: active repository truth for autonomous payment work  
Reconciled: 2026-08-23  
Scope: source-controlled configuration and contracts only; this document does not claim live provider or production evidence.

## Purpose

This file gives engineering workers a concise, current map of the payment implementation so code work can continue without repeatedly re-discovering the same architecture or confusing source presence with production readiness. `docs/PAYMENTS_EXECUTION_TRACKER.md` remains authoritative for completion.

## Current server-owned Stripe catalog

`firebase/functions/stripe_marketplace_config.js` is the source-controlled Stripe object mapping.

| Flow | Currency | Amount | Interval | Source-controlled object |
| --- | --- | ---: | --- | --- |
| Dispatch Monthly | CAD | CA$25.00 | month | `dispatchMonthlyCad` |
| Dispatch Yearly | CAD | CA$300.00 | year | `dispatchYearlyCad` |
| Pipe Marketplace Fee | provider-calculated from immutable fee snapshot | variable | one-time | `pipeMarketplaceFeeCad` |
| Equipment Marketplace Fee | provider-calculated from immutable fee snapshot | variable | one-time | `equipmentMarketplaceFee` |

The Dispatch monthly/yearly checkout command selects the server-configured Price ID. The Flutter client must never provide the authoritative amount or Price ID.

Server-owned promotion identifiers exist for one-year-free and five-years-free Dispatch entitlements. Eligibility is read from Firestore by the server; clients must not choose arbitrary coupons.

## Dispatch subscription command

`firebase/functions/dispatch_subscription_commands.js` exports the implementation used by the production Functions bootstrap.

Checkout is fail-closed unless all of the following repository-defined readiness fields are satisfied:

- `paidFeatures` feature is enabled;
- `dispatch` feature is enabled;
- `stripeSubscriptionsEnabled == true`;
- `stripeMode == production`;
- `stripeWebhookVerified == true`;
- `stripeReconciliationReady == true`;
- tax state is either approved ready or explicitly registration-pending;
- configured success/cancel URLs are valid;
- authenticated identity and rate-limit checks pass.

Checkout uses Stripe `mode=subscription`, requires billing address collection, uses server-owned Price/coupon IDs, includes Pipe Buyer metadata, and persists the checkout session under `subscription_checkout_sessions`.

## Webhook authority

The production bootstrap exports `stripeMarketplaceWebhook`. `firebase/functions/stripe_webhook.js` verifies the raw-body Stripe signature with a five-minute timestamp tolerance and records Stripe event IDs in `stripe_webhook_events`.

The handler currently covers:

- `checkout.session.completed`;
- `checkout.session.async_payment_succeeded`;
- `checkout.session.async_payment_failed`;
- `invoice.paid`;
- `charge.refunded`;
- `refund.created`;
- `refund.updated`;
- `refund.failed`;
- dispute created/updated/closed/funds-withdrawn/funds-reinstated events.

Already-processed event IDs return without replaying financial side effects. Failed processing is stored as failed and returns HTTP 500 so Stripe can retry.

For Dispatch, Checkout completion records session/provider state; `invoice.paid` remains the monetization/entitlement authority. A browser redirect must never grant paid entitlement by itself.

## External-settlement Marketplace fee

The production bootstrap exports `confirmExternalSettlement` and `createExternalSettlementFeeCheckout`.

The fee-only webhook path validates Stripe checkout subtotal against the immutable marketplace-fee snapshot and records provider identifiers. It does not create a seller-proceeds Transfer.

This flow remains subject to the acceptance/reconciliation/tax items in P3 of the payment tracker.

## Full on-platform Marketplace checkout

The repository contains Separate Charges and Transfers foundations. Seller Transfers are guarded by provider readiness, payout holds, successful PaymentIntent evidence, immutable sale/fee snapshots, `source_transaction`, and an idempotency key tied to the Pipe Buyer transaction.

**Do not autonomously activate this flow.** P4 remains gated by provider/risk/legal/tax/acceptance evidence.

## Source-controlled readiness versus live readiness

The repository can prove implementation contracts. It cannot, by source inspection alone, prove the current values or secret versions in production.

The following remain external evidence and must not be invented by an autonomous worker:

- current production `platform_configuration/payment_provider_readiness` values;
- deployed `STRIPE_SECRET_KEY` binding/version;
- deployed `STRIPE_WEBHOOK_SECRET` binding/version;
- current Stripe Dashboard product/price activation state;
- current webhook endpoint health/retry history;
- government tax registrations/effective dates;
- live payment/reconciliation acceptance.

A blocked external item does not prevent independent code/test work from continuing.

## Immediate autonomous code queue

Until live-provider evidence is supplied, autonomous payment work should prefer these repository-verifiable items in order:

1. confirm/build Flutter Monthly and Yearly Dispatch subscription actions against `createDispatchSubscriptionCheckout`;
2. confirm success/cancel UX treats redirects as pending provider evidence, never entitlement authority;
3. add/strengthen tests for `invoice.paid`, recurring failure, renewal, cancellation/end-of-period behavior;
4. add/strengthen one-year-free and five-years-free entitlement tests, including zero-dollar invoice revenue behavior;
5. build/verify customer self-service subscription-management UX using a server-authoritative provider path;
6. strengthen external-settlement two-party confirmation, duplicate prevention, failure and receipt/admin-state tests;
7. strengthen reconciliation capture for Checkout Session, PaymentIntent, Charge, Balance Transaction where applicable, refunds, disputes, currency, fee revision and webhook event IDs;
8. build reconciliation exception/admin tooling that can be tested without live money movement.

Each payment increment is HIGH risk by default and requires focused tests, compatibility checks, rollback notes, independent review and the full repository verification gate.

## Activation boundary

Autonomous development may prepare code, tests, emulator acceptance, reconciliation tooling and runbooks. It may not:

- mutate live Stripe products/prices/coupons/webhooks;
- enable paid features in production;
- create live charges/refunds/transfers;
- declare tax readiness;
- deploy production Functions;
- merge itself to `main`.
