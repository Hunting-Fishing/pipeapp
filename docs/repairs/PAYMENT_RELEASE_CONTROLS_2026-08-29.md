# Payment release controls — 2026-08-29

## Root cause

The marketplace payment implementation was validated, but the production activation workflow still wrote `stripeCheckoutEnabled: false`, and the safe payment deployment list did not include the new Timed Buying mirror and delayed seller-release triggers. Deploying without correcting those release controls could either leave Checkout disabled or activate Checkout without all lifecycle functions deployed.

## Permanent repair

- Production activation uses `marketplaceTaxCollectionDeferredApproved=true`, `stripeTaxReady=false`, and `stripeCheckoutEnabled=true` while registration/name documents are pending.
- Stripe automatic tax remains disabled in this mode; the configuration does not falsely claim tax registration is complete.
- The activation workflow is manual-only and is invoked by the verified release orchestrator after the exact Firebase release succeeds.
- The gated payment backend deploy now includes `updateAuctionTransaction`, `onAuctionTransactionCreatedPaymentMirror`, `onAuctionTransactionUpdatedPaymentMirror`, and `onMarketplaceTransactionUpdatedSellerRelease`.
- The release orchestrator summary records Checkout as active under audited tax-collection deferral instead of held for tax registration.

## Release order invariant

1. Validate and deploy the gated payment backend for the exact release SHA.
2. Run the full verified Firebase production deployment for the same SHA, including App Check enforcement, rules, Functions, web build, integration tests, and visual acceptance.
3. Only after that succeeds, activate live billing/Checkout readiness.
4. Verify live Terms and Privacy bytes and publish their exact hashes.

Do not bypass this ordering for future payment repairs.

## Deposit rule

Deposit/split payments are a separate multi-charge ledger feature. They must not reuse the legacy one-charge transaction fields as the sole financial record. Each deposit/balance charge must have its own immutable payment-part record so refunds and disputes can be attributed correctly.
