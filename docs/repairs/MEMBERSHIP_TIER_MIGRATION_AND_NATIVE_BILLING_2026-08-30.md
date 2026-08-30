# Membership tier migration and native billing repair — 2026-08-30

## Scope

Pipe Buyer needed customer-controlled movement between the approved membership levels:

- Free
- Dispatch Monthly
- Dispatch Yearly
- VIP

The change also needed a safe native iOS/Android billing path without sending native digital-subscription purchases through Stripe Checkout.

## Root cause

VIP and Dispatch were originally implemented as separate subscription/entitlement surfaces. Subscription lifecycle and invoice handling also relied on Stripe metadata such as `billingType`, `dispatchPlan`, and `vipPlan` to classify paid access.

That architecture was safe while plans were isolated, but it was not safe for plan migration. A Stripe subscription could change price while stale metadata still identified the old tier. That could create a mismatch where Stripe billed one plan and Firebase granted another.

The repair therefore did **not** enable unrestricted Stripe Customer Portal price switching. The entitlement and transition model was corrected first.

## Approved membership model

The server defines one hierarchy:

1. `free` — no recurring membership.
2. `dispatch_monthly` — Dispatch tier, monthly billing.
3. `dispatch_yearly` — the same Dispatch entitlement tier, annual billing cadence.
4. `vip_monthly` — higher tier; VIP benefits include Dispatch access.

Dispatch Monthly and Dispatch Yearly have the same entitlement rank. VIP ranks above both.

## Approved transition behavior

- Free → paid: initial purchase through the platform-appropriate secure checkout/store flow.
- Dispatch Monthly/Yearly → VIP on Stripe: immediate provider update with proration and `payment_behavior=error_if_incomplete`; access waits for provider/payment confirmation.
- VIP → Dispatch Monthly/Yearly on Stripe: scheduled at the end of the already-paid period.
- Monthly ↔ Yearly on Stripe: scheduled at the end of the current paid period.
- Any paid Stripe tier → Free: `cancel_at_period_end`; already-paid access remains until its paid-through timestamp.
- Dispatch-only promotion discounts are explicitly removed during a VIP upgrade and are not carried into VIP.
- An existing Pipe Buyer-owned subscription schedule can be replaced/released; an unknown/external schedule is never overwritten automatically.

## Stripe authority repair

### Subscription lifecycle

`customer.subscription.*` events are classified by the single approved Stripe subscription item Price ID. `billingType` metadata no longer chooses the tier after the subscription price exists.

Metadata remains useful for stable ownership (`pipeBuyerUid`) and billing/tax/referral context, but it cannot override an approved billed price.

### Invoice lifecycle

`invoice.paid` and invoice-payment-failure routing use the approved membership price actually present on the invoice line.

This is deliberately different from simply retrieving the subscription's current price. A delayed or replayed invoice can belong to a previous plan after the subscription has already changed. Classifying the old invoice using the subscription's new current price could grant the wrong tier.

The resolver supports both Stripe line shapes used by the application/API versions:

- `line.price.id`
- `line.pricing.price_details.price`

For upgrade proration, a negative credit for the old plan plus a positive charge for the target plan resolves to the positive target price. Multiple conflicting positive approved membership prices fail closed rather than guessing.

## Provider ownership and duplicate-billing prevention

Pipe Buyer treats the billing provider as part of membership state:

- `stripe`
- `app_store`
- `google_play`
- `free`

A non-terminal Stripe subscription blocks creating a second paid membership subscription. An active App Store or Google Play membership blocks Stripe plan mutations/checkout. A Stripe-managed membership blocks native store purchase initiation.

On web, a store-managed customer is directed to the App Store or Google Play subscription-management surface instead of being shown a Stripe mutation that cannot own that subscription.

## Customer-facing plan management

The dedicated Stripe Customer Portal remains restricted to billing details, payment methods, invoices, and cancellation support. Generic Stripe plan/price switching remains disabled.

Pipe Buyer's own `Change plan` UI exposes only the approved Free / Monthly / Yearly / VIP choices and sends the requested transition to the guarded server command.

This preserves simple UX while keeping the business rules, proration behavior, discount policy, ownership checks, and effective dates server-authoritative.

## Native iOS/Android billing architecture

Native digital membership purchasing uses Flutter's in-app-purchase integration rather than Stripe-hosted subscription checkout.

Approved store product IDs:

- `pipebuyer_dispatch_monthly`
- `pipebuyer_dispatch_yearly`
- `pipebuyer_vip_monthly`

The native client:

- requests a server-generated store account UUID;
- supplies that token to the store purchase request;
- listens to the store purchase stream;
- sends purchase evidence to Pipe Buyer server verification;
- calls `completePurchase()` only after Pipe Buyer confirms `verified: true`;
- supports purchase restoration;
- uses Google Play replacement modes for upgrade/downgrade;
- provides store subscription-management links.

