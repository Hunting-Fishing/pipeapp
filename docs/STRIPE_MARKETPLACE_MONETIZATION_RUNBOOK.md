# Pipe Buyer — Stripe Marketplace Monetization Runbook

Status: implementation branch only. Do **not** enable production money movement until every production gate in this document is complete.

## 1. User experience model

### Buyers

Buyers remain normal Pipe Buyer users. They do **not** create or log into a separate Stripe account. At checkout, Pipe Buyer sends the authenticated buyer to a Stripe-hosted payment experience or a future embedded payment experience.

### Sellers and affiliates receiving payouts

A user only needs Stripe Connect payout onboarding when Pipe Buyer will send money to that user. Pipe Buyer calls the Stripe Accounts v2 recipient onboarding flow and stores only the Stripe connected-account ID and readiness status. Stripe collects the required identity/business/bank payout data.

The same verified recipient account can be used for seller proceeds and eligible affiliate commission payouts.

## 2. Live Stripe resources created

| Resource | Stripe identifier / behavior |
|---|---|
| Dispatch Monthly CAD | `prod_V2WkE5D16GhGaD` / `price_1U2SYGDkO07WMXyRm6xbprUn` — CA$25 monthly |
| Dispatch Yearly CAD | `prod_V2WsPl25y7Qe6A` / `price_1U2XDVDkO07WMXyRS0eCYKCh` — CA$300 yearly recurring |
| Pipe marketplace fee | `prod_V2cTDvqWIPAZEm` / `price_1U2XEPDkO07WMXyRJciY3faj` — CA$1/stick base reporting product |
| Equipment/assets marketplace fee | `prod_V2cTrDBcQDhMKq` — dynamic amount calculated by Firebase |
| 1 year free Dispatch | coupon `PIPEBUYER_FREE_1Y` — 100% for 12 months |
| 5 years free Dispatch | coupon `PIPEBUYER_FREE_5Y` — 100% for 60 months |

Dispatch products use Stripe tax code `txcd_10103001` (business-use SaaS). Underlying physical marketplace inventory defaults to `txcd_99999999` only as a fallback; more specific category tax codes should be assigned server-side as the listing taxonomy is finalized.

## 3. Launch marketplace fee policy

The server fee schedule in `firebase/functions/marketplace_fee_policy.js` is versioned as `2026-08-09-launch-v1`.

### Pipe / tubing / casing

- Base: CA$1 / US$1 per stick or joint sold.
- Recommended minimum: $25.
- Recommended percentage cap: 3% of final negotiated sale value.
- Recommended absolute cap: $5,000.
- The lower cap can override the minimum on unusually low-value transactions so the platform fee never becomes economically unreasonable relative to the sale.

### Equipment / vehicles / buildings / other assets

- Under $10,000: 5%.
- $10,000–$49,999: 3%.
- $50,000–$249,999: 2%.
- $250,000+: 1%.

Every accepted transaction receives an immutable server-side fee snapshot. Later fee-policy changes do not alter already accepted deals.

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
5. Stripe Tax can calculate tax on Pipe Buyer’s fee once the required registrations and tax-liability configuration are approved.
6. Affiliate commission becomes payable only after Pipe Buyer’s fee clears.

No buyer-to-seller funds move through Pipe Buyer in this path.

## 6. On-platform settlement

The implementation uses Separate Charges and Transfers.

1. Buyer and seller accept the final transaction.
2. Firebase snapshots final quantity, price, currency and marketplace fee.
3. Seller must have an active Stripe recipient `stripe_transfers` capability.
4. Buyer starts Stripe Checkout from the authenticated Pipe Buyer transaction.
5. Stripe confirms the payment through a signed webhook.
6. Pipe Buyer retains its marketplace fee and any tax amount that the approved tax model requires the platform to retain.
7. Firebase creates the seller Transfer using the original Stripe charge as `source_transaction`.
8. Transaction and affiliate ledgers are finalized server-side.

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
5. Use Accounts v2 recipient configuration for new marketplace payout accounts.
6. Use Express Dashboard / Stripe-hosted onboarding unless the embedded onboarding implementation is deliberately chosen later.

## 10. Webhook endpoint

Deploy function:

`stripeMarketplaceWebhook`

Register its final HTTPS URL in Stripe Workbench as a webhook/event destination.

Minimum events currently handled:

- `checkout.session.completed`
- `checkout.session.async_payment_succeeded`
- `checkout.session.async_payment_failed`
- `invoice.paid`
- `charge.refunded`

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

## 14. Production activation order

1. Complete current Pipe Buyer Stripe account identity/liveness verification.
2. Complete B.C. business registration being used for the MVP.
3. Confirm Connect platform responsibilities in Stripe.
4. Deploy the branch to a Firebase sandbox/staging environment.
5. Install `STRIPE_SECRET_KEY` and webhook secret through Secret Manager.
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
