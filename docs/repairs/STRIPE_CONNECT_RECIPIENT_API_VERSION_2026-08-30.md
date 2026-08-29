# Stripe Connect recipient Accounts v2 API version repair — 2026-08-30

## Scope

Seller payout onboarding only. No buyer charge, refund, transfer, payout, subscription, webhook, or tax behavior was changed by this repair.

## Observed production sequence

1. Seller payout onboarding initially failed before Stripe-hosted onboarding opened.
2. After the sanitized Stripe error contract was deployed, Stripe returned `account_creation_liability_unacknowledged`.
3. The Pipe Buyer platform owner completed the required Connect negative-balance liability acknowledgement in Stripe Dashboard on 2026-08-29.
4. A new seller onboarding attempt then returned `capability_not_available_without_other_capability`.

The second error proved that the liability acknowledgement was no longer the blocker and narrowed the failure to the Accounts v2 capability request.

## Root cause

`firebase/functions/stripe_marketplace_commands.js` was using the shared Stripe preview version `2026-06-24.preview` for Accounts v2 seller-recipient calls.

The seller payload itself matches Stripe's current marketplace recipient guidance:

- `dashboard: express`
- `defaults.responsibilities.fees_collector: application`
- `defaults.responsibilities.losses_collector: application`
- `configuration.recipient.capabilities.stripe_balance.stripe_transfers.requested: true`

Stripe's current marketplace connected-account creation guide uses Accounts v2 preview `2026-07-29.preview` for this recipient configuration. The older preview evaluated the requested recipient transfer capability with an incompatible dependency contract and returned `capability_not_available_without_other_capability`.

## Repair

- Added `stripeMarketplaceConfig.connectAccountsApiVersion = "2026-07-29.preview"`.
- Seller Connect Accounts v2 requests now use that isolated version.
- The general Stripe integration remains on `stripeMarketplaceConfig.apiVersion = "2026-06-24.preview"`.
- Checkout, subscriptions, marketplace payment processing, and webhook API behavior were not globally upgraded.

## Regression coverage

`firebase/functions/test/stripe_connect_accounts_api_version.test.js` locks both conditions:

1. seller Connect Accounts v2 uses `2026-07-29.preview`;
2. the Connect Accounts preview remains isolated from the shared Stripe preview used by other payment surfaces.

## Do not repeat

- Do not add merchant/card-payment capabilities to marketplace recipient accounts just to silence a capability dependency error. Pipe Buyer sellers are recipients for separate charges and transfers; they are not direct-charge merchants in this flow.
- Do not globally upgrade the Stripe API version as a repair for a Connect-only preview mismatch.
- Do not remove platform-owned fees/losses from the recipient configuration; that responsibility model is intentional for Pipe Buyer's marketplace flow.
- Do not perform a real buyer charge, seller transfer, refund, or payout as part of diagnosing seller onboarding unless explicitly approved immediately before the financial action.
