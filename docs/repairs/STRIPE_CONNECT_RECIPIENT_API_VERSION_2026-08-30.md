# Stripe Connect seller onboarding architecture repair — 2026-08-30

## Scope

Seller payout account creation, Stripe-hosted onboarding links, and seller payout readiness reads only. No buyer charge, refund, transfer, payout release, subscription, webhook, tax, or marketplace fee behavior is changed by this repair.

## Observed production sequence

1. Seller payout onboarding initially failed before Stripe-hosted onboarding opened.
2. Sanitized diagnostics exposed `account_creation_liability_unacknowledged`.
3. The Pipe Buyer platform owner completed Stripe's Connect negative-balance liability acknowledgement.
4. Seller onboarding then returned `capability_not_available_without_other_capability`.
5. Moving Accounts v2 between `2026-07-29.preview` and `2026-02-25.preview` did not solve the production failure.
6. The expanded diagnostic exposed Stripe's exact dependency: `stripe_balance.stripe_transfers` could not be requested without `configuration.merchant_capabilities.card`.
7. Seller onboarding was moved to stable Connect v1, but the first controller-based v1 production retry returned `invalid_request_error` before any connected account was created.
8. A live Stripe read immediately after that retry still returned zero connected accounts, proving the failure remained on `POST /v1/accounts`, not on the Account Link call.

The preview-version attempts and the first controller-heavy v1 request are therefore recorded as disproven repair paths, not successful fixes.

## Root cause refinement

Pipe Buyer uses **separate charges and transfers**: the buyer charge belongs to the Pipe Buyer platform and seller proceeds move later under server-controlled transaction completion and payout-readiness rules.

Stable Connect v1 is the correct API family for that architecture, but the first v1 implementation still over-specified seller creation by sending explicit controller properties and an explicit `transfers` capability request.

Stripe's current Express documentation states that when an Express account omits `capabilities`, Stripe uses the platform's saved **Connect Configuration settings** to request the correct capabilities for the account's country. Stripe also documents that **Transfers / Restricted Capability Access** selects the recipient-service-agreement path for Express accounts.

The platform owner completed and saved that Stripe Configuration setting in the Dashboard. Therefore Pipe Buyer should not duplicate or override the same configuration during account creation unless there is a specific per-account exception.

## Corrected repair

Seller creation now follows Stripe's minimal documented Express path:

- create seller account: `POST /v1/accounts`
- request format: `application/x-www-form-urlencoded`
- API version: `2026-06-24.dahlia`
- send only the authenticated seller email, selected country, and `type=express`
- do **not** send controller overrides during account creation
- do **not** send an explicit `capabilities[transfers][requested]` override during account creation
- allow Stripe's saved Express Configuration settings to select Transfers / Restricted Capability Access and the associated recipient-service-agreement behavior
- create Stripe-hosted onboarding with `POST /v1/account_links`
- read seller readiness with `GET /v1/accounts/{account}`

This keeps Stripe responsible for onboarding/KYC collection while Pipe Buyer remains responsible for the marketplace transaction and later seller transfer flow.

## Diagnostics correction

`invalid_request_error` now preserves only Stripe's sanitized:

- human-readable explanation
- rejected parameter name
- Stripe request reference

Emails, URLs, banking data, tax data, identity data, and raw Stripe payloads are not exposed.

## Readiness correction

A seller is considered payout-ready only when both conditions are true:

1. `capabilities.transfers == active`
2. `payouts_enabled == true`

This prevents an account with incomplete onboarding or no usable payout destination from being reported as ready.

## Regression coverage

`firebase/functions/test/stripe_connect_accounts_api_version.test.js` locks these conditions:

1. seller Connect uses stable v1 rather than Accounts v2 preview;
2. the Connect API version remains isolated from other Stripe payment surfaces;
3. seller creation uses `/v1/accounts` with `type=express`;
4. seller account creation does not reintroduce controller overrides;
5. seller account creation does not reintroduce an explicit `transfers` capability override;
6. seller onboarding uses `/v1/account_links`;
7. no Accounts v2 seller endpoint remains;
8. payout readiness requires both active transfers and payouts enabled.

`firebase/functions/test/stripe_seller_onboarding_error_contract.test.js` also locks sanitized `invalid_request_error` message/parameter/request-reference handling.

## Do not repeat

- Do not treat the `2026-07-29.preview` or `2026-02-25.preview` changes as successful fixes; production retries disproved both.
- Do not add Merchant/Card capability merely to silence a Connect capability dependency while Pipe Buyer continues to use separate charges and transfers.
- Do not duplicate Stripe Express Configuration settings in account-creation parameters unless a specific per-account override has been reviewed and approved.
- Do not use Accounts v2 seller onboarding for the current separate-charges-and-transfers marketplace architecture unless Stripe explicitly adds the required support and the whole flow is re-reviewed.
- Do not change the buyer charge/fee/transfer ledger as part of this seller onboarding repair.
- Do not perform a real buyer charge, transfer, refund, or payout without explicit approval immediately before the financial action.

## Live acceptance

This repair is not considered fully closed until production successfully creates a connected account, opens Stripe-hosted onboarding, and reads the resulting seller readiness through the v1 account status path.
