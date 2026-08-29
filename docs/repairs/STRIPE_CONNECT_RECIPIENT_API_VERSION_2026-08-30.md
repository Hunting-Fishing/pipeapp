# Stripe Connect seller onboarding architecture repair — 2026-08-30

## Scope

Seller payout account creation, Stripe-hosted onboarding links, and seller payout readiness reads only. No buyer charge, refund, transfer, payout release, subscription, webhook, tax, or marketplace fee behavior is changed by this repair.

## Observed production sequence

1. Seller payout onboarding initially failed before Stripe-hosted onboarding opened.
2. Sanitized diagnostics exposed `account_creation_liability_unacknowledged`.
3. The Pipe Buyer platform owner completed Stripe's Connect negative-balance liability acknowledgement.
4. Seller onboarding then returned `capability_not_available_without_other_capability`.
5. Moving Accounts v2 between `2026-07-29.preview` and `2026-02-25.preview` did not solve the production failure.
6. The expanded diagnostic exposed Stripe's exact dependency: `stripe_balance.stripe_transfers` could not be requested without `configuration.merchant_capabilities.card`. The latest captured Stripe request reference was `req_v2xLVobnA6cu5ucnq`.

The repeated production evidence disproved API-preview pinning as the root-cause repair.

## Root cause

Pipe Buyer's marketplace payment architecture uses **separate charges and transfers** so the buyer charge is created on the Pipe Buyer platform and seller proceeds are transferred later under server-controlled completion/readiness rules.

Stripe's current documentation states that the Accounts v2 preview does **not** support separate charges and transfers. That makes Accounts v2 the wrong connected-account API family for Pipe Buyer's current payment architecture, even though its recipient examples superficially resemble the desired seller account.

Stripe's stable Connect v1 documentation states that Express connected accounts support separate charges and transfers. The v1 Accounts API also supports controller properties that preserve the intended responsibilities:

- Stripe-hosted Express Dashboard
- Stripe requirement collection
- Pipe Buyer pays Stripe fees
- Pipe Buyer owns payment loss responsibility
- connected seller requests `transfers` capability

No seller direct-charge card-processing capability is required by Pipe Buyer's current flow.

## Corrected repair

Seller Connect account management is moved from Accounts v2 preview to stable Connect v1:

- create seller account: `POST /v1/accounts`
- create Stripe-hosted onboarding link: `POST /v1/account_links`
- read seller readiness: `GET /v1/accounts/{account}`
- Stripe API version: `2026-06-24.dahlia`
- request format: `application/x-www-form-urlencoded`
- controller dashboard: `express`
- controller requirement collection: `stripe`
- controller fee payer: `application`
- controller payment losses: `application`
- requested seller capability: `transfers`

The marketplace payment pipeline remains separate charges and transfers. This repair does not change buyer charges or seller transfer execution.

## Readiness correction

A seller is considered payout-ready only when both conditions are true:

1. `capabilities.transfers == active`
2. `payouts_enabled == true`

This prevents an account with transfer capability but no usable payout destination from being reported as ready.

## Regression coverage

`firebase/functions/test/stripe_connect_accounts_api_version.test.js` locks these conditions:

1. seller Connect uses stable v1 rather than Accounts v2 preview;
2. the Connect API version remains isolated from other Stripe payment surfaces;
3. seller creation uses `/v1/accounts` and requests `transfers`;
4. Express Dashboard and Stripe requirement collection remain configured;
5. seller onboarding uses `/v1/account_links`;
6. no Accounts v2 seller endpoint remains;
7. no Merchant/Card capability is requested by this seller flow;
8. payout readiness requires both active transfers and payouts enabled.

## Do not repeat

- Do not treat the `2026-07-29.preview` or `2026-02-25.preview` changes as successful fixes; production retries disproved both.
- Do not add Merchant/Card capability merely to silence the Accounts v2 dependency while Pipe Buyer continues to use separate charges and transfers.
- Do not use Accounts v2 seller onboarding for the current separate-charges-and-transfers marketplace architecture unless Stripe explicitly adds support and the entire flow is re-reviewed.
- Do not change the buyer charge/fee/transfer ledger as part of this seller onboarding repair.
- Do not perform a real buyer charge, transfer, refund, or payout without explicit approval immediately before the financial action.

## Live acceptance

This document records the root-cause repair implementation. It must not be marked fully closed until a production seller account is successfully created, Stripe-hosted onboarding opens, and the seller's live readiness can be read back through the v1 account status path.