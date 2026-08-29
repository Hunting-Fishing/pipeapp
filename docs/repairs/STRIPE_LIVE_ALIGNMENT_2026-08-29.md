# Stripe Live Alignment Repair — 2026-08-29

Status: implementation branch `stripe-live-integration-2026-08-29`  
Production Stripe account: Pipe Buyer (`acct_1U2QmKDkO07WMXyR`)  
Firebase project: `flutter-flow-pipe`

## Repair rule

This repair records root cause, exact change, and verification so future work does not repeat the same speculative fixes. Full buyer-to-seller marketplace checkout must remain fail-closed until the existing tax/readiness gate is legitimately satisfied.

## Root cause 1 — Dispatch yearly Stripe catalog drift

**Observed**

The current unified live Dispatch product is `prod_V2WkE5D16GhGaD`. Its current recurring yearly price is `price_1U7bTCDkO07WMXyRvLkWVHHu` (`pipe_buyer_dispatch_yearly_cad`, CA$300/year). Source still referenced the older yearly product/price pair.

**Repair**

`firebase/functions/stripe_marketplace_config.js` now maps yearly Dispatch billing to the current unified live product and recurring yearly price.

**Commit**

`67a56b268257158cafc38c6e8c08e8a341bfedc9`

**Verification**

Live Stripe product/price inventory was read from the Pipe Buyer live account and compared directly with the server configuration.

## Root cause 2 — raw banking/tax credentials collected in Flutter

**Observed**

`lib/marketplace/marketplace_payout_settings.dart` collected ACH routing/account numbers, IBAN/SWIFT values and tax IDs and wrote them into user Firestore data. This contradicted the already-implemented Stripe Connect seller-onboarding architecture and unnecessarily expanded Pipe Buyer's sensitive-data scope.

**Repair**

The page was replaced with a simple Stripe Connect seller-payout screen. It calls the existing authenticated Firebase commands:

- `createStripeSellerOnboardingLink`
- `refreshStripeSellerStatus`

Bank, identity and tax details are entered on Stripe-hosted onboarding. Pipe Buyer retains only the connected-account reference and operational readiness/status fields required by the marketplace.

**Commit**

`cba6051afba51a2c162bbabdee036a9910e38cfb`

**Verification**

The replacement client calls the existing server-owned Connect flow in `stripe_marketplace_commands.js`, which creates recipient-focused connected accounts and does not persist the single-use onboarding URL.

## Root cause 3 — safe deploy omitted required billing/readiness callables

**Observed**

The payment backend deployment workflow deployed subscription checkout but did not include the Dispatch catalog, subscription status, or Stripe Customer Portal callable. This could leave production UI and server surfaces on different releases.

**Repair**

`.github/workflows/deploy-payment-backend-safe.yml` now deploys and verifies the full required payment surface, including:

- Dispatch catalog and status
- Dispatch Checkout and Customer Portal
- Stripe seller account/onboarding/status
- marketplace and fee checkout
- refunds/disputes/recovery
- payment-readiness controls

**Commit**

`0dedd3fa48614a2fbc1e2b7d2ce7e840fd500297`

## Root cause 4 — production webhook event drift

**Observed**

The live Stripe endpoint existed and was enabled, but its event list did not include the full subscription lifecycle already implemented by source.

**Repair**

The live Stripe endpoint `we_1U2mXRDkO07WMXyRpm7HCA9z` was updated to match `firebase/functions/stripe_webhook_event_catalog.js`, including:

- `invoice.payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `customer.subscription.paused`
- `customer.subscription.resumed`

The existing checkout, refund and dispute events remain enabled.

**Verification**

The live Stripe API returned the updated event list after mutation.

## Root cause 5 — public Terms/Privacy contradicted live billing architecture

**Observed**

The published-source Terms/Privacy described payments as inactive, claimed Pipe Buyer did not process/route funds, and contained an obsolete Dispatch `$25/year + $10/job` proposal. That conflicted with the live Stripe catalog and current server design.

**Repair**

`web/terms.html` now documents:

- current web Dispatch pricing: CA$25/month and CA$300/year
- current server marketplace fee schedule revision behavior
- Stripe as the payment/onboarding provider
- no Pipe Buyer escrow/trust-account claim
- seller payout onboarding through Stripe
- full buyer-to-seller checkout as a readiness/tax-gated feature
- refund/dispute and subscription lifecycle boundaries

`web/privacy.html` now documents:

- Stripe Checkout/Billing/Connect data flows
- provider identifiers and financial-state metadata Pipe Buyer retains
- raw payment/bank/identity data that Pipe Buyer does not collect through its Stripe flow
- reconciliation, fraud and provider-event uses

**Commits**

- Terms: `95fe7bee2bcf9f15da369f6a11d184da22caee7e`
- Privacy: `cbf37510111a25355e338b9a64a0a601debea3dd`

## Root cause 6 — regression test retained obsolete escrow wording

**Observed**

The first verified production release of merge commit `99fbd56e33d29196a6d8003501869fd51bc51bcf` passed static analysis but stopped at `flutter test`: 436 tests passed and one test failed because `test/marketplace_escrow_test.dart` still expected the old user-facing label `Escrow Secured`. Production code had intentionally changed the label to `Payment Confirmed` as part of removing the false implication that Pipe Buyer operates an escrow or trust account.

**Repair**

The regression test now asserts the current provider-payment labels while retaining legacy internal enum/parser compatibility for historical transaction records:

- `Payment Confirmed`
- `Seller Transfer Completed`
- `Delivery / Inspection Pending`
- `Dispute Under Review`

No Stripe, Firebase, settlement, entitlement, or payment-state logic changed in this repair.

**Verification rule**

Do not restore obsolete escrow wording merely to satisfy an old test. Tests that cover settlement presentation must assert the current legal/product terminology while legacy stored status keys remain backwards compatible.

## Root cause 7 — temporary 2nd-gen HTTP functions were blocked by infrastructure IAM

**Observed**

The corrected production release `376c5184d880ee1f43ef7f156dec65296bd12718` completed all application tests, Firebase security/integration tests, the exact web build, full Firebase production deployment, Function parity, and live visual acceptance. The subsequent tax-pending billing activation failed only when calling the temporary `productionBillingActivation` endpoint. Six requests returned HTTP `401` before the handler could evaluate its one-time bearer token. The endpoint was then deleted successfully by the cleanup step.

The function was a Firebase Functions 2nd-gen `onRequest` endpoint. Without an explicit public invoker, the underlying Cloud Run/Firebase IAM layer rejected the GitHub runner before application-level authorization could run.

**Repair**

The temporary activation endpoint now sets `invoker: "public"` at the Firebase HTTPS-function infrastructure layer while retaining all of its application-level controls:

- POST only
- random one-time 256-bit activation token stored in Secret Manager
- timing-safe bearer-token comparison inside the handler
- exact, hard-coded tax-pending production readiness profile
- verification of the returned profile before success
- deletion of the temporary endpoint immediately after the one authorized write

The same control is applied proactively to the temporary exact-policy publisher used to publish the verified Terms/Privacy hashes, preventing the next release step from failing for the identical infrastructure reason.

**Security boundary**

`invoker: "public"` is used only on these short-lived, token-authenticated release endpoints. It is not a general change to Pipe Buyer callable authorization. Public infrastructure reachability is required so the cryptographic application-level token check can execute; possession of the endpoint URL alone does not authorize the write.

**Verification rule**

When a temporary 2nd-gen HTTP release function is intentionally called from GitHub Actions without Google IAM identity, explicitly define its invoker policy. Do not confuse infrastructure invocation authorization with the function's own application-level authorization. Always retain a one-time secret and cleanup deletion for privileged temporary endpoints.

## Live Stripe verification performed

- Pipe Buyer account is live mode.
- Dispatch monthly recurring price: CA$25/month.
- Dispatch yearly recurring price: CA$300/year.
- `PIPEBUYER_FREE_1Y` is a valid 100% 12-month live coupon.
- `PIPEBUYER_FREE_5Y` is a valid 100% 60-month live coupon.
- Production webhook is enabled and aligned with source lifecycle events.

## Intentionally not bypassed

### Full buyer-to-seller marketplace Checkout

The repository's activation control intentionally keeps `stripeCheckoutEnabled=false` while Canadian tax registration/readiness is pending. This repair does not set `stripeTaxReady=true` without real registration evidence and does not bypass the gate.

The intended launch state before that gate is cleared is:

- Stripe Connect seller onboarding: enabled when production readiness is activated
- Dispatch subscriptions: enabled when production readiness is activated
- marketplace fee billing: enabled when production readiness is activated
- signed Stripe webhook: enabled
- reconciliation controls: enabled
- full buyer-to-seller Checkout: held until tax/readiness approval

### VIP billing

VIP early-access UI exists, but no approved live VIP Stripe product/price was found. No arbitrary real-money VIP price was invented. VIP must receive an approved business price/product before paid Checkout is connected.

## Regression checklist

Before any future payment repair:

1. Compare live Stripe catalog to `stripe_marketplace_config.js`.
2. Confirm the Firebase deployment includes every client-called payment function.
3. Confirm the Stripe webhook event list matches `stripe_webhook_event_catalog.js`.
4. Never collect raw seller banking/tax credentials in Pipe Buyer when Stripe Connect can collect them.
5. Never grant entitlement or mark a marketplace transaction paid from a redirect alone.
6. Never set tax readiness from Stripe Dashboard enablement alone; require actual tax/compliance evidence.
7. Do not remove or deactivate legacy Stripe products/prices until old releases and historical references are dependency-audited.
8. When user-facing payment terminology changes for legal/product accuracy, update its regression tests in the same change; do not revert corrected wording to satisfy stale assertions.
9. For privileged temporary 2nd-gen HTTP release functions called from GitHub Actions, explicitly configure infrastructure invoker access, retain a one-time timing-safe bearer token, and always delete the endpoint immediately after use.
