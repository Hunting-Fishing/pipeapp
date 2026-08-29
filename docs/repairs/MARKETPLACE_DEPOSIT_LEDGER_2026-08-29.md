# Marketplace deposit and balance ledger — 2026-08-29

## Why this is separate from normal Checkout

A deposit is not a smaller version of the existing one-charge payment. It creates multiple financial events for one purchase. Each charge can have its own Stripe PaymentIntent, Charge, refund, dispute, and settlement state. Reusing only the legacy top-level `stripeChargeId` would make refunds, chargebacks, and seller releases ambiguous.

## Permanent architecture

Every split-payment transaction uses an immutable payment plan and a `payment_parts` ledger under the authoritative marketplace transaction.

`marketplace_transactions/{transactionId}/payment_parts/{partId}`

Each payment part records at minimum:
- `partId`: `deposit`, `balance`, or `full`
- `sequence`
- `amountMinor`
- `currency`
- `status`
- Stripe Checkout Session ID
- Stripe PaymentIntent ID
- Stripe Charge ID
- tax collected for that charge
- refunded amount for that charge
- disputed amount/status for that charge
- paid/refunded/disputed timestamps

The parent transaction records aggregates only:
- `paymentPlan`: `full` or `deposit_balance`
- `paymentPlanStatus`
- `paymentRequiredMinor`
- `amountPaidMinor`
- `balanceRemainingMinor`
- `refundedMinor`
- `financialStatus`
- seller payout aggregate status

The payment-part ledger is authoritative for multi-charge payments. Top-level legacy charge fields remain only for backward compatibility with single-charge transactions.

## Marketplace / chat deal flow

For a normal negotiated marketplace purchase, a deposit plan must be an agreed transaction term before any payment begins. A buyer or seller may propose the deposit amount in the transaction chat, but the other party must approve the exact proposal revision before it becomes active. Once any payment part is paid, the plan is immutable.

Flow:
1. Offer accepted and authoritative transaction created.
2. Default payment plan is full payment.
3. Either party may propose `deposit + balance` before payment.
4. Counterparty approves or declines.
5. Once both approve, server creates immutable `deposit` and `balance` parts.
6. Buyer pays deposit through Stripe Checkout.
7. Parent transaction becomes `partially_paid`; no seller transfer is made.
8. Buyer pays remaining balance through a second Stripe Checkout session.
9. Parent transaction becomes `paid`; fulfillment can proceed.
10. Completion confirmations release seller proceeds.

## Timed Buying rule

Timed Buying is different. The winning bidder must not discover a new deposit requirement after winning. Any required deposit terms must be disclosed in the auction/listing terms before bidding starts. The winning transaction inherits those immutable terms when the auction closes.

Until auction-listing deposit terms are implemented and tested, Timed Buying remains full-payment-only after winning. Do not add an after-the-win deposit negotiation shortcut.

## Seller release for split payments

Do not create one transfer tied to one arbitrary charge. Seller proceeds are allocated across the paid charge parts so every transfer has a valid source charge and the Pipe Buyer marketplace fee is deducted exactly once in aggregate.

Recommended deterministic allocation:
- allocate the marketplace fee proportionally across all sale-subtotal payment parts;
- seller transfer for each part = part subtotal minus that part's fee allocation;
- final part receives the rounding remainder so total allocated fee exactly equals the immutable marketplace fee snapshot.

Transfers remain delayed until fulfillment/completion and use Stripe idempotency keys per transaction + part.

## Refunds and disputes

Refund/dispute handling must target payment parts first and then recompute the parent aggregate. Never infer a split-payment refund solely from a top-level charge ID.

A full-transaction refund may require multiple Stripe refunds, one per paid part. Partial refunds must deterministically allocate to specific part(s) and record the allocation in the financial case before execution.

## Release gate

Do not expose a `Pay deposit` button until all of the following are green:
- payment-plan proposal/approval authorization tests
- multi-part Checkout idempotency tests
- webhook settlement tests for deposit and balance
- duplicate webhook/retry tests
- seller release allocation tests
- refund tests across both charges
- charge dispute lookup tests across payment parts
- cancellation/financial-guard tests for partially paid deals
- Flutter analyzer/tests for the chat payment-state UI

This document is the reference architecture; future repairs should extend it rather than introducing a second payment model.
