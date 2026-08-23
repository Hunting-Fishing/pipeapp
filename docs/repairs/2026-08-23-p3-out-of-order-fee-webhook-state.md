# P3 repair — out-of-order external-fee webhook state

Date: 2026-08-23  
Scope: External-settlement Marketplace fee webhook ordering  
PR: #95

## Observed defect

The original fee-only webhook failure/processing handlers merged `marketplaceFeeStatus=payment_failed` or `processing` without first comparing the current fee state, Checkout Session, or checkout-attempt number.

That allowed a late/out-of-order event to potentially:

- downgrade an already `collected` fee to `payment_failed` or `processing`;
- apply an old attempt's failure after a newer checkout attempt had started;
- accept a different Stripe Session for the same logical attempt without surfacing an operational conflict;
- move a failed attempt back to `processing` from a late event.

## Root cause

Fee success handling was provider/state aware, but non-success fee webhook transitions were blind merges. The payment attempt model introduced for Checkout retry was not being enforced on webhook failure/processing events.

## Repair

Added `external_settlement_fee_webhook_policy.js` and routed fee-only non-success Checkout events through the transactional webhook claim wrapper before the legacy inner handler.

The guarded transition now uses:

- current `marketplaceFeeStatus`;
- current Stripe fee Session ID;
- current `marketplaceFeeCheckoutAttempt`;
- incoming Stripe Session ID;
- incoming `metadata.checkoutAttempt`;
- requested next state (`processing` or `payment_failed`).

Rules:

- `collected` is terminal for non-success events and cannot be downgraded;
- an event from an older attempt is ignored;
- a late processing event cannot move the same failed attempt back to processing;
- a webhook for a newer attempt may arrive before callable persistence and is allowed to advance state;
- a different Session for the same attempt does not change fee state and instead sets `marketplaceFeeOperationalReviewRequired=true` with conflict evidence;
- guarded non-success events are recorded as processed in `stripe_webhook_events`, including transition action/reason;
- a guarded-transition processing error records the event as failed and returns non-2xx for Stripe retry.

## Verification

Focused Node 22 verification executed:

- webhook transition policy assertions: 9 passed;
- guarded command-level transition assertions: 3 passed;
- 0 failures.

Coverage includes terminal-collected protection, stale-attempt suppression, failed-attempt processing suppression, newer-attempt early webhook handling, same-attempt Session conflict review, and normal processing→failure progression.

## Do not repeat

Do not write fee `processing` or `payment_failed` from a Stripe event without comparing the current server-owned attempt and Session. Provider events are at-least-once and can arrive out of order. `collected` must remain terminal for non-success events, and stale attempts must never override newer payment state.
