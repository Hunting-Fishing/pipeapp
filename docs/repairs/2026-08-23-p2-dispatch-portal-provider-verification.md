# Repair record — P2 Dispatch Billing Portal provider verification

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

## Root cause

The earlier Billing Portal repair correctly pinned every customer Portal session to an exact audited Stripe configuration ID (`bpc_...`). That solved mutable-default configuration risk, but a second control problem remained:

**a syntactically valid `bpc_...` ID proves identity format, not that the live Stripe configuration has the launch-approved features.**

Before this repair, an administrator could store an enabled Portal record with a valid-looking `bpc_...` and Pipe Buyer HTTPS return URL. Payment readiness and Dispatch Checkout would accept that record without re-reading Stripe to prove:

- the configuration actually exists in LIVE mode;
- the configuration is active;
- payment-method updates are enabled;
- invoice history is enabled;
- cancellation is enabled at the end of the billing period;
- cancellation does not create proration;
- subscription update / Monthly ↔ Yearly price switching is disabled.

That could create customer-management behavior different from the application policy even though the stored configuration ID looked valid.

A second runtime gap was then identified during review: even valid provider proof can become stale if an operator changes the Stripe Portal configuration after Pipe Buyer verified it. Stored proof therefore cannot be the final runtime authority.

## Exact repair

### 1. Provider feature policy

`firebase/functions/dispatch_billing_portal_policy.js`

Provider policy revision:

`2026-08-23-p2-v1-provider-features`

`dispatchBillingPortalProviderAssessment()` now requires the retrieved Stripe Portal configuration to prove all of:

- valid exact `bpc_...` identity;
- `livemode == true`;
- `active == true`;
- `features.payment_method_update.enabled == true`;
- `features.invoice_history.enabled == true`;
- `features.subscription_cancel.enabled == true`;
- `features.subscription_cancel.mode == at_period_end`;
- cancellation proration behavior is `none`;
- `features.subscription_update.enabled == false`.

The policy returns a sanitized assessment with failed checks and reviewed feature state.

`dispatchBillingPortalProviderRecordReady()` additionally requires the stored provider proof to be bound to:

- the current policy revision; and
- the exact same `stripePortalConfigurationId` currently stored.

Changing the `bpc_...` identity or using stale policy evidence therefore invalidates readiness.

### 2. Stripe-backed verification command is the only enable path

Added:

`firebase/functions/dispatch_billing_portal_verification_commands.js`

Callable:

`verifyDispatchBillingPortalConfiguration`

The MFA-admin command:

1. validates the requested exact `bpc_...` ID;
2. validates the reviewed Pipe Buyer HTTPS return URL;
3. requires explicit production confirmation and an audit reason;
4. retrieves `/v1/billing_portal/configurations/{bpc}` with the production Stripe secret;
5. runs the provider feature assessment;
6. fails closed if identity or any required feature is wrong;
7. only on successful provider proof writes `platform_configuration/dispatch_billing_portal` as enabled;
8. stores exact configuration binding, provider-policy revision, sanitized provider features, administrator identity, timestamps, and an audit record.

This command does **not** activate subscriptions and does not create any payment, Checkout Session, invoice, charge, or money movement.

### 3. Manual Portal enablement removed

`setDispatchBillingPortalReadiness` can no longer set `enabled: true`.

It is retained as the emergency revoke/disable control only. Disable clears:

- Portal enabled state;
- stored `bpc_...` identity;
- return URL;
- provider-verification state;
- provider-verified configuration binding;
- provider-policy revision;
- sanitized provider feature evidence.

This prevents old/stale provider proof from becoming active again accidentally.

### 4. Payment activation requires provider proof

`payment_readiness_admin.js` now refuses `stripeSubscriptionsEnabled == true` unless the Portal record:

- is enabled;
- passes `dispatchBillingPortalProviderRecordReady()`;
- retains a valid Pipe Buyer HTTPS return URL.

A `bpc_...`-shaped value without provider proof is explicitly tested and rejected.

### 5. Exported Dispatch Checkout has an independent Portal proof gate

Added:

`firebase/functions/dispatch_subscription_portal_runtime_gate.js`

The production callable export checks the current Portal record before invoking the existing hardened Dispatch Checkout command. It requires:

- Portal enabled;
- current provider proof bound to the exact `bpc_...`;
- reviewed safe Pipe Buyer return URL.

This protects the actual client-exposed Checkout boundary even if readiness data is manually corrupted.

The original Checkout command remains intact; the added guard is a narrow boundary wrapper rather than a broad rewrite.

### 6. Billing Portal sessions require the same provider proof

`dispatchBillingPortalAvailable()` now requires current provider verification in addition to the server-owned Stripe Customer/Subscription identities and no operational review conflict.

A Portal session therefore cannot be opened from an unverified or re-pointed configuration record.

### 7. Operator UI verifies Stripe rather than declaring readiness

Added:

`lib/marketplace/marketplace_dispatch_billing_portal_control.dart`

Integrated into the MFA-protected Dispatch Billing Operations page.

The admin flow is:

