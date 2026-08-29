# Stripe Live Release Orchestration Addendum — 2026-08-29

This addendum extends `STRIPE_LIVE_ALIGNMENT_2026-08-29.md` with the final release-control repairs discovered before production merge.

## Root cause 6 — marketplace UI claimed Pipe Buyer operated escrow

The auction settlement screen displayed **Pipe Buyer Escrow** and said funds were held until buyer inspection. The actual Stripe architecture is provider payment processing plus platform-controlled transaction/transfer state; Pipe Buyer does not operate an escrow or trust account.

### Repair

- `marketplace_auction_settlement.dart` now labels the section **Payment & settlement** and accurately states that Stripe processes supported payments and seller transfers.
- The legacy internal `EscrowStatus` model remains only for backward compatibility with historical records.
- `formatEscrowStatus` now emits neutral payment/fulfillment/transfer language rather than escrow claims.
- The invoice control no longer implies that the local itemized invoice itself is the payment surface.

Commits:

- `25aa1f6f58fd395690eadf7ac83e98ed6ce9a891`
- `98f0be75a5f1585d6cfa653b363541f1cace678f`

## Root cause 7 — verified deployment, billing activation, and policy publication were separate manual operations

The repository intentionally keeps the full Firebase production release and the tax-pending billing activation behind controlled `workflow_dispatch` workflows. That is a sound release boundary, but it meant a source merge alone would not make the complete Stripe alignment live. It also meant changed Terms/Privacy could be deployed without updating the exact version/hash records used by the in-app policy acceptance system.

### Repair

A one-shot source-controlled workflow was added:

`.github/workflows/release-stripe-live-alignment-2026-08-29.yml`

It runs only when its own file is added/changed on `main` (or when explicitly dispatched later), and performs this sequence:

1. Wait for the gated payment-backend deployment for the exact merge SHA.
2. Dispatch the existing `deploy.yml` verified production release for that exact SHA with App Check enforcement.
3. Wait for the verified Firebase release and visual acceptance to succeed.
4. Dispatch the existing `activate-live-billing-pending-tax.yml` workflow.
5. Verify live `/terms` and `/privacy` bytes exactly match the release source.
6. Compute SHA-256 hashes of those exact live/source documents.
7. Deploy a one-time token-protected policy publisher.
8. Publish `terms_of_service` and `privacy_notice` as version `2026-08-29` with their exact hashes and publication audit events.
9. Delete the temporary policy publication endpoint.

This preserves the required tax posture:

- Stripe mode: production
- Dispatch subscriptions: enabled
- Stripe Connect seller onboarding: enabled
- marketplace fee billing: enabled
- signed webhook: enabled
- reconciliation: enabled
- full buyer-to-seller Checkout: **disabled while Canadian tax registration/readiness is pending**

## Why the policy hash step matters

The application compares every required policy acceptance against both the published `version` and `contentSha256`. A legal document must therefore never be changed at the live URL while its Firestore policy record continues to identify the old bytes. The release orchestrator publishes a new policy record only after the live document matches the exact source hash.

## Future repair rule

Do not recreate this one-shot orchestration for ordinary releases. Normal releases should use the permanent verified release and billing-readiness workflows. This workflow exists to close the current source/live alignment gap in one auditable release and should remain inert unless explicitly changed or dispatched.