The phone is never the entitlement authority.

### Apple verification

The server implementation uses the App Store Server API, validates the transaction/current subscription state, binds the store transaction to the Pipe Buyer account token, records the original transaction ID, and supports production/sandbox verification.

Secret names are reserved for activation:

- `APPLE_IAP_PRIVATE_KEY`
- `APPLE_IAP_KEY_ID`
- `APPLE_IAP_ISSUER_ID`

### Google Play verification

The server implementation uses the Android Publisher API subscription-v2 state, validates the obfuscated account identifier, and supports reconciliation.

Secret reserved for activation:

- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

## Fail-closed native activation

Repository support does **not** mean native production purchasing is active.

Until App Store Connect and Google Play products, agreements, API permissions, and production secrets are provisioned and sandbox/TestFlight/Play testing is complete:

- `getNativeMembershipBillingStatus` can be deployed;
- `verifyNativeMembershipPurchase` remains unexported;
- `reconcileNativeMembershipSubscriptions` remains unexported;
- native readiness remains disabled;
- native purchase controls show the unavailable/readiness state instead of falling back to Stripe.

Do not bind missing Secret Manager entries to ordinary production Functions. Doing so can break an otherwise safe deployment.

## Regression and repair evidence

Draft PR #156 was used as the execution gate rather than merging first.

### Failure 1 — Dart formatting

The first CI failures were formatter-only differences in the Dispatch/VIP checkout files and then the native billing contract test.

**Repair:** apply exactly the formatter output. No billing behavior was changed to address formatting.

### Failure 2 — invalid const boundaries

Flutter compilation then identified `const SizedBox` parents containing `OutlinedButton.icon`, which is not const in the pinned Flutter toolchain.

**Repair:** remove only the invalid outer `const` qualifiers. Do not change widget behavior to solve a const-constructor compile error.

### Failure 3 — four Functions tests after the runtime authority change

Once Flutter tests passed, the complete Functions suite found four fixtures that still assumed metadata-authoritative subscriptions/invoices or used a synthetic timestamp incompatible with the production wall clock.

**Repair:**

- Dispatch lifecycle fixtures now include an approved Dispatch price and deliberately stale VIP metadata to prove the price wins.
- Unknown/non-approved prices are rejected.
- VIP lifecycle/invoice fixtures include the approved VIP billed price and deliberately stale Dispatch metadata to prove the price wins.
- Native provider ownership uses a real current future expiry in the deterministic status test.

The runtime was **not weakened** to make obsolete metadata-only tests pass.

### Green validation

GitHub Actions run `33301395021` (run #81) completed successfully:

- Flutter dependency resolution: passed
- Dart formatting guard: passed
- Stripe/Flutter integration tests: passed
- Functions install/lint: passed
- complete Functions test suite: passed

## Dependency-generation repair

Adding Flutter in-app purchasing legitimately changes generated dependency state. The release process requires a clean working tree after `flutter pub get`, so generated files must be committed using the same pinned Flutter 3.44.6 toolchain.

A temporary, branch-only, no-production workflow was used to detect the exact generated paths. It found only:

- `pubspec.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift`

The generator is required to fail if any other path changes. The temporary workflow must be removed before merge.

## Do not repeat

- Do not enable unrestricted Stripe Customer Portal plan switching to implement membership migrations.
- Do not let `billingType`, `dispatchPlan`, or `vipPlan` metadata override the actual approved Stripe price after a subscription/invoice exists.
- Do not classify a delayed invoice using only the subscription's current future price; use what that invoice actually billed.
- Do not grant VIP/Dispatch access from a client-reported native purchase without server verification.
- Do not call `completePurchase()` before server verification succeeds.
- Do not allow Stripe and a mobile store to own overlapping paid memberships for the same Pipe Buyer account.
- Do not carry Dispatch-only promotion discounts into VIP.
- Do not remove paid access immediately when a customer selects Free; preserve the already-paid period.
- Do not overwrite a Stripe subscription schedule that is not explicitly Pipe Buyer-owned.
- Do not activate native store billing before the products, credentials, permissions, and sandbox/TestFlight/Play verification exist.
- Do not create fake live Stripe subscriptions merely to test this migration.
- Do not hand-edit generated dependency hashes; generate lock state with the pinned release toolchain.
- Once this repair is deployed, use this record before attempting another membership/billing repair.

## Production status

This document records the implementation and pre-merge validation. Production deployment evidence should be appended after the protected release completes. Native production purchasing must remain described as **prepared but inactive** until the separate store-activation gate is completed.
