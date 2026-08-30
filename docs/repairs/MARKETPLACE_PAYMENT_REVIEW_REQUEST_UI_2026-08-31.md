# Marketplace payment review request UX — 2026-08-31

## Scope

This repair closes the launch-readiness gap identified in `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`: buyers and sellers need a simple transaction-level way to report a Pipe Buyer Stripe payment problem and request refund review without giving the Flutter client authority to refund money.

## Existing financial architecture preserved

The server already owns the financial-resolution workflow in `firebase/functions/marketplace_financial_resolution.js`.

`requestMarketplaceRefund`:

- requires an authenticated buyer or seller participant;
- requires a real Pipe Buyer Stripe charge;
- rejects an already-refunded payment and an open cardholder dispute;
- calculates the remaining refundable amount on the server when `amountMinor` is omitted;
- creates `marketplace_financial_cases/{requestId}`;
- sets the marketplace transaction financial state to `refund_requested`;
- records an immutable financial event;
- does not execute a Stripe refund.

Actual refund execution remains an administrator/server financial-resolution action with the existing readiness, reconciliation, dispute, seller-funds recovery, and Stripe controls.

## Root cause

The server workflow existed and was deployed, but the normal buyer/seller transaction experience did not expose it. Users could pay securely, confirm completion, cancel, or open a transaction dispute, but there was no clear post-payment action for a payment problem/refund review.

The missing feature was therefore a controlled UX entry point, not a second refund engine.

## Repair

`MarketplaceSecurePaymentPanel` now:

- exposes `Payment problem / Request refund review` only after `paymentProviderStatus == paid`;
- exposes the action to either transaction participant through the existing transaction panel;
- collects only a bounded reason from the user;
- sends `requestId`, `transactionId`, and `reason` to `requestMarketplaceRefund`;
- deliberately does **not** send `amountMinor`, `stripeChargeId`, platform fee, payout amount, or any other monetary authority from Flutter;
- explains before submission that the request does not guarantee a refund and does not automatically move money;
- shows `Payment review in progress` when `activeFinancialCaseId` or `financialStatus == refund_requested` is present;
- suppresses a new review action while a review is already active or the transaction is already refunded, disputed, or charged back;
- reuses the existing `MarketplaceCommandClient`, diagnostics, Firestore transaction state, and feedback patterns.

The request ID is generated once per mounted payment panel and remains bounded to the server identifier limit. This protects normal repeated taps/retries within the same mounted transaction surface while Firestore remains the source of truth for an active case.

## Regression coverage

`test/marketplace_secure_payment_review_policy_test.dart` covers:

- review unavailable before a successful Pipe Buyer payment;
- review available for a paid transaction with no financial case;
- active review state suppressing another request;
- refunded/disputed/charged-back states suppressing review creation;
- the Flutter payload containing no client-selected monetary amount or Stripe charge ID;
- bounded reason validation;
- bounded slash-free request IDs.

The full repository quality gate must pass before this repair is merged. Production deployment remains a separate exact-SHA action after merge.

## Do not repeat

- Do **not** call the Stripe Refund API from Flutter.
- Do **not** let a buyer or seller provide `amountMinor`, charge IDs, platform fees, seller payout values, or refund execution flags.
- Do **not** create a parallel refund/support collection when `marketplace_financial_cases` already owns financial review.
- Do **not** describe a review request as an approved or guaranteed refund.
- Do **not** issue a refund while a cardholder dispute is open.
- Do **not** weaken seller-funds recovery, reconciliation, webhook, administrator, or readiness gates to make a refund proceed.
- Do **not** describe Pipe Buyer's separate-charge-and-transfer marketplace flow as escrow or trust custody.

## Acceptance state

Implementation is isolated on `repair/marketplace-payment-review-ux-20260831` pending analyzer, targeted test, complete Flutter test suite, pull-request quality checks, merge, and protected production release evidence.
