# Stripe integration closure — 2026-08-29

## Scope

This repair closes two launch-critical integration gaps found during the end-to-end Stripe inspection without redesigning the established payment architecture.

## Repair 1 — seller payout status permission failure

### Symptom

`MarketplacePayoutSettingsPage` subscribed directly to `payment_provider_accounts/{uid}` in Firestore. That provider-account collection is intentionally server-owned and has no client read rule, so the payout screen could encounter `permission-denied` even when Stripe onboarding had succeeded.

### Root cause

The UI was reading an internal provider record instead of using the authenticated Firebase command surface that already owns Stripe account access.

### Repair

- Removed the direct Firestore read from the payout settings page.
- Payout status is now obtained with the authenticated `refreshStripeSellerStatus` command.
- Stripe onboarding continues through `createStripeSellerOnboardingLink`.
- The returned onboarding URL is accepted only when it is HTTPS and the host is `stripe.com` or a Stripe subdomain.
- The provider account remains server-private; no Firestore rule was loosened.

### Do not repeat

Do **not** add a client read of `payment_provider_accounts` merely to show payout status. Extend the authenticated server status response if the UI later needs another safe field.

## Repair 2 — native hosted subscription bypass

### Symptom

The dedicated Dispatch membership page correctly disabled hosted Stripe subscription purchasing on native builds, but the Account → Memberships dialog used separate VIP and Dispatch checkout widgets that could still launch Stripe externally on native.

### Root cause

Hosted-subscription eligibility was enforced independently by multiple UI surfaces.

### Repair

- Added `marketplace_subscription_billing_policy.dart` as the shared hosted-membership billing policy.
- Hosted VIP and Dispatch subscription checkout is allowed only on web in the current release.
- Native builds can still display existing active membership status, but cannot open hosted Stripe checkout or provider billing-management actions from these widgets.
- Defensive guards were added inside checkout/management action methods so a later button refactor cannot bypass the UI state.
- Existing server-side subscription verification remains unchanged.

### Do not repeat

Do **not** create another VIP or Dispatch purchase button that calls Stripe directly without consulting `marketplaceHostedMembershipBillingAllowed()`.

## Regression coverage

Added contract tests for:

- web vs native hosted-membership billing policy;
- payout UI remaining free of direct `payment_provider_accounts` reads;
- payout onboarding continuing to use authenticated commands and Stripe host validation;
- both VIP and Dispatch checkout widgets sharing the native billing guard.

## Architecture intentionally unchanged

The following established behavior is not changed by this repair:

- accepted-offer and Timed Buying marketplace payments use server-authoritative Stripe Checkout;
- marketplace fees are calculated server-side;
- seller proceeds are released later through Stripe Connect after transaction completion/readiness checks;
- signed Stripe webhooks remain authoritative for payment/subscription events;
- deposits/split payments, automatic affiliate payouts, automatic dispute resolution, and unapproved tax automation remain behind their existing safety gates.

## Follow-up items

- Replace stale Account Settings copy that still refers to bank routing/account numbers and escrow releases. The payout page itself is already Stripe-hosted and does not collect bank details.
- Run the full validation/CI suite for this branch and merge only if green.
- Deploy the merged exact SHA through the normal protected Firebase release path, then verify the corrected About/Terms/Privacy and payment surfaces in production.
- Add a controlled buyer/seller payment-problem/refund-request UI on top of the existing server financial-case workflow.
- Design Dispatch job payment as a separate server-owned freight ledger before enabling transaction fees on awarded hauling jobs.
