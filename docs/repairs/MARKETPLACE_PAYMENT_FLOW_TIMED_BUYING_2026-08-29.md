# Marketplace payment flow and Timed Buying repair — 2026-08-29

## Scope

Pipe Buyer uses Stripe Connect for physical-goods marketplace payments. This repair covers normal accepted offers, payment actions launched from marketplace chat, Timed Buying winner payment, platform fee retention, delayed seller release, and the production readiness gate used while Pipe Buyer is not yet collecting GST/HST through Stripe.

## Root causes found

1. `createMarketplaceCheckout` existed server-side, but the marketplace chat transaction panel never called it. Users could negotiate and confirm completion but could not start the Pipe Buyer Stripe payment from chat.
2. Timed Buying finalized into `auction_transactions`, while the Stripe checkout and immutable fee pipeline operate on `marketplace_transactions`. A winner therefore had a settlement record but no payable Stripe transaction.
3. Successful Stripe Checkout immediately created the seller Connect transfer. That contradicted Pipe Buyer’s intended physical-goods flow where payment is received first and seller proceeds are released only after fulfillment/receipt confirmation.
4. The marketplace Checkout readiness gate treated `stripeTaxReady` as mandatory and always enabled Stripe automatic tax. Pipe Buyer needs a separately audited tax-collection-deferred mode while registration/business documentation is not finalized; that mode must never impersonate `stripeTaxReady=true`.
5. The refund/dispute engine currently assumes one primary Stripe charge per marketplace transaction. A deposit plus later balance would create multiple charges and make the current refund/dispute mapping ambiguous. Deposit support is therefore intentionally held until the payment-parts ledger and charge-specific recovery logic are added.

## Approved repair architecture

### Normal marketplace purchase

Accepted offer → immutable fee snapshot → buyer taps **Pay securely** in chat → Stripe Checkout platform charge → webhook records `paid` and `sellerPayoutStatus=pending_release` → seller fulfills / buyer receives → both completion confirmations → server creates the Connect transfer using the original Stripe charge as `source_transaction` → transaction becomes financially settled.

The platform fee remains on the Pipe Buyer platform balance. Pipe Buyer does not describe this as escrow or a trust account.

### Timed Buying

Auction finalization remains authoritative for winner and price. A server trigger mirrors the winning settlement into `marketplace_transactions/auction_<listingId>`, allowing the existing fee snapshot and Checkout engine to be reused. The winner sees **Pay winning bid** after finalization. Seller release uses the same delayed-release engine as a normal purchase.

Do not hold a long-lived full card authorization throughout an auction. Winner payment begins after the server finalizes the auction.

### Tax collection mode

A distinct `marketplaceTaxCollectionDeferredApproved` readiness decision may permit checkout with Stripe automatic tax disabled while `stripeTaxReady` remains false. This is an operational configuration, not a legal determination. It must be audited, reversible, and replaced with registered/automatic-tax handling when required.

### Deposits

Deposits are not marked live by this repair. Before enabling them, add a server-owned payment-parts ledger with `full`, `deposit`, and `balance` purposes; cumulative paid amount; per-charge Stripe identifiers; charge-specific refunds/disputes; and explicit deposit terms. Until then the UI must not claim that Pipe Buyer safely supports split/deposit payments.

## Regression rules

- Never add a payment button that accepts client-supplied amount or platform fee.
- Never create the seller transfer from the Checkout-completed webhook for a physical-goods sale.
- Seller release requires a successful Pipe Buyer charge, completed fulfillment state, no refund/dispute/financial hold, and an active Stripe recipient account.
- Timed Buying must reuse the marketplace payment engine after winner finalization; do not create a parallel pricing or fee implementation.
- Never set `stripeTaxReady=true` merely to bypass a readiness gate.
- Never claim deposits are supported until multi-charge refund/dispute accounting is implemented and tested.
