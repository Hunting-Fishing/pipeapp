# Pipe Buyer — Stripe Marketplace Monetization Runbook

Status: implementation branch only. Do **not** enable production money movement until every production gate in this document is complete.

## 1. User experience model

### Buyers

Buyers remain normal Pipe Buyer users. They do **not** create or log into a separate Stripe account. At checkout, Pipe Buyer sends the authenticated buyer to a Stripe-hosted payment experience or a future embedded payment experience.

### Sellers and affiliates receiving payouts

A user only needs Stripe Connect payout onboarding when Pipe Buyer will send money to that user. The current implementation creates a minimal Connect v1 Express account and stores only the connected-account ID and readiness status. Stripe-hosted onboarding collects the required identity, business, and bank payout data. Revalidate this deliberately pinned API choice against the current Stripe account configuration and supported cross-border flow before production activation; do not silently switch account models during launch.

The same verified recipient account can be used for seller proceeds and eligible affiliate commission payouts.

## 2. Live Stripe resources created

| Resource | Stripe identifier / behavior |
|---|---|
| Dispatch Monthly CAD | `prod_V2WkE5D16GhGaD` / `price_1U2SYGDkO07WMXyRm6xbprUn` — CA$25 monthly |
| Dispatch Yearly CAD | `prod_V2WkE5D16GhGaD` / `price_1U7bTCDkO07WMXyRvLkWVHHu` — CA$300 yearly recurring |
| Pipe marketplace fee | `prod_V2cTDvqWIPAZEm` / `price_1U2XEPDkO07WMXyRJciY3faj` — CA$1/stick base reporting product |
| Equipment/assets marketplace fee | `prod_V2cTrDBcQDhMKq` — dynamic amount calculated by Firebase |
| 1 year free Dispatch | coupon `PIPEBUYER_FREE_1Y` — 100% for 12 months |
| 5 years free Dispatch | coupon `PIPEBUYER_FREE_5Y` — 100% for 60 months |

Dispatch products use Stripe tax code `txcd_10103001` (business-use SaaS). Underlying physical marketplace inventory defaults to `txcd_99999999` only as a fallback; more specific category tax codes should be assigned server-side as the listing taxonomy is finalized.

## 3. Launch marketplace fee policy

The server fee schedule in `firebase/functions/marketplace_fee_policy.js` is
versioned as `2026-10-16-sale-only-v4` with collection timing
`sale_payment`.

- Marketplace and auction listings have no upfront listing fee.
- For an on-platform sale, the seller fee is collected when the buyer's payment
  succeeds. Seller proceeds remain `pending_release` while physical fulfillment
  is pending and are transferred only after completion and financial release
  checks pass.
- For an approved external-settlement sale, no buyer proceeds move through Pipe
  Buyer; the seller pays the separately invoiced fee after both parties confirm
  the external settlement.
- Timed Buying sales and accepted Marketplace offers use the same server-owned
  fee policy; a client cannot choose a cheaper fee path.
- Wanted Ads are discovery only. A match must become a Marketplace offer or a
  Timed Buying listing; a Wanted Ad cannot create a transaction, payment, fee,
  or third settlement path.
- New Marketplace and Timed Buying listings are USD-only. Legacy accepted
  records retain their original currency and immutable fee snapshot.
- Sale-forming price bases are total or server-verifiable whole-item counts.
  Measured-area/length, bundle, lease, and call-for-price labels are discovery
  fields for Wanted Ads only until an authoritative measurement snapshot is
  implemented. Malformed legacy terms fail closed rather than being guessed.
- Every accepted transaction receives an immutable server-side fee snapshot.
  The v4 schedule applies only to newly accepted transactions after deployment;
  later policy changes do not rewrite earlier snapshots.
- Every listing starts on equipment pricing. Seller-selected category,
  product type, title, and embedded fee fields are non-authoritative. Pipe
  pricing requires a separate `marketplace_fee_classifications/{listingId}`
  record written by the MFA administrator callable with source
  `administrator_approved_catalog`, tied to the same seller, catalog values,
  and listing revision. Missing, revoked, stale, or mismatched approval records
  fail closed to equipment pricing.

### Pipe / tubing / casing

- Eligibility requires the current server-only administrator approval above;
  catalog selection by the seller is necessary for review but never sufficient.
- Base: CA$1 / US$1 per stick or joint sold.
- Percentage cap: 3% of the agreed sale value.
- Absolute cap: CA$2,500 / US$2,500.
- The charged amount is the lowest of the per-item calculation, the 3% cap,
  and the absolute cap. The fair-value cap can therefore produce a fee below
  $1 on an unusually small sale.

### Equipment / vehicles / buildings / other assets

The percentages are progressive marginal brackets, not one percentage applied
to the entire sale:

| Portion of agreed sale price | Fee on that portion |
| --- | ---: |
| First $5,000 | 3.0% |
| Over $5,000 through $25,000 | 2.5% |
| Over $25,000 through $100,000 | 2.0% |
| Over $100,000 through $250,000 | 1.5% |
| Over $250,000 | 1.0% |

The overall equipment fee has a CA$1 / US$1 minimum, a CA$2,500 / US$2,500
maximum, and can never exceed the agreed sale amount. Marginal calculation
avoids a fee jump when a sale crosses a bracket boundary.

## 4. Affiliate program

Launch structure: direct one-level referral only.

- Marketplace commission: 20% of Pipe Buyer’s marketplace fee.
- Dispatch commission: 20% of the paid subscription amount after discounts, excluding tax.
- Free invoices generate no affiliate commission.
- Affiliate commission never uses the seller’s full asset sale as its calculation base.
- Marketplace commissions are created only after an accepted marketplace transaction exists.
- Commissions stay in a 30-day refund/dispute hold state after Pipe Buyer actually receives the qualifying platform fee or subscription payment.
- A refunded source charge voids an unpaid commission when the Stripe charge can be matched.
- Automatic affiliate transfers are controlled by `affiliatePayoutsEnabled` and are disabled until explicitly approved.

## 5. External settlement

Pipe Buyer can allow cash, wire, cheque, PO or other negotiated settlement outside Stripe.

1. Accepted offer creates the authoritative transaction and fee snapshot.
2. Buyer and seller each confirm external settlement in Pipe Buyer.
3. Pipe Buyer records the transaction as externally settled/agreed.
4. The seller is billed only the Pipe Buyer marketplace fee through a separate Stripe Checkout Session.
5. The sale cannot be completed until that marketplace fee is confirmed as collected by the signed Stripe webhook.
6. Before both-party agreement or any Stripe/fee activity, either participant can withdraw a one-sided external-settlement choice; the server advances the settlement generation so stale attempts cannot revive it.
7. Stripe Tax can calculate tax on Pipe Buyer’s fee once the required registrations and tax-liability configuration are approved.
8. Affiliate commission becomes payable only after Pipe Buyer’s fee clears.

No buyer-to-seller funds move through Pipe Buyer in this path.

## 6. On-platform settlement

The implementation uses Separate Charges and Transfers.

1. Buyer and seller accept the final transaction.
2. Firebase snapshots final quantity, price, currency and marketplace fee.
3. Seller must have an active Stripe recipient `stripe_transfers` capability.
4. Buyer starts Stripe Checkout from the authenticated Pipe Buyer transaction.
5. The server transactionally reserves one settlement mode and a stable
   checkout attempt/idempotency key; retries reuse that attempt and cannot race
   an external-settlement choice.
6. Stripe confirms the buyer payment through a signed webhook. The webhook
   must match the active transaction, session, checkout attempt, settlement
   generation, amount, currency, and immutable fee snapshot before it can
   advance payment state.
7. Pipe Buyer records the seller fee as collected and retains any tax amount
   that the approved tax model requires the platform to retain.
8. Seller proceeds remain `pending_release`; no seller Transfer is created
   merely because buyer payment succeeded.
9. After confirmed physical fulfillment, Firebase rechecks payment, dispute,
   refund, financial-hold, and recipient readiness state.
10. Firebase creates the seller Transfer exactly once using the original Stripe
   charge as `source_transaction`, then finalizes the transaction and affiliate
   ledgers server-side.

A transaction cannot be marked completed merely because its provider status
once became paid. The server also requires the snapshotted seller fee to be
collected and rejects completion while reconciliation, refund exposure,
dispute/chargeback state, or any financial hold is present.

Client code can never provide authoritative price, tax, commission, seller-proceeds or payout values.

## 7. Firebase secrets

Create these with Firebase / Google Cloud Secret Manager. Never commit their values.

- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`

The functions bind the secrets only to Stripe-dependent functions.

For local emulation use Firebase-supported local secret handling; do not add live secrets to `.env.example`, source code, Flutter assets or GitHub Actions logs.

## 8. Firestore production readiness document

Create/maintain this server-controlled document:

`platform_configuration/payment_provider_readiness`

Recommended initial values:

```json
{
  "stripeMode": "disabled",
  "stripeConnectOnboardingEnabled": false,
  "stripeCheckoutEnabled": false,
  "stripeSubscriptionsEnabled": false,
  "stripeWebhookVerified": false,
  "stripeTaxReady": false,
  "stripeReconciliationReady": false,
  "affiliatePayoutsEnabled": false,
  "connectReturnUrl": "https://pipebuyer.com/payments/connect/return",
  "connectRefreshUrl": "https://pipebuyer.com/payments/connect/refresh",
  "checkoutSuccessUrl": "https://pipebuyer.com/payments/success",
  "checkoutCancelUrl": "https://pipebuyer.com/payments/cancel"
}
```

URLs can be changed to the final deployed Pipe Buyer routes, but the server validates that they use HTTPS on `pipebuyer.com` or a subdomain.

The existing `phase1_feature_flags` paid-features flag also remains false until launch approval.

## 9. Stripe Connect platform setup

Before creating live connected accounts:

1. Open Stripe Connect / platform settings.
2. Complete the platform profile.
3. Review and acknowledge that Pipe Buyer owns platform pricing and negative-balance/loss responsibility for the marketplace charge model.
4. Enable Radar / marketplace fraud controls appropriate to the risk profile.
5. Confirm the current Connect v1 Express configuration still supports the
   chosen separate-charges-and-transfers and cross-border payout model. Any
   future Accounts v2 migration requires a separately tested design change.
6. Use Express Dashboard / Stripe-hosted onboarding unless the embedded onboarding implementation is deliberately chosen later.

## 10. Webhook endpoint

Deploy function:

`stripeMarketplaceWebhook`

Register its final HTTPS URL in Stripe Workbench as a webhook/event destination.

Minimum events currently handled:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `checkout.session.expired`
- `invoice.paid`
- `charge.refunded`
- `refund.created`
- `refund.updated`
- `refund.failed`
- `charge.dispute.created`
- `charge.dispute.updated`
- `charge.dispute.closed`
- `charge.dispute.funds_withdrawn`
- `charge.dispute.funds_reinstated`

The webhook verifies Stripe’s signature against the raw request body and records processed event IDs in `stripe_webhook_events` for idempotency.

After an end-to-end sandbox test proves the webhook signature and event processing are correct, set `stripeWebhookVerified: true`.

## 11. Tax activation gate

Do not set `stripeTaxReady: true` merely because Stripe Tax is enabled in the Dashboard.

Before production marketplace checkout, confirm:

- Which entity is liable to collect GST/HST for each marketplace transaction pattern.
- Treatment of registered versus non-registered sellers.
- B.C. PST treatment of Pipe Buyer marketplace/SaaS fees and any B.C. facilitated sales.
- Which government registrations are actually active.
- Correct product/listing tax codes.
- Tax retention/remittance and reporting process.

Add Stripe Tax registrations only after the legal registration exists with the relevant authority.

## 12. Payment-method policy

- Card: good default for subscriptions and smaller sales; can be uneconomic for six-figure industrial transactions.
- Canadian PAD / ACSS: supported for one-time Checkout payments but delayed and disputable; do not release seller proceeds until Stripe confirms success.
- Bank transfer / invoicing: evaluate for large B2B transactions and procurement workflows.
- PayPal: not currently available through the Canada-based Stripe account; keep it as a separate future payment-provider module if required.

Never hard-code a card surcharge without a separate legal/card-network review for every applicable jurisdiction.

## 13. Required sandbox test matrix

Do not switch to production until all tests pass.

### Seller onboarding

- Canadian individual recipient.
- Canadian business recipient.
- U.S. recipient in supported cross-border configuration.
- Missing requirements / restricted capability.
- Expired Account Link regeneration.

### Marketplace payment

- Card succeeds.
- Card declines.
- Asynchronous bank payment succeeds.
- Asynchronous bank payment fails.
- Duplicate webhook event.
- Duplicate checkout creation attempt.
- Seller transfer succeeds exactly once.
- No transfer occurs before payment success.
- A successful buyer payment collects the seller fee but does not release seller
  proceeds before fulfillment is confirmed.
- Final sale price/quantity cannot be modified by the Flutter client.

### External settlement

- Only one party confirms — no fee checkout.
- Both parties confirm — seller fee checkout allowed.
- Fee payment succeeds.
- Fee payment fails.
- No seller proceeds transfer occurs for fee-only Checkout.

### Affiliate

- Direct referral is immutable.
- Self-referral rejected.
- Marketplace commission uses platform fee, never GMV.
- 100%-free Dispatch invoice creates zero commission.
- Paid recurring Dispatch invoice creates 20% commission.
- Refund before payout voids unpaid commission.
- Affiliate without payout onboarding is held as `eligible_payout_setup_required`.
- Affiliate payout idempotency prevents duplicate Transfer.

### Recovery and ordering

- Checkout response is lost after Stripe may have created the Session — retry
  reuses the same immutable attempt and idempotency key.
- Checkout Session expires — only the currently reserved attempt is released;
  a stale expiration cannot erase a replacement or downgrade paid/refunded
  state.
- Refund or dispute arrives before Checkout completion — later settlement
  imports the current Charge state and must not mark refunded or disputed funds
  payable.
- Refund state updates share a Stripe timestamp — terminal success/failure
  outranks pending state and event IDs provide deterministic ordering.
- Seller or affiliate transfer response is lost — retry uses the exact reserved
  amount, currency, destination, source charge, and idempotency key.
- Refund/dispute races a transfer — financial-epoch and dispatch-lease checks
  prevent stale finalization; a transfer that escaped the race receives a
  durable compensating reversal/hold instead of being treated as payable.

## 14. Production activation order

1. Complete current Pipe Buyer Stripe account identity/liveness verification.
2. Complete B.C. business registration being used for the MVP.
3. Confirm Connect platform responsibilities in Stripe.
4. Deploy the branch to a Firebase sandbox/staging environment.
5. Install sandbox-only `STRIPE_SECRET_KEY` and webhook secret through Secret
   Manager. Use an isolated project, webhook destination, environment stamp,
   and tester cohort; sandbox events must fail closed against production data.
6. Set callback/checkout URLs.
7. Enable `stripeConnectOnboardingEnabled` in sandbox and test seller onboarding.
8. Register and verify the Stripe webhook endpoint.
9. Run the full sandbox test matrix.
10. Finalize tax registration/liability decision and set `stripeTaxReady` only when valid.
11. Set `stripeReconciliationReady` after accounting/ledger tests reconcile to Stripe.
12. Enable Dispatch subscription checkout if desired.
13. Enable marketplace checkout.
14. Enable affiliate payouts only after accounting/tax-reporting treatment and refund policy are approved.
15. Change `stripeMode` to production only after explicit go-live approval.

Before steps 13-15, approve a high-value payment-method and margin policy.
Full-GMV card processing on a six-figure sale can cost more than the capped
seller fee. Do not enable that path until its processor cost, dispute exposure,
and cross-border settlement economics are proven; the fee-only external-
settlement path remains the safer default for large B2B transactions.

## 15. Files added by this implementation

- `marketplace_fee_policy.js`
- `marketplace_monetization.js`
- `affiliate_commands.js`
- `affiliate_payouts.js`
- `stripe_marketplace_config.js`
- `stripe_marketplace_commands.js`
- `stripe_checkout_commands.js`
- `external_settlement_commands.js`
- `dispatch_subscription_commands.js`
- `subscription_monetization.js`
- `stripe_webhook.js`
- `bootstrap.js`
- related unit tests

The implementation is intentionally fail-closed. Creating code and Stripe resources is not the same as approving live custody, tax collection or payouts.
