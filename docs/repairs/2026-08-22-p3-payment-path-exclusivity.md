# P3 Repair — Marketplace payment-path exclusivity

Date: 2026-08-22  
Workstream: Payments Execution Tracker item #4 / P3 external-settlement fee checkout  
PR: #95  
Status: code repaired; CI and controlled payment acceptance still required

## Observed defect

The external-settlement flow and full Stripe marketplace checkout did not use one shared definition of whether a payment path had already started.

`confirmExternalSettlement` blocked only a paid provider state or an existing Stripe PaymentIntent. A Stripe Checkout Session can exist before the PaymentIntent is persisted in Pipe Buyer state, leaving a window where the transaction could be switched to external settlement after on-platform checkout had already started.

The reverse direction also lacked an explicit guard: `createMarketplaceCheckout` did not reject a transaction after buyer or seller external-settlement confirmation had started.

## Root cause

Payment-path exclusivity was implemented as local checks in separate commands instead of as a shared financial invariant.

## Exact repair

1. Added `firebase/functions/marketplace_payment_path_guard.js`.
2. `hasStartedStripeMarketplaceCheckout` treats any of the following as an active Stripe marketplace path:
   - `paymentMethod == stripe_checkout`
   - Stripe Checkout Session ID
   - Stripe PaymentIntent ID
   - Stripe Charge ID
   - provider status `checkout_created`, `processing`, or `paid`
3. `hasStartedExternalSettlement` treats any of the following as an active external-settlement path:
   - `paymentMethod == external_settlement`
   - buyer confirmation
   - seller confirmation
   - marketplace-fee Checkout Session / PaymentIntent / Charge IDs
   - fee status `pending_collection`, `checkout_created`, `processing`, or `collected`
4. `confirmExternalSettlement` now rejects a transaction once the Stripe marketplace path has started.
5. `createExternalSettlementFeeCheckout` now rejects a Stripe marketplace-path transaction and requires both participant confirmations plus `paymentMethod == external_settlement`.
6. `createMarketplaceCheckout` now rejects a transaction once external settlement has started.
7. Added `firebase/functions/test/marketplace_payment_path_guard.test.js` regression coverage.

## Why this repair is preferred

The invariant is centralized. Future payment commands can reuse the same guard instead of recreating slightly different checks that drift over time.

A failed/abandoned payment path is intentionally not silently switched to the other path. If Pipe Buyer later permits path switching after failure, implement an explicit audited recovery/reset command that first proves the prior provider path is no longer collectible.

## Verification required before merge

- GitHub `Quality` workflow passes Node lint/check/tests.
- Firebase emulator callable integration remains green.
- Existing Flutter analysis/tests/builds remain green.
- Controlled P3 test proves one-party confirmation cannot start fee checkout.
- Controlled P3 test proves both-party confirmation can create exactly one fee Checkout Session.
- Controlled race/retry test proves Stripe and external paths cannot both become active for one transaction.

## Remaining P3 gaps discovered during this pass

Repository search found no Flutter references to the deployed `confirmExternalSettlement` or `createExternalSettlementFeeCheckout` callables. The backend foundation therefore exists without a verified user-facing transaction flow.

Next implementation slice:

1. Add Flutter repository/service methods for both callables.
2. Add buyer/seller external-settlement confirmation state to the transaction/conversation UX.
3. Seller-only `Pay Pipe Buyer fee` action after both confirmations.
4. Launch only the server-returned HTTPS Stripe Checkout URL.
5. Present `pending_collection`, `checkout_created`, `processing`, `payment_failed`, and `collected` states from Firestore/webhook evidence.
6. Add admin unpaid/paid/review state presentation and controlled reconciliation evidence.
