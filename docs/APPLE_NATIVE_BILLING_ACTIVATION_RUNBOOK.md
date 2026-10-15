# Apple native billing activation runbook

Status: source prerequisites only; production activation is intentionally blocked.

This runbook covers the Pipe Buyer iOS app (`Pipe.Buyerapp`, Apple app ID
`6795847447`) and its approved Dispatch subscription products:

| Product | Price | State for this launch |
| --- | ---: | --- |
| `pipebuyer_dispatch_monthly` | User-approved target USD 25/month; App Store tier USD 24.99/month | Configure and test |
| `pipebuyer_dispatch_yearly` | User-approved target USD 300/year; App Store tier USD 299.99/year | Configure and test |
| `pipebuyer_vip_monthly` | Not approved | Do not configure or expose on Apple |

The Google Play catalog remains independent. Do not remove or rename a Google
product merely because it is not approved for Apple.

## Current fail-closed state

- `production_bootstrap.js` exports only the authenticated billing status
  callable. It does **not** export purchase verification, reconciliation, or an
  App Store Server Notifications endpoint.
- No production secret, notification URL, scheduled job, or readiness flag is
  created or enabled by the prerequisite change.
- `apple_native_billing_composition.js` contains reviewed Sandbox and Production
  composition factories, but `production_bootstrap.js` does not import or export
  them. Constructing either composition requires the three Apple IAP secret
  bindings and preserves the library's Production-app-ID/Sandbox-no-app-ID rule.
- Apple signed data is handled by `@apple/app-store-server-library` 3.1.0.
  Unsigned JWS payload decoding is not an activation path.
- Apple G2 and G3 public roots are vendored under
  `firebase/functions/certs/apple/`; `README.md` records the official Apple
  source URLs and pinned SHA-256 values.
- The Apple allowlist contains only the two Dispatch product identifiers.
- Entitlement apply/clear operations require the current per-user monotonic
  generation in `native_membership_reconciliation_leases`; older Store API
  responses cannot overwrite a newer verification result.
- Native preflight and Stripe Dispatch/VIP checkout reservations share
  `membership_billing_intents/{uid}`. Coordination activates only when native
  billing is enabled or an existing intent must remain fenced. The accompanying
  Stripe checkout safety changes (promo-replacement blocking and classified
  retry cleanup) affect exported checkout paths on a broad Functions deploy, so
  review and stage that deploy independently even while Apple exports remain
  dormant. Purchase verification requires the opaque preflight nonce;
  restore uses its own preflight nonce rather than a client-controlled bypass.
  Native reservations cover 26 hours and a token-bound pending update renews
  that window for delayed Ask to Buy completion. A completed nonce remains
  replayable for seven days only for the exact account/platform/product so a
  lost callable response cannot prevent StoreKit completion.
- Server-only notification/idempotency/account-index collections are denied to
  clients by the ruleset's default deny behavior and are documented in
  `firebase/FIRESTORE_SCHEMA.md`; do not add client grants.
- Lifecycle notification processing is independently fail-closed through
  `appleSandboxNotificationMutationsEnabled` and
  `appleProductionNotificationMutationsEnabled`. A verified `TEST` notification
  may be acknowledged while the applicable switch is false; every non-`TEST`
  notification receives a retryable response before an idempotency lease or
  entitlement mutation.
- Notification idempotency records carry a `retentionExpiresAt` timestamp at
  least 35 days after the latest processing attempt. Approve and configure the
  Firestore TTL policy before activation; never shorten it below Apple's retry
  window.

## Account and App Store Connect prerequisites

Complete these items in App Store Connect before any server export:

1. The Paid Applications agreement is active, with banking and tax information
   accepted for every entity that will sell the subscription worldwide.
2. The subscription group contains exactly the two approved Dispatch products
   at the App Store tiers USD 24.99/month and USD 299.99/year (the approved
   commercial targets are USD 25/month and USD 300/year), with availability
   set to all 175 storefronts. Confirm Apple's storefront price equalization
   before saving.
3. Localizations, review screenshots, review notes, and the app's subscription
   disclosure/Terms/Privacy links are complete.
