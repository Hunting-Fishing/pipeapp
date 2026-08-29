# Stripe Connect recipient Accounts v2 API version repair — 2026-08-30

## Scope

Seller payout onboarding only. No buyer charge, refund, transfer, payout, subscription, webhook, or tax behavior is changed by this repair.

## Observed production sequence

1. Seller payout onboarding initially failed before Stripe-hosted onboarding opened.
2. After the sanitized Stripe error contract was deployed, Stripe returned `account_creation_liability_unacknowledged`.
3. The Pipe Buyer platform owner completed the required Connect negative-balance liability acknowledgement in Stripe Dashboard on 2026-08-29.
4. A later seller onboarding attempt returned `capability_not_available_without_other_capability`.
5. We first isolated seller Accounts v2 onto `2026-07-29.preview`, but a production retry still failed with the same code.
6. The expanded sanitized diagnostic then exposed Stripe's exact dependency message: `stripe_balance.stripe_transfers` could not be requested without `configuration.merchant_capabilities.card` (request `req_v20yaXFLI12EejwLC`).

This proved that the `2026-07-29.preview` version bump did not repair the recipient-only flow and must not be recorded as a successful root-cause fix.

## Intended account model

Pipe Buyer sellers are marketplace recipients for indirect marketplace payments and later server-controlled transfers. They are not direct-charge merchants in this onboarding flow.

The seller payload intentionally uses:

- `dashboard: express`
- `defaults.responsibilities.fees_collector: application`
- `defaults.responsibilities.losses_collector: application`
- `configuration.recipient.capabilities.stripe_balance.stripe_transfers.requested: true`
- recipient-only Account Link onboarding

It intentionally does **not** request Merchant/Card capability.

Stripe's marketplace recipient creation documentation shows this same recipient-only account model using Accounts v2 preview `2026-02-25.preview`. Stripe's recipient Account Link onboarding documentation uses the same preview.

## Corrected repair

- Pin `stripeMarketplaceConfig.connectAccountsApiVersion` to `2026-02-25.preview` for seller Accounts v2 and Account Link requests only.
- Keep the general Stripe integration isolated on `stripeMarketplaceConfig.apiVersion = "2026-06-24.preview"`.
- Do not add `configuration.merchant` or `card_payments` merely to satisfy a preview-specific dependency that conflicts with the intended marketplace recipient architecture.
- Preserve the sanitized Stripe capability diagnostic until the live recipient flow has successfully created an account and opened Stripe-hosted onboarding.

## Regression coverage

`firebase/functions/test/stripe_connect_accounts_api_version.test.js` locks these conditions:

1. seller Connect Accounts v2 uses `2026-02-25.preview`;
2. the Connect Accounts preview remains isolated from other Stripe surfaces;
3. seller onboarding continues to request `stripe_balance.stripe_transfers`;
4. the Account Link remains recipient-only;
5. seller onboarding does not request Merchant/Card capability.

## Do not repeat

- Do not treat `2026-07-29.preview` as the successful fix; the production retry disproved it.
- Do not add merchant/card-payment capabilities to marketplace recipient accounts unless Pipe Buyer's payment architecture changes to direct charges or an approved `on_behalf_of` flow.
- Do not globally upgrade or downgrade every Stripe surface to solve a Connect-only preview mismatch.
- Do not remove platform-owned fees/losses from the recipient configuration; that responsibility model is intentional for Pipe Buyer's marketplace flow.
- Do not perform a real buyer charge, seller transfer, refund, or payout as part of diagnosing seller onboarding unless explicitly approved immediately before the financial action.
