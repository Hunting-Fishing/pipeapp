# Repair Record — Stripe production API version alignment

Date: 2026-08-23  
Branch: `p3-external-settlement-checkout`  
PR: #95

## Observed mismatch

Pipe Buyer production API requests were globally pinned to `2026-06-24.preview`, while the live Stripe webhook endpoint is pinned to the GA `2026-06-24.dahlia` API version.

Stripe documents `.preview` as a distinct public-preview release channel. The P3 payment path uses ordinary GA v1 Checkout, PaymentIntent, Charge, Balance Transaction, Refund and Transfer resources. Current Stripe documentation also exposes Accounts v2 Recipient configuration, `stripe_balance.stripe_transfers`, Express Dashboard, and platform fee/loss responsibility fields in the GA API.

## Root cause

The shared Stripe API-version constant originated while Accounts v2 functionality was earlier in preview. The preview pin remained after the recipient Accounts v2 surface used by Pipe Buyer became available in the GA API.

This made unrelated production money operations inherit public-preview API behavior even though they did not require a preview feature.

## Repair

Changed the shared production Stripe API version from:

`2026-06-24.preview`

to:

`2026-06-24.dahlia`

This aligns Pipe Buyer outgoing API requests with the currently configured live webhook endpoint API family and removes an unnecessary public-preview dependency from production billing.

No Stripe account object, Checkout Session, charge, webhook endpoint, payment-readiness flag, or seller account was mutated by this repair.

## Verification

Added `firebase/functions/test/stripe_api_version_policy.test.js` to require the reviewed GA `2026-06-24.dahlia` pin and reject a `.preview` suffix.

After the change, the mounted focused P3 Node safety suite executed **80 tests: 80 passed, 0 failed**.

Read-only Stripe evidence on 2026-08-23 confirmed:

- Pipe Buyer live account `acct_1U2QmKDkO07WMXyR`;
- live webhook `we_1U2mXRDkO07WMXyRpm7HCA9z` uses `2026-06-24.dahlia` and remains enabled;
- zero live Checkout Sessions existed at the time of the check.

## Do not repeat

Do not move all production Stripe traffic back to a `.preview` API version merely because one future Stripe feature requires preview access. If a future feature is genuinely preview-only, isolate that feature behind a separately reviewed API-version path instead of changing the shared monetary API version for Checkout, charges, refunds, reconciliation, and transfers.

Any future API-version change must be reviewed against:

1. the live webhook endpoint version;
2. Checkout/PaymentIntent/Charge/Balance Transaction behavior;
3. Accounts v2 seller onboarding fields;
4. refund/dispute/transfer operations;
5. provider-stub and repository verification tests.
