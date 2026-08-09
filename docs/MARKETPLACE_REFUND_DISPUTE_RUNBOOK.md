# Pipe Buyer Marketplace Refund & Dispute Runbook

Status: production-hardening controls; money movement remains gated by platform configuration.

## Scope

This runbook covers marketplace purchases paid through Pipe Buyer Stripe Checkout using Separate Charges and Transfers. External cash, wire, cheque, purchase-order, or other buyer-to-seller settlements are not automatically refundable by Pipe Buyer because Pipe Buyer never received the underlying sale funds.

## Core financial rule

For Separate Charges and Transfers, refunding the platform charge does not automatically reverse money already transferred to the seller. Pipe Buyer therefore treats buyer refunds and seller recovery as separate ledger operations.

Default approved-refund order:

1. Load the immutable Pipe Buyer marketplace transaction.
2. Re-read the Stripe charge as the payment source of truth.
3. Calculate cumulative buyer exposure from completed refunds plus active/lost disputes.
4. Calculate the seller's required net proceeds proportionally.
5. Reverse seller transfers until the seller's net proceeds match the exposure target.
6. If seller recovery is incomplete, block the refund and place the seller on a payout hold.
7. Only an MFA administrator may bypass the block, and only when `platformFundedRefundOverrideEnabled` is explicitly true.
8. Issue the Stripe refund with an idempotency key.
9. Reconcile the Stripe webhook back into Firestore.
10. Recalculate affiliate commission eligibility/recovery.

## Refund controls

### User request

`requestMarketplaceRefund`

- callable by the transaction buyer or seller
- applies only to a marketplace charge created through Pipe Buyer Stripe Checkout
- supports full or partial requested amounts
- does not move money
- records an immutable financial case and audit event
- refuses a new refund request while a cardholder dispute is open

`cancelMarketplaceRefundRequest`

- requester-only
- allowed only while the request is still in `requested` state

### Admin execution

`executeMarketplaceRefund`

- requires Pipe Buyer administrator claims plus Firebase MFA
- requires `marketplaceFinancialResolutionEnabled`
- requires verified Stripe webhooks and reconciliation readiness
- re-checks Stripe's current refundable balance before acting
- attempts seller recovery before issuing the buyer refund
- uses an idempotent Stripe Refund API call
- supports `requested_by_customer`, `duplicate`, and `fraudulent` Stripe reason values

### Platform-funded override

A refund can proceed before complete seller recovery only when all of the following are true:

- the administrator is MFA authenticated
- the request explicitly sets `allowPlatformFunding=true`
- `platformFundedRefundOverrideEnabled=true`
- the unresolved seller amount remains recorded as an open recovery obligation
- the seller remains payout-held until the obligation is resolved

This override is an exception path, not the default refund workflow.

## Seller funds model

Pipe Buyer tracks seller proceeds across:

- the original seller transfer
- any later restoration transfers after a dispute is won/closed
- transfer reversals against any of those transfers

The system computes **net seller transferred funds**, not merely the reversal amount on the first transfer. This prevents double recovery when a dispute is won, funds are restored, and a later refund or second dispute occurs.

Multiple Stripe disputes can exist against a single payment. Cumulative exposure is capped at the original buyer charge amount.

## Stripe Dashboard/manual refunds

A refund created outside Pipe Buyer still emits Stripe events. `charge.refunded` is treated as authoritative reconciliation input:

- update actual refunded amount
- recalculate cumulative exposure
- attempt seller transfer recovery
- create a financial reconciliation case
- place a seller hold if recovery is incomplete
- reduce or recover affiliate commission as applicable

Do not rely on an administrator manually editing Firestore after a Dashboard refund.

## Failed/pending refunds

Refund objects can have asynchronous status changes for some payment methods.

- `refund.created` / `refund.updated`: update case state
- `refund.failed`: restore seller proceeds that were recovered for a refund that ultimately failed, subject to available platform balance
- `charge.refunded`: reconcile the actual successful refunded amount

A failed refund must never leave the seller permanently underpaid solely because Pipe Buyer reversed their proceeds before the refund attempt.

## Dispute lifecycle

Tracked Stripe events include:

- `charge.dispute.created`
- `charge.dispute.updated`
- `charge.dispute.funds_withdrawn`
- `charge.dispute.closed`
- `charge.dispute.funds_reinstated`

Stripe dispute IDs use the `du_` object prefix.

Each dispute receives its own `marketplace_financial_cases` document. A single marketplace transaction can therefore have multiple dispute cases.

Outcomes:

