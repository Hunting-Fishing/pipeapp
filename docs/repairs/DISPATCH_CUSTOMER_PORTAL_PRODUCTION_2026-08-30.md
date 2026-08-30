# Dispatch Customer Portal Production Activation — 2026-08-30

## Inspection finding

The Dispatch subscription UI and backend already contained a guarded Stripe Customer Portal flow, but production payment readiness had never enabled it. The live Stripe account had one default Customer Portal configuration, and that default configuration allowed subscription price changes.

Pipe Buyer's backend intentionally rejects a portal configuration when `features.subscription_update.enabled` is true. That boundary prevents a customer from switching monthly/yearly prices through a provider surface that bypasses Pipe Buyer's plan, tax, policy, and checkout controls.

Therefore the correct repair is **not** to point Pipe Buyer at the permissive default portal and **not** to relax the backend approval check.

## Repair

A production-only activation workflow creates or reuses a dedicated live Stripe Customer Portal configuration identified by metadata:

- `app=pipe_buyer`
- `surface=dispatch`
- `policy_version=dispatch_portal_v1`

The dedicated configuration must be live and active and is restricted to:

- customer billing/contact updates;
- invoice history;
- payment-method updates;
- subscription cancellation at the natural period end;
- no cancellation proration; and
- **no subscription price/plan updates**.

Its default return URL is:

`https://www.pipebuyer.com/payments/dispatch`

The workflow then performs a narrowly scoped, audited Firebase readiness update setting only:

- `stripeDispatchPortalEnabled=true`
- `stripeDispatchPortalConfigurationId=<verified bpc_ id>`
- `dispatchPortalReturnUrl=https://www.pipebuyer.com/payments/dispatch`

All existing payment, tax, marketplace, VIP, Connect, refund, dispute, and payout readiness fields are preserved.

## First activation attempt — exact failure and root cause

The first production activation run successfully:

- validated the approved Pipe Buyer portal runtime;
- passed the complete Firebase Functions lint/check suite;
- verified the live Pipe Buyer Stripe account;
- created and verified the dedicated restricted Stripe portal configuration;
- deployed the one-time token-protected Firebase activator; and
- deleted the temporary activator during cleanup.

The authorized readiness write returned `403 Forbidden` and therefore did **not** change Firebase portal readiness.

This was not a Stripe configuration failure and it was not a reason to relax the token guard. The repository already contained the exact earlier failure pattern from the Stripe live-alignment work: the workflow created its secret file using:

`openssl rand -hex 32 > .dispatch-portal-activation-token`

`openssl rand -hex 32` emits 64 hexadecimal characters followed by a newline. `functions:secrets:set --data-file` can publish that newline as part of the secret, while Bash command substitution later loads the caller token with `$(cat file)`, which removes trailing newlines. The handler intentionally requires equal byte lengths before `crypto.timingSafeEqual`, so the request correctly failed closed.

### Corrected token repair

The workflow now reuses the previously proven canonical one-time-secret pattern:

1. generate the token into a shell variable;
2. require it to match `^[0-9a-f]{64}$`;
3. write it with `printf '%s'` so no newline is added;
4. verify the secret file is exactly 64 bytes before publishing it to Firebase Secret Manager;
5. continue using the dedicated `X-PipeBuyer-Dispatch-Portal-Token` header rather than the reserved HTTP `Authorization` channel;
6. prove the deployed handler returns the exact application-level unauthenticated `403 Forbidden` before sending the authorized request; and
7. delete the temporary endpoint after the authorized operation.

This is a byte-canonicalization repair only. It does not weaken authentication, change Stripe portal restrictions, or broaden the Firebase readiness write.

## Safety controls

Before any configuration write, the workflow verifies:

1. the approved restricted portal runtime remains present in the repository;
2. Firebase's production Stripe secret belongs to the live Pipe Buyer Stripe platform account;
3. Stripe is in live mode;
4. an existing dedicated Dispatch portal configuration, if found, already satisfies the approved restrictions; otherwise the workflow fails rather than silently weakening it;
5. production readiness still has live subscriptions, verified webhooks, and reconciliation readiness enabled; and
6. the temporary Firebase activator rejects an unauthenticated probe before the one-time token is used.

The temporary activation function and local credential files are deleted after the audited update.

## Why this is separate from promo codes

Customer-entered promotion codes before checkout and post-purchase promotion application use dedicated authenticated callables. They do not require Customer Portal and do not depend on the portal being enabled.

The portal repair completes adjacent subscription-management UX so a future active Dispatch subscriber can update a payment method or cancel renewal without exposing general plan switching.

## Do not repeat

- Do not enable Pipe Buyer against Stripe's default portal configuration unless it independently satisfies `portalConfigurationApproved()`.
- Do not relax `subscriptionUpdate.enabled !== true` in `dispatch_subscription_portal.js` to make an unsafe portal configuration pass.
- Do not allow Stripe Customer Portal price switching as a shortcut for monthly/yearly plan changes.
- Do not overwrite the full `payment_provider_readiness` document merely to enable the portal; update only the three portal fields and preserve the current safety profile.
- Do not create a charge, refund, transfer, payout, or subscription while verifying portal setup.
- Do not store Stripe Customer Portal session URLs in Firestore; they remain short-lived authenticated URLs returned only to the signed-in caller.
- Do not create one-time Secret Manager files with shell redirection from commands that emit trailing newlines. Canonicalize the token, write exact bytes with `printf`, and verify the byte count before publishing.
- Do not interpret an application-level `403 Forbidden` from the timing-safe token comparison as a reason to disable or bypass authentication.
