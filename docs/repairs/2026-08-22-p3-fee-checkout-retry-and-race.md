# Repair Record — P3 External-Settlement Fee Checkout Retry & State Race

Date: 2026-08-22  
Workstream: Payments Execution Tracker #4 / P3 external-settlement Marketplace fee  
Branch: `p3-external-settlement-checkout`  
PR: #95

## Symptoms / risks found

1. External fee Checkout used an idempotency key based only on transaction ID and transaction revision. After an asynchronous Stripe payment failure, retrying could resolve to the same already-used Checkout Session instead of producing a clean payment attempt.
2. Checkout Session creation called Stripe before writing `marketplaceFeeStatus=checkout_created`. A fast Stripe webhook could therefore mark the transaction `processing`, `payment_failed`, or `collected` before the callable performed its final Firestore write. The callable could then overwrite the newer provider-authoritative state back to `checkout_created`.
3. There was no per-attempt audit record for external fee Checkout creation.

## Root cause

The first implementation treated Checkout creation as a single lifetime operation for a transaction and did not model payment attempts independently. It also persisted the post-Stripe state with a blind merge rather than a provider-state-aware Firestore transaction.

## Repair

- Added `external_settlement_fee_checkout_policy.js`.
- Added `external_settlement_fee_provider_policy.js` as the single provider-session/persistence decision layer.
- Added a server-owned `marketplaceFeeCheckoutAttempt` counter.
- Stripe idempotency keys now include the payment attempt number.
- Concurrent requests for the same attempt still share the same Stripe idempotency key.
- `checkout_created` sessions are re-read from Stripe before reuse.
- Open sessions are reused only when the returned URL is a valid Stripe Checkout URL.
- Processing/completed/paid sessions are not duplicated.
- Expired sessions can advance to a new attempt.
- Unknown provider states fail closed for manual review rather than guessing a retry path.
- Failed local payment state can advance to a clean new attempt.
- Inconsistent active state without a valid Stripe Session ID fails closed for review.
- Post-Stripe persistence now runs inside a Firestore transaction.
- The callable refuses to downgrade `collected`, `processing`, or `payment_failed` states written by a faster webhook for the same Session.
- A newer checkout attempt supersedes any stale response from an older provider call.
- Each created attempt is recorded under `marketplace_transactions/{transactionId}/marketplace_fee_checkout_attempts/{attempt}` for reconciliation evidence.
- Stripe Checkout URL host is validated server-side as `https://checkout.stripe.com`.

## Receipt repair

- Added seller-only `getExternalSettlementFeeReceipt` callable.
- The callable re-reads the Stripe Charge instead of trusting Firestore alone.
- It requires Stripe `paid=true`.
- It verifies Charge amount and currency against the stored Pipe Buyer fee total before returning receipt information.
- Only safe receipt fields are returned to the seller.
- Hosted receipt links are restricted to HTTPS Stripe domains.

## User/admin UX added

- Added authenticated user workspace at `/account/settlements`.
- Shows buyer/seller external-settlement confirmation state.
- Seller-only marketplace-fee payment action is enabled only after both confirmations.
- UI distinguishes fee due, checkout open, processing, failed, and paid states.
- Paid seller can open the provider-backed Stripe receipt when available.
- Added MFA-backed admin queue at `/admin/settlement-fees`.
- Admin queue surfaces confirmation pending, fee due, checkout open, processing, failed, paid, tax review, payment-path conflict, and reconciliation state.

## Verification added / executed

- Pure Node tests for attempt numbering, active/inconsistent state, retry generation, and idempotency keys.
- Pure Node tests for receipt URL and amount/currency verification.
- Provider lifecycle policy tests cover open-session reuse, invalid URL refusal, completed/paid processing lock, expired-session retry, unknown-status review, webhook-state preservation, and stale-attempt supersession.
- Focused Node 22 execution verified 11 provider lifecycle assertions with no failures.
- A source-contract test verifies `external_settlement_commands.js` consumes both authoritative provider lifecycle decisions.
- Flutter contract tests cover Checkout lifecycle responses and Stripe URL restrictions.
- Flutter source-contract tests cover user settlement route/controls and admin fee queue states.
- Functions `npm run check` includes the checkout, provider policy, receipt, reconciliation and webhook claim modules.

## Acceptance still required

Do not mark P3 financially complete from this repair record alone.

Required evidence remains:

- Run the repository-wide `tool/verify.ps1` gate from the final P3 commit, including Flutter and Firebase emulator work. Hosted GitHub Actions continue to fail before job startup and are not payment-code evidence.
- Complete a controlled real Stripe fee payment to prove the deployed Checkout/webhook path against provider objects.
- Exercise one intentional failed payment/retry during controlled acceptance.
- Run provider-backed reconciliation and require a zero-difference `balanced` result through the Stripe Balance Transaction.
- Obtain web/mobile visual acceptance before production activation.

## Do not repeat

Do not "fix" failed fee retries by removing Stripe idempotency. The correct repair is attempt-scoped idempotency: one stable key per logical payment attempt, with a new attempt only after the prior attempt is conclusively failed/expired.

Do not write `checkout_created` blindly after the Stripe API returns. The provider webhook may have already advanced the transaction state. Preserve newer provider-authoritative state inside a Firestore transaction.

Do not duplicate provider-status branching in multiple call sites. `external_settlement_fee_provider_policy.js` is now the authoritative provider lifecycle decision layer for fee Checkout reuse/retry and post-provider persistence.
