# P3 repair — concurrent Stripe webhook event claim

Date: 2026-08-23  
Scope: Stripe webhook duplicate delivery / concurrency safety  
PR: #95

## Observed defect

The Stripe webhook handler checked `stripe_webhook_events/{eventId}` before processing and wrote `status=processed` only after business handling completed. Two simultaneous deliveries of the same Stripe event could therefore both read the event as not-yet-processed and both enter the financial handler before either wrote the processed marker.

Stable Stripe idempotency protected some downstream provider mutations, but that did not make the webhook event ledger itself a single-owner execution gate.

## Root cause

Webhook deduplication used a non-transactional read-then-process sequence rather than atomically claiming the Stripe event before financial handling.

## Repair

Added:

- `firebase/functions/stripe_webhook_event_claim.js`
- `firebase/functions/stripe_webhook_claim_wrapper.js`
- `firebase/functions/test/stripe_webhook_event_claim.test.js`
- `firebase/functions/test/stripe_webhook_claim_wrapper.test.js`

The production `stripeMarketplaceWebhook` export is now wrapped by a transactional Firestore event claim.

The claim record uses:

- `status=processing`
- monotonically increasing `attempts`
- `processingStartedAt`
- `processingLeaseExpiresAt`

A processed event is never claimed again. A simultaneous delivery while the processing lease is active returns safely without invoking the inner financial handler. A failed event can be reclaimed. A stale `processing` lease can also be reclaimed so a process crash does not permanently strand the event.

Invalid Stripe signatures are rejected before any event claim is written.

The existing inner webhook remains authoritative for provider state transitions, payment settlement, refund/dispute handling, failure recording, and final `processed` state.

## Verification

Focused Node 22 execution in the mounted P3 verification workspace:

- webhook claim policy/wrapper syntax checks: passed
- 10 webhook claim tests: passed
- 0 failed

Coverage includes:

- already-processed duplicate refusal;
- simultaneous in-flight duplicate refusal;
- failed-event retry;
- expired processing-lease recovery;
- attempt incrementing;
- Firestore-like timestamp handling;
- invalid-signature refusal before claim.

## Do not repeat

Do not return to a plain `get event -> run money logic -> set processed` deduplication pattern. Stripe webhook delivery is at-least-once and can be concurrent. Event ownership must be claimed transactionally before financial side effects begin, while retaining stale-lease recovery for crashes.