- `open`: temporary exposure; seller recovery/hold applies
- `lost`: permanent chargeback exposure; seller recovery remains required
- `won`: dispute exposure is removed and seller funds are restored to the correct net level
- `warning_closed`: treated as closed/non-loss exposure and seller funds can be restored

Later funds-reinstated events do not reopen a terminal won/closed dispute because terminal state is derived from Stripe's dispute status rather than event ordering.

## Dispute evidence

Programmatic evidence requires `marketplaceDisputeEvidenceEnabled=true` and an MFA administrator.

### Stage

`stageMarketplaceDisputeEvidence`

- validates an allowlisted set of Stripe evidence fields
- accepts Stripe `file_...` IDs for file-based evidence
- sends `submit=false`
- stores an evidence hash, field list, administrator UID, and timestamp
- can be repeated before final submission

### Final submit

`submitMarketplaceDisputeEvidence`

- requires `confirmFinalSubmission=true`
- refuses submission unless evidence was staged
- re-retrieves the current Stripe dispute
- refuses closed or past-due disputes
- refuses if Stripe already reports a final evidence submission
- sends `submit=true`
- records the final administrator and timestamp

Final evidence submission should be treated as a controlled finance/legal action because card-network dispute evidence generally cannot be replaced after final submission.

### Accept dispute as lost

`acceptMarketplaceDispute`

- requires MFA admin
- requires `confirmIrreversibleLoss=true`
- calls Stripe's dispute close endpoint
- is irreversible

## Affiliate recovery

Marketplace affiliate commissions are recalculated against cumulative buyer exposure.

Before payout:

- unpaid commissions are reduced proportionally
- a fully eliminated unpaid commission is voided
- previously paid commissions create an `affiliate_recovery_obligations` balance
- future affiliate earnings are automatically applied to open recovery obligations before a new payout is sent
- if obligations remain, affiliate payout remains held

No raw bank information is stored by Pipe Buyer; payout destinations remain Stripe connected/recipient accounts.

## Tax handling

Refunds and disputes are not equivalent for tax reporting.

- successful refunds should reconcile through Stripe Tax/reporting for the refunded transaction
- a lost card dispute/chargeback must be flagged `taxReviewRequired=true`
- finance must review the applicable jurisdiction because a chargeback does not necessarily reduce tax liability/reporting in the same way as a refund

Tax registrations and remittance policy remain jurisdiction-specific and require the applicable legal/tax registration to be active before collection.

## Firestore financial collections

Server-authored collections include:

- `marketplace_financial_cases`
- `marketplace_financial_events`
- `marketplace_seller_recovery_obligations`
- `affiliate_recovery_obligations`
- `stripe_webhook_events`

Marketplace users receive high-level financial status through their existing `marketplace_transactions` record. Raw financial cases, provider errors, and administrative decision evidence remain server/admin operational data unless a separately reviewed UI projection is added.

## Activation flags

Keep these false until sandbox evidence is complete:

- `marketplaceFinancialResolutionEnabled`
- `marketplaceDisputeAutomationEnabled`
- `marketplaceDisputeEvidenceEnabled`
- `platformFundedRefundOverrideEnabled`
- `affiliatePayoutsEnabled`

Existing payment gates must also remain satisfied:

- Stripe mode is sandbox/production as intended
- Stripe Checkout enabled
- signed webhook verified
- Stripe Tax ready for the jurisdiction
- reconciliation ready
- `paidFeatures` enabled only in the reviewed release

## Required sandbox scenarios

Before production activation, retain evidence for at least:

1. Full refund before seller payout is withdrawn.
2. Partial refund with proportional seller recovery.
3. Second partial refund on the same charge.
4. Seller transfer reversal failure and payout hold.
5. MFA platform-funded override.
6. Refund API failure after seller recovery, followed by seller restoration.
7. Manual Stripe Dashboard refund reconciliation.
8. Dispute created and seller recovery.
9. Dispute won and seller restoration.
10. Dispute lost and tax-review flag.
11. Funds-reinstated event after dispute close without state reopening.
12. Two disputes on one payment.
13. Staged dispute evidence.
14. Final evidence submission.
15. Explicit acceptance of a dispute as lost.
16. Previously paid affiliate commission recovery.
17. Future affiliate earnings offsetting recovery debt.
18. Duplicate/replayed Stripe webhook events.
19. Out-of-order Stripe dispute events.
20. Firestore security-rule verification that clients cannot author financial states.

## Production principle

No Flutter client action may directly mark a refund completed, a dispute won/lost, seller recovery satisfied, an affiliate debt cleared, or funds released. Stripe events and privileged server commands remain authoritative.