1. create/review the live Portal configuration in Stripe Dashboard;
2. enter its exact `bpc_...` ID and Pipe Buyer return URL;
3. choose **Verify & enable Billing Portal**;
4. server re-reads Stripe and validates every required feature;
5. only successful provider evidence turns Portal readiness on.

The UI also exposes an audited **Disable Billing Portal** action. It contains no direct Firestore financial writes and no public subscription-activation control.

### 8. Production readiness audit checks features, not count

`.github/workflows/production-readiness-audit.yml` no longer treats “at least one active Portal configuration” as sufficient.

It requires at least one active LIVE Portal configuration whose provider features match the approved Dispatch launch profile, and it requires deployment of:

- `createDispatchBillingPortalSession`;
- `verifyDispatchBillingPortalConfiguration`;
- `verifyDispatchSubscriptionLifecycleWebhook`;
- `reconcileDispatchSubscriptionInvoice`.

### 9. Stored proof is re-verified live at the client-exposed runtime boundary

The same runtime wrapper now re-reads the exact stored `bpc_...` from Stripe immediately before:

- `createDispatchSubscriptionCheckout`; and
- `createDispatchBillingPortalSession`.

If Stripe no longer returns the exact configuration or any launch feature has drifted, the action fails closed before the original billing handler executes.

This specifically protects against post-verification provider drift such as:

- turning Monthly ↔ Yearly plan switching on;
- changing cancellation away from end-of-period;
- enabling cancellation proration;
- disabling payment-method update or invoice history;
- disabling/deleting/replacing the Portal configuration.

### 10. Authentication occurs before Firestore or Stripe provider re-read

The runtime wrapper now requires an authenticated Firebase request before reading the Portal readiness document or calling Stripe.

This closes a review-discovered ordering defect where an unauthenticated caller could otherwise cause provider reads before the wrapped Dispatch handler reached its own authentication/rate-limit controls.

The wrapper performs only the minimal signed-in precheck. The original inner handlers remain authoritative for their complete account-security, feature-flag, tax, and abuse/rate-limit policy.

A regression test proves an unauthenticated request causes:

- zero Firestore Portal reads;
- zero Stripe provider calls; and
- zero inner-handler invocation.

### 11. Dispatch Billing Operations UI made operator-oriented

The dedicated admin workspace now presents:

- a protected-financial-operations banner;
- a constrained desktop/mobile reading width;
- numbered Launch Readiness, Customer Billing Management, and Subscription Accounting sections;
- six-prerequisite progress rather than a loose set of booleans;
- a single recommended next action;
- explicit `BILLING OFF` / `BILLING ON` status;
- `PROVIDER VERIFIED` / `NOT VERIFIED` Portal status;
- the exact verified Portal feature checklist;
- current Invoice → InvoicePayment → PaymentIntent → Charge → Balance Transaction reconciliation language;
- an explicit expected empty state before controlled Monthly/Yearly acceptance.

The UI still contains no public subscription activation action and no direct authoritative Firestore financial writes.

## Verification contracts added/updated

Coverage now includes:

- safe vs unsafe Stripe Portal provider feature assessment;
- exact `bpc_...` provider binding;
- policy-revision binding;
- manual enable rejection;
- stale provider proof rendered fail-closed;
- emergency disable clears proof;
- activation rejects a valid-looking ID without provider proof;
- exported Checkout gate rejects missing/stale proof before invoking the inner command;
- live provider drift blocks both Checkout and Manage Billing;
- unauthenticated requests cannot trigger Portal Firestore/Stripe reads;
- Portal session rejects missing/mismatched proof;
- provider verifier rejects plan switching, immediate cancellation, proration, and non-live configuration;
- production audit checks launch-safe provider features;
- Flutter Portal control uses callables only and cannot activate subscriptions;
- Launch Readiness UI requires provider-bound Portal proof and exposes one recommended next action;
- Dispatch Billing Operations retains its protected, focused section structure.

Full Flutter/Functions/emulator execution is still required from the complete toolchain before merge/deploy.

## Live provider state during this repair

At the latest read-only Stripe audit, the Pipe Buyer LIVE account still had **zero Billing Portal configurations**.

No `bpc_...` object was fabricated, no live charge was created, no lifecycle webhook events were added, and public Dispatch subscriptions remain OFF.

The connected Stripe tool in this session exposes Portal configuration list/retrieve operations but not create/update. The live Portal object therefore remains a deliberate external Dashboard step.

## Do not repeat

- Do not equate `bpc_...` format validation with provider configuration verification.
- Do not treat stored provider proof as permanently valid; re-read Stripe before client-exposed billing actions.
- Do not perform provider reads for an unauthenticated request.
- Do not manually enable Portal readiness; only the Stripe-backed verifier may establish the ON state.
- Do not reuse provider proof after changing the configuration ID or provider policy revision.
- Do not enable subscription-update/plan switching in the first-release Portal configuration.
- Do not allow immediate cancellation/proration when the approved launch policy is end-of-period cancellation with no proration.
- Do not mark Portal readiness green from a stale legacy record; current provider proof is required.
- Do not rewrite the large Dispatch Checkout implementation for a boundary precondition when a small server-side wrapper can safely enforce it.
- Do not add live lifecycle webhook events or run controlled money until the accepted receiver/verifier stack is deployed.
