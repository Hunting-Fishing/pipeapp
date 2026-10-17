# Recommended Connect integration

## A. Account configuration

- Accounts API: `/v2/core/accounts`
- Legacy account `type`: not used for new connected accounts
- Dashboard: Express (lightweight view for sellers) (`dashboard: "express"`)
- Fee collection: Pipe Buyer manages pricing (`fees_collector: "application"`)
- Negative balance liability: Pipe Buyer (`losses_collector: "application"`)
- Default settlement currency: USD

This configuration fits Pipe Buyer because it operates the buyer checkout and
controls delivery-gated release of seller proceeds. Each new connected account
needs recipient configuration (`configuration.recipient`) with
`stripe_transfers` on `stripe_balance` requested, so the account can receive
transfers from Pipe Buyer. Marketplace connected accounts must not request
merchant configuration or the `card_payments` capability because they do not
accept direct charges.

Existing legacy connected accounts remain usable during a controlled migration,
but every new seller account must use Accounts v2 and the explicit settings
above.

## B. Charge pattern: separate charges and transfers

Pipe Buyer charges the buyer on the platform account and releases seller
proceeds only after the server-recorded completion safeguards pass. The seller
transfer uses the original charge as its source transaction, and transfer math
retains Pipe Buyer's fee. `application_fee_amount` is not used with this charge
pattern.

## C. Seller onboarding flow

Onboarding method: Stripe-hosted or embedded onboarding, with Express Dashboard
access.

1. A verified Pipe Buyer seller requests payout onboarding.
2. The server creates or retrieves an Accounts v2 recipient connected account.
3. Stripe collects identity, business, tax and bank information.
4. Pipe Buyer re-reads the account from Stripe after onboarding and whenever
   account requirements change.
5. Checkout and transfers remain unavailable until
   `configuration.recipient.capabilities.stripe_balance.stripe_transfers.status`
   and the relevant payouts status are both `active`.
6. Pipe Buyer immediately rechecks Stripe before each Checkout and transfer;
   cached Firestore readiness is never sufficient by itself.

## D. Payments dashboard access for sellers

Sellers open the Express Dashboard through a short-lived login link created by
Pipe Buyer. Native mobile screens continue to show Pipe Buyer payout readiness,
while Stripe-hosted views provide earnings, payout and verification details.

## E. Embedded components

Recommended Connect embedded components for a future web seller workspace:

- `account_onboarding`
- `notification_banner`
- `account_management`
- `payments`
- `payouts`
- `balance_report`
- `payout_reconciliation_report`

With separate charges and transfers, seller payment and dispute detail is
limited in Express. Pipe Buyer therefore remains responsible for the complete
refund, dispute, transfer-reversal and support experience.

## F. Webhook integration

Use signed webhooks as the source of truth for payment, account and payout state,
with raw-body signature verification and idempotent event processing.

## G. Onboarding status gating

Before enabling a payment attempt or seller transfer, retrieve the connected
account and require:

```text
configuration.recipient.capabilities.stripe_balance.stripe_transfers.status == active
configuration.recipient.capabilities.stripe_balance.payouts.status == active
```

Account-state webhooks update the cached UI status, but a fresh provider read is
required at money-movement time.

## H. Fee structure

- Platform fee model: seller-paid, tiered by sale category and value
- Fee calculation: immutable server snapshot at accepted sale commitment
- Fee retention: transfer math, not `application_fee_amount`
- Processing-cost mode: margin-preserving (`stripe_fee_estimate`)

The seller transfer must not exceed:

```text
buyer charge
- Pipe Buyer marketplace fee
- applicable Stripe processing cost that the approved commercial policy assigns to the seller
- refunds, reversals or other authorized adjustments
```

The exact processor cost is provider evidence, not a hard-coded universal
percentage. Rates vary by region and payment method; validate them against
[Stripe pricing](https://stripe.com/pricing) and monitor the Connect margin
report. Full-value card Checkout must fail closed when the immutable transaction
fee cannot cover the approved processing-cost allocation and minimum Pipe Buyer
margin.

```text
Buyer pays the full sale amount
              |
              v
      Pipe Buyer platform charge
         |                 |
         |                 +-- Stripe processing cost
         |
         +-- Pipe Buyer retains the snapshotted marketplace fee
         |
         v
Seller receives the approved net transfer after completion
```

For high-value equipment where card economics are unsuitable, the enabled
product path is external settlement plus a fee-only Stripe Checkout, or another
separately approved low-cost rail. The application must never silently absorb a
large full-GMV processing cost.

## I. SaaS monetization

Not applicable to the Marketplace funds flow. Apple and Google membership
subscriptions remain separate digital-product billing integrations and do not
change seller connected-account configuration.

## J. Implementation plan

1. Create all new seller accounts through Accounts v2 recipient configuration.
2. Add account-state webhook reconciliation and immediate capability rechecks.
3. Keep production Marketplace Checkout and fee billing disabled.
4. Use an isolated Stripe sandbox with a restricted API key stored in Google
   Secret Manager and a separate webhook signing secret.
5. Validate Marketplace accepted-offer, Timed Buying winner, Buy It Now and
   below-reserve acceptance paths.
6. For every path, prove charge, signed webhook, fee snapshot, completion,
   exactly-once seller transfer, refund, dispute, transfer reversal and ledger
   reconciliation.
7. Enforce Firebase App Check and verify an authenticated request without App
   Check is rejected before enabling any payment mutation.
8. Enable production only after tax responsibility, registrations, pricing,
   refund operations and reconciliation are independently approved.

## K. Negative balance liability

Negative balance liability belongs to Pipe Buyer. If a customer disputes a
charge after seller proceeds were transferred, Stripe debits Pipe Buyer's
balance; Pipe Buyer must reverse the seller transfer and the connected account
may go negative. This ownership is required for the selected charge pattern.

## L. Risk management

Pipe Buyer owns transaction risk and uses Stripe Radar, server-side amount and
identity validation, payment holds, idempotency, velocity controls and an
operator exception queue. Negative balance liability and fraud detection remain
separate controls.

## M. Why this fits Pipe Buyer

- Pipe Buyer runs the buyer checkout and payment-support experience.
- Seller proceeds require completion confirmation rather than immediate release.
- Marketplace and Timed Buying converge on one authoritative transaction ledger.
- The platform fee is snapshotted on the server and retained through transfer
  math.
- Express Dashboard access gives sellers payout visibility without making them
  the merchant of record for buyer charges.

## N. Open launch decisions

- A tax adviser must identify whether Pipe Buyer or each seller collects and
  remits transaction tax in each supported jurisdiction before Stripe Tax is
  enabled.
- Stripe must confirm cross-border transfer eligibility country by country;
  worldwide listing visibility does not imply worldwide seller payout support.
- Operations must approve the minimum net margin and which party bears provider
  processing cost for full-value Checkout.
- Production remains disabled until an isolated sandbox evidence package passes
  every payment, refund, dispute and reconciliation gate.