4. Create a dedicated **In-App Purchase** private key under Users and Access >
   Integrations. Do not reuse an App Store Connect API key intended only for
   build upload.
5. Record the key ID and issuer ID and download the `.p8` key once. Store them
   only in the deployment secret manager as:
   - `APPLE_IAP_PRIVATE_KEY`
   - `APPLE_IAP_KEY_ID`
   - `APPLE_IAP_ISSUER_ID`
6. Confirm the App Store Server Notifications setting uses version 2. Use a
   separate Sandbox URL and Production URL so each endpoint can pin exactly one
   environment.

Creating those credentials and URLs is an operator action. Never paste the
private key into source, a ticket, console output, or this document.

## Pre-deployment engineering gates

All gates below must pass on the exact release commit:

1. `npm ci`, `npm run lint`, and `npm test` pass in `firebase/functions`.
2. The Flutter caller sends `platform: ios` or `platform: android` to
   `getNativeMembershipBillingStatus` and uses the corresponding
   `appleProductIds` or `googleProductIds` list. On iOS, VIP must not be queried
   or rendered as purchasable.
3. A policy/checkout preflight blocks a StoreKit purchase before Apple charges
   the customer when current policy acceptance, account state, or provider
   ownership disallows purchase. Post-purchase verification must not be the
   first policy gate.
4. The entitlement transaction rechecks Stripe ownership before committing a
   native entitlement, including an open Stripe Checkout Session. Dispatch and
   VIP Stripe reservation transactions must claim the same per-user billing
   intent before their network call; an outer read-only guard does not close the
   race.
5. Existing `native_membership_accounts` documents are backfilled into the
   hashed `native_membership_account_tokens` reverse index by a reviewed,
   admin-only job. Run its dry-run first, then require `confirmWrite: true` for
   the write pass. Abort before writes if any source or existing index token maps
   to more than one user.
6. Firestore backup/restore and event retention are approved for
   `app_store_notification_events`. Notification UUID records must outlive
   Apple's retry window.
7. Monitoring exists for non-2xx notification responses, failed idempotency
   records, unresolved account tokens, reconciliation failures, and lag since
   the last successful reconciliation.
8. The scheduled reconciliation composition durably stores `nextCursor` after
   every successful page, resumes it on the next invocation, and retries or
   alerts whenever `failed > 0`. An in-memory cursor is not sufficient.
   `native_membership_reconciliation_runner.js` processes one bounded page per
   invocation, owns a Firestore execution lease, preserves the page's starting
   cursor on failure, and emits structured success/failure logs. It remains
   unexported until the activation change is approved.

## Staged server activation

Do not combine all of these steps into one blind production change.

1. Add a reviewed composition module that builds one `SignedDataVerifier` and
   one `AppStoreServerAPIClient` per environment. Production must pass Apple app
   ID `6795847447`; Sandbox must omit it, as required by Apple's library.
2. Compose the V2 notification processor with:
   - the environment-specific verifier;
   - the Firestore idempotency event store;
   - the account-token owner resolver;
   - `beginNativeMembershipReconciliation` so every mutation is bound to the
     latest per-user generation;
   - a fresh App Store subscription-status reconciliation call;
   - `applyNativeEntitlement` and `clearExpiredNativeEntitlement` wrappers bound
     to Admin SDK dependencies.
   - an owner authorization callback that accepts Production owners normally
     but requires the `appleSandboxTester` custom claim for Sandbox owners.
3. Add an activation gate ahead of all notification mutations. The endpoint may
   acknowledge Apple's `TEST` notification while disabled, but a lifecycle
   event must not mutate membership until the environment-specific gate is
   deliberately enabled. Keep
   `appleSandboxNotificationMutationsEnabled: false` and
   `appleProductionNotificationMutationsEnabled: false` when first deploying.
4. Export only the Sandbox HTTPS endpoint first and deploy it with App Check not
   required (Apple, not a Firebase client, calls this endpoint). Keep the signed
   payload verifier, request-size limit, and POST-only behavior enabled.
   Sandbox purchase verification additionally requires both
   `appleSandboxEnabled: true` in server readiness and the authenticated custom
   claim `appleSandboxTester: true`; production transaction lookup never falls
   back to Sandbox for ordinary accounts.
