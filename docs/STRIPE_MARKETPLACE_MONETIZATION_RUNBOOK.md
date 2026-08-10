# Pipe Buyer — Stripe Marketplace Monetization Runbook

## Status

Production controls are server-authoritative and fail closed. Enabling Stripe products or having a live Stripe account does not by itself approve every marketplace, tax, refund, dispute, seller-transfer, or affiliate-payout path.

## 1. Core marketplace fee schedule

Authoritative implementation: `firebase/functions/marketplace_fee_policy.js`.

Current schedule revision: `2026-08-10-launch-v3`.

### Pipe / tubing / casing / OCTG

- CA$1 / US$1 per stick or joint sold.
- Minimum Pipe Buyer marketplace fee: $25.
- Maximum Pipe Buyer marketplace fee: $5,000.
- There is no separate percentage cap that can reduce the fee below the $25 minimum.
- The seller is the marketplace-fee payer under the current schedule.

### Equipment / vehicles / buildings / other assets

- Under $10,000: 5%.
- $10,000–$49,999: 3%.
- $50,000–$249,999: 2%.
- $250,000+: 1%.
- Minimum marketplace fee: $25 where configured for the transaction currency.

Every accepted marketplace transaction stores an immutable server-calculated fee snapshot. Later schedule changes do not rewrite an already accepted deal.

## 2. Affiliate program — 5% of positive net eligible Pipe Buyer revenue

Affiliate revenue policy: `2026-08-10-net-revenue-5pct-v1`.

The affiliate share is **5%**, or 500 basis points, of **positive commissionable net Pipe Buyer revenue**. It is never 5% of the buyer/seller asset sale value.

Commissionable revenue may include eligible Pipe Buyer marketplace-fee revenue and paid Dispatch subscription revenue. The affiliate calculation excludes or deducts, as applicable:

- buyer/seller gross merchandise value and seller sale proceeds;
- GST/HST, PST, sales tax, VAT, and other customer tax amounts;
- payment-provider costs that have not been recovered from the seller or another authorized source;
- provisional tax reserves;
- refunds and credits;
- finalized chargeback/dispute losses;
- Dispatch Billing cost reserves;
- other pass-through costs or platform losses assigned by the authoritative revenue policy.

The commission base is floored at zero. If eligible net Pipe Buyer revenue is zero or negative, affiliate commission is zero.

Affiliate commissions remain subject to the existing 30-day refund/dispute hold and financial-recovery rules. Paid affiliate losses caused by later finalized refunds or chargebacks can create an affiliate recovery obligation that is offset against future eligible commission before new cash payout.

Automatic affiliate transfers remain separately controlled by `affiliatePayoutsEnabled`.

## 3. Full on-platform marketplace checkout

Pipe Buyer uses Stripe Separate Charges and Transfers for the current marketplace architecture.

1. Buyer and seller accept the final transaction.
2. Firebase snapshots quantity, negotiated total, currency and Pipe Buyer marketplace fee.
3. Seller must have an active Stripe payout recipient account and no unresolved payout hold.
4. Buyer starts authenticated Stripe Checkout.
5. The signed Stripe webhook confirms payment success.
6. Pipe Buyer retrieves the successful Stripe charge with its expanded balance transaction.
7. The application records the **actual Stripe payment-provider fee** from the balance transaction; it does not estimate a card percentage.
8. The actual provider fee is deducted from seller proceeds before the seller Transfer, to the extent seller proceeds are available.
9. Pipe Buyer's marketplace fee is therefore not silently consumed by card-processing costs on the seller's transaction.
10. The seller Transfer uses the original Stripe charge as `source_transaction` and remains idempotent.
11. The transaction records gross seller proceeds before provider costs, actual provider cost, provider cost recovered from seller proceeds, final seller proceeds, Pipe Buyer marketplace fee and net eligible affiliate-revenue economics.

If Stripe settlement currency does not match the transaction currency, the webhook fails closed for financial review instead of guessing FX economics.

Client code never supplies authoritative seller proceeds, provider costs, Pipe Buyer fee, affiliate commission, tax, or payout values.

## 4. External buyer/seller settlement

Pipe Buyer can support cash, wire, cheque, PO, or another buyer/seller payment settled outside Pipe Buyer.

1. Accepted offer creates the authoritative transaction and fee snapshot.
2. Buyer and seller both confirm external settlement.
3. No buyer-to-seller sale proceeds move through Pipe Buyer.
4. Pipe Buyer bills the seller only for the marketplace fee through Stripe Checkout.
5. The webhook reads the actual Stripe provider fee on that Pipe Buyer fee payment.
6. Any unrecovered provider fee and applicable provisional tax reserve reduce commissionable Pipe Buyer revenue before the 5% affiliate calculation.

This prevents an affiliate payout from being calculated on revenue Pipe Buyer did not actually retain.

## 5. Dispatch subscription economics

Current Stripe products remain CA$25 monthly and CA$300 yearly recurring.

