# Repair record — P2 Dispatch customer billing availability projection

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

## Root cause

The Dispatch subscription status API originally calculated `canStartCheckout` only from the individual user's subscription state:

- no active subscription;
- no open Checkout;
- not processing;
- no review conflict.

That answered **whether the account was locally eligible to start another subscription**, but it did not answer **whether Pipe Buyer production billing was currently allowed to sell one**.

As a result, a user with no existing subscription could see a purchase action even while the server correctly had public Dispatch subscriptions OFF because one or more production prerequisites were incomplete.

The actual Checkout callable would fail closed, but that still produced a poor customer experience: the app could invite a non-technical user to buy and then reject the action as unavailable.

This was a projection mismatch between the customer UI and the server financial gate, not a Checkout authorization defect.

## Exact repair

### 1. Keep account-state eligibility separate

`dispatch_subscription_status_policy.js` remains responsible only for public user subscription state and local account eligibility.

It still answers whether the user's current subscription/Checkout state is compatible with starting another Checkout.

### 2. Add platform billing availability at the authenticated status command

`dispatch_subscription_status_commands.js` now reads:

- `dispatch_subscriptions/{uid}`;
- `platform_configuration/dispatch_billing_portal`;
- `platform_configuration/payment_provider_readiness`.

`dispatchSubscriptionPublicBillingReady()` requires the same stored production prerequisites used by Dispatch billing:

- `stripeSubscriptionsEnabled == true`;
- Stripe mode is production;
- core webhook verified;
- subscription lifecycle webhook verified;
- subscription recovery verified;
- reconciliation ready;
- authorized GST/HST billing state;
- provider-verified current Billing Portal record with a safe Pipe Buyer return URL.

The status response now includes:

`billingAvailable`

and returns:

`canStartCheckout = billingAvailable && accountStateCanStartCheckout`

The actual Checkout runtime remains more authoritative and re-reads the live Stripe Portal configuration before money movement. The public status projection deliberately does not call Stripe on every UI refresh.

### 3. Existing subscribers are preserved when new sales are OFF

Turning new Dispatch subscriptions OFF does not rewrite entitlement state.

An active subscriber can remain:

- `entitlementActive == true`;
- `alreadySubscribed == true`;
- `canManageBilling == true` when the verified Portal remains available;

while:

- `billingAvailable == false`;
- `canStartCheckout == false`.

This separates new-sale authority from existing subscription state.

### 4. Flutter fails closed across mixed backend/app versions

`MarketplaceDispatchSubscriptionStatus` now exposes `billingAvailable`.

If an older backend response omits that new field, Flutter treats it as `false`, not `true`. This avoids accidentally enabling purchase actions during a staged deployment.

### 5. Customer UX matches server availability

`marketplace_dispatch_subscription_panel.dart` now:

- disables purchase actions when `billingAvailable == false`;
- shows **Dispatch subscriptions are not open yet** rather than an error;
- labels plan buttons **Subscriptions not available yet**;
- preserves and explains an existing Checkout if billing later becomes unavailable;
- explains when an existing subscriber's secure billing management is temporarily unavailable;
- displays tax treatment as subject to the approved Pipe Buyer billing state / secure Stripe Checkout;
- refreshes subscription status automatically when the app resumes after external Stripe Checkout or Billing Portal use;
- retains the manual Refresh control as a fallback.

Returning from Checkout still never grants entitlement by itself.

## Verification added/updated

Coverage now includes:

- public billing availability requires all stored Dispatch launch prerequisites;
- public sales OFF forces `billingAvailable == false` and `canStartCheckout == false`;
- fully ready billing + eligible user allows Checkout projection;
- existing active subscriber remains active when new purchases are disabled;
- Flutter treats a missing `billingAvailable` field as unavailable;
- customer plan buttons depend on `status.billingAvailable`;
- customer UI exposes a non-error not-open-yet state;
- app lifecycle resume triggers a server status refresh;
- customer Flutter contains no direct authoritative financial Firestore writes.

Full Flutter/Functions/emulator execution remains required from the complete repository toolchain.

## Do not repeat

- Do not derive a customer purchase button only from the user's subscription state; platform financial readiness must also permit the sale.
- Do not solve a server/UI readiness mismatch by catching the Checkout rejection and showing friendlier text. Fix the projection.
- Do not let a missing new readiness field default to enabled during staged deployment.
- Do not revoke or rewrite existing subscriber entitlement merely because new subscription sales are paused.
- Do not make the status endpoint call Stripe on every normal UI refresh; stored public readiness may drive presentation while the actual financial action performs the final live provider re-check.
- Do not grant membership because the app resumed or returned from Stripe; resume only refreshes server-authoritative state.