5. Register the Sandbox URL in App Store Connect, request a test notification,
   and verify a successful event record without an entitlement mutation.
6. Exercise StoreKit/TestFlight cases for initial buy, renewal, cancel with paid
   access through expiry, billing retry, grace period, recovery, product change,
   refund/revoke, restore, duplicate delivery, and out-of-order delivery.
   TestFlight traffic uses Apple's Sandbox environment.
7. Export a bounded scheduled reconciliation job only after notification tests
   pass. Continue with `nextCursor` until `complete: true`; alert rather than
   silently abandoning failed documents.
8. Deploy the Production notification endpoint with its mutation gate still
   disabled. Register its URL, send Apple's production test notification, and
   confirm signature verification and idempotency telemetry.
9. Export purchase preflight, restore preflight, authenticated intent resume,
   pending-intent update, intent release, and purchase verification together
   for an internal release cohort. The app-lifetime purchase observer must use
   the signed-in account's server-authoritative exact product intent whenever
   its per-account local cache is absent or mismatched, send that nonce with
   verification after a restart, mark the exact product/token pending, and
   release it only on a definite synchronous start failure. Asynchronous
   StoreKit cancel/error events do not carry the server nonce or an exact
   provider-attempt binding, so they must not release a possibly newer intent.
   The 26-hour purchase reservation covers Apple's 24-hour approval window with
   a safety margin; restore uses a separate ten-minute non-charging window and
   settles immediately when the store returns an empty restore batch. Do not
   expose a buy button merely by enabling the global configuration document.
10. When evidence is approved, enable Apple purchases and notification mutation
    in that order, then widen the release cohort. Leave Google readiness and its
    product list unchanged.

## Required acceptance evidence

Capture timestamps and identifiers, but never signed payloads or private keys:

- App Store Connect product status and storefront availability for both IDs.
- Apple test-notification token/status and the matching hashed idempotency event.
- One Sandbox purchase per product mapped to the expected Pipe Buyer account.
- Duplicate notification produces no second membership mutation.
- Invalid outer JWS produces no idempotency reservation or entitlement write.
- A stale expiration event followed by a current Apple status still preserves
  current access.
- Refund/revoke clears only the matching App Store original transaction.
- Apple VIP purchase/notification is rejected or ignored as unconfigured.
- Stripe-managed membership cannot be replaced through a concurrent native
  purchase.
- Simultaneous Apple and Stripe preflights for one UID produce exactly one
  winning billing intent; the losing channel never starts its provider call.
- A pending Apple approval still blocks Stripe after 24 hours, then a late
  success verifies with the original nonce and allows StoreKit completion.
- A lost successful verification response can replay only the exact completed
  nonce/product within its bounded retention window.
- A canceled Stripe subscription remains a native-purchase blocker through its
  paid `currentPeriodEnd`, and an open Stripe Checkout cannot be replaced just
  to change a promo code.
- `restore: true` without a restore-preflight nonce cannot bypass the shared
  billing intent or an open Stripe Checkout Session.
- Reconciliation demonstrates at least three pages (more than 400 records) and
  a resumable continuation cursor.
- Production bootstrap export diff and deployed function inventory match the
  approved activation change exactly.

## Rollback

1. Disable the Apple purchase and notification-mutation gates first.
2. Remove the Production notification URL in App Store Connect if the endpoint
   is unsafe or returning repeated errors. Preserve idempotency records and
   logs for investigation.
3. Keep server verification fail-closed; do not grant an entitlement from an
   unverified device payload to work around an outage.
4. Continue read-only reconciliation where safe. Correct entitlements from
   verified Apple status, then re-enable only after the acceptance matrix passes.

## Release decision

The presence of these source files is not launch approval. Launch is permitted
only after the account prerequisites, secrets, explicit exports, sandbox and
production notification tests, entitlement race regression tests, monitoring,
and acceptance evidence above are complete and reviewed.