Affiliate commission is not calculated from tax-inclusive invoice totals. The Dispatch revenue base is post-discount and excludes customer tax.

Before calculating the 5% affiliate commission, the implementation deducts:

- the actual Stripe charge fee when the charge/balance transaction is available;
- a conservative 1% Dispatch Billing cost reserve under the current affiliate policy;
- any provisional tax reserve required while a registration is pending.

If a non-zero paid Dispatch invoice does not yet expose provider-cost information, the affiliate record fails closed to financial review rather than paying from unknown gross margin.

Free Dispatch invoices create no affiliate commission.

## 6. Refunds, disputes and negative economics

Refund and dispute automation remains controlled by the dedicated financial-readiness flags.

- A refund does not assume a seller Transfer is automatically reversed; seller recovery is reconciled separately.
- Affiliate commission is adjusted for customer financial exposure.
- Open disputes hold affiliate payout rather than being treated as a finalized loss.
- Finalized refund/lost-dispute exposure can create affiliate recovery obligations.
- Seller proceeds use the actual original seller Transfer amount, including the provider-fee deduction, as the basis for later proportional recovery/restoration.
- Platform-funded refunds remain separately gated.

## 7. Taxes

Customer tax is never affiliate revenue.

The marketplace tax-compliance system separately tracks buyer/seller tax profiles, registration verification, B.C. PST exemption claims, tax recovery holds, transaction-level tax snapshots, and the platform's statutory obligations.

Do not set `stripeTaxReady` merely because Stripe Tax is enabled in the Stripe Dashboard. Applicable tax registrations and effective dates must be valid before full automatic-tax marketplace checkout is enabled.

## 8. Stripe/Firebase secrets

Production Stripe-dependent Firebase Functions use Secret Manager values. Never commit secret values to GitHub, Flutter assets, source files, or CI logs.

Current production secret names include:

- `STRIPE_SECRET_PRODUCTION`
- `STRIPE_WEBHOOK_SECRET`

Local/emulator workflows must use dummy emulator-only secret values, never the production Stripe secret.

## 9. Payment-provider readiness

Server-controlled document:

`platform_configuration/payment_provider_readiness`

Relevant gates include, among others:

- `stripeMode`
- `stripeConnectOnboardingEnabled`
- `stripeCheckoutEnabled`
- `stripeFeeBillingEnabled`
- `stripeSubscriptionsEnabled`
- `stripeWebhookVerified`
- `stripeTaxReady`
- `stripeTaxRegistrationPending`
- `stripeReconciliationReady`
- `marketplaceFinancialResolutionEnabled`
- `marketplaceDisputeAutomationEnabled`
- `marketplaceDisputeEvidenceEnabled`
- `platformFundedRefundOverrideEnabled`
- `affiliatePayoutsEnabled`

These switches remain server-authoritative. Flutter must not hard-code financial readiness.

## 10. Required financial test matrix

### Marketplace fee

- Pipe: $1/stick.
- Pipe minimum: $25.
- Pipe maximum: $5,000.
- CAD and USD schedules.
- Equipment tier boundaries.

### Full marketplace payment

- Stripe charge succeeds.
- Actual balance-transaction provider fee is recorded.
- Seller Transfer equals negotiated seller proceeds less actual provider fee.
- Pipe Buyer fee is preserved after seller Transfer.
- Tax is not included in affiliate revenue.
- Currency mismatch fails closed.
- Duplicate webhook does not duplicate seller Transfer.

### Affiliate

- Direct one-level referral remains immutable.
- Share is exactly 5% / 500 bps.
- GMV never becomes the affiliate base.
- Net eligible revenue cannot be negative.
- Unrecovered provider cost reduces affiliate base.
- Recovered seller provider cost does not reduce Pipe Buyer marketplace-fee revenue a second time.
- Tax reserves reduce the base.
- Refund/chargeback exposure adjusts or voids commission.
- 100%-free Dispatch invoice produces zero commission.
- Paid Dispatch invoice deducts actual provider fee and Billing reserve.
- Missing provider-cost information fails closed.
- Affiliate without payout onboarding remains held.
- Payout idempotency prevents duplicate transfers.

## 11. Accounting controls

For each revenue-producing source, Firestore should retain enough provider-authored data to reconcile to Stripe, including charge/payment intent, balance transaction, provider fee, tax, seller Transfer, marketplace fee, affiliate commissionable revenue and final affiliate commission.

Do not treat gross Stripe collections as Pipe Buyer revenue. Accounting reports must distinguish seller funds, customer taxes, Pipe Buyer fees/subscriptions, payment-provider costs, reserves, refunds, disputes, affiliate liabilities and actual net platform revenue.

## 12. Production rule

A financial path is production-ready only when the code, webhook, Firestore ledger, Stripe provider data and applicable readiness switches agree. If provider cost, tax liability, currency conversion, seller recovery or affiliate economics cannot be determined safely, the path should hold for review rather than pay out from an assumed margin.
