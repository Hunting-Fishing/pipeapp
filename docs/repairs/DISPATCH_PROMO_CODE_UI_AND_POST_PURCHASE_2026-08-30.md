# Dispatch Promo Code UI + Post-Purchase Repair — 2026-08-30

## Problem

The earlier Dispatch promotion repair enabled Stripe-hosted promotion-code entry for eligible monthly Checkout Sessions, but the Pipe Buyer UI only told customers to look for the field after leaving the app. That was technically correct but easy to miss, especially for users who expect the familiar checkout pattern of seeing a promo field before pressing the payment button.

There was also no self-service Pipe Buyer path for an existing Dispatch subscriber to enter a promotion code after the initial purchase.

## Root cause

Promotion validation existed only inside Stripe-hosted Checkout. Pipe Buyer had no server-authoritative way to resolve a customer-entered code before opening Checkout, and no authenticated operation for applying an eligible promotion to an existing Stripe subscription.

The fix must not duplicate Stripe's discount engine in Flutter. Expiration, redemption limits, customer restrictions, first-purchase restrictions, and the actual discount value remain Stripe-authoritative.

## Repair

### Before purchase

Monthly Dispatch membership surfaces now show a normal checkout control directly above the payment button:

- `Promo code (optional)`
- `Enter promo code`
- `Apply`
- clear Stripe-confirmed success feedback such as `Promo applied — 100% off for 6 months.`

If a customer types a code and presses Apply, the authenticated backend resolves the active Stripe Promotion Code and creates/reuses a Stripe Checkout Session with `discounts[0][promotion_code]` set to the Stripe promotion-code ID. Pipe Buyer never calculates the discount locally.

If the field is left blank, eligible monthly Checkout Sessions still use `allow_promotion_codes=true`, so Stripe-hosted Checkout remains a fallback entry point.

`CHECKOUT_CONFIGURATION_VERSION` is now `3`. Checkout reuse also requires the cached `promotionCodeId` to match the currently requested promotion. A no-promo Session cannot be reused after the user enters a code, and a Session created for one promotion cannot be reused for another promotion.

### Existing subscribers

Active monthly Dispatch memberships now show a separate `Have a promo code?` section in Pipe Buyer.

The new authenticated callable `applyDispatchSubscriptionPromotionCode`:

1. requires the signed-in Firebase identity;
2. enforces the existing account rate limit and Dispatch / paid-feature gates;
3. requires production Stripe subscription readiness, webhook verification, reconciliation readiness, and current tax-billing policy readiness;
4. verifies that the caller has an active monthly Dispatch membership;
5. verifies that the Firestore provider state belongs to the caller and points to a Stripe `cus_` customer and `sub_` subscription;
6. resolves the user-entered code from Stripe rather than trusting the client;
7. retrieves the Stripe subscription and verifies its customer ownership;
8. refuses to silently stack or replace an existing different discount;
9. applies the eligible Stripe Promotion Code through the Subscription Update API; and
10. records a sanitized server-side promotion audit record without storing the raw code typed by the customer.

Applying a promotion updates the subscription discount for future eligible invoices. The promo action does not itself create a charge, refund the current paid period, transfer seller funds, or trigger a payout.

### Annual membership policy

Self-service promo entry remains intentionally limited to monthly Dispatch membership for the current policy. A repeating six-month percentage coupon can have surprising semantics on an annual invoice. Annual promo support must be introduced only with an annual-specific offer/policy and regression coverage.

## FOUNDING500 behavior

The live `FOUNDING500` Promotion Code is configured in Stripe as a first-transaction offer. Pipe Buyer must preserve that restriction.

A new customer can enter the code before the first eligible monthly purchase. An already-paid subscriber who later enters `FOUNDING500` receives a clear eligibility error instead of Pipe Buyer bypassing Stripe's first-purchase policy.

Do not expose or auto-fill `FOUNDING500` in the app merely because it exists in Stripe. The UI is a generic promo-entry surface for customers who already possess an eligible code.

## Security and financial boundaries

- Flutter sends only the typed promotion-code string; it never sends or calculates a discount amount.
- The backend resolves the Stripe Promotion Code ID and discount details.
- No promotion code can alter marketplace seller proceeds, marketplace fees, refunds, transfers, payouts, or Connect onboarding.
- Existing server-granted Dispatch entitlement coupons remain separate and are not stacked with customer-entered promotion codes.
- Existing subscription discounts are never silently replaced or stacked.
- Promotion-code input is length and character bounded before Stripe lookup.
- The raw customer-entered code is not persisted in Firestore audit state.

## Deployment and regression coverage

The gated payment deployment now includes and verifies `applyDispatchSubscriptionPromotionCode`.

Regression coverage locks:

- monthly-only customer promo entry under the current offer policy;
- input normalization and bounding;
- case-insensitive Stripe code selection and customer-specific preference;
- Stripe-derived discount summaries;
- Dispatch product scoping when Stripe supplies `applies_to`;
- existing-discount ID recognition for idempotency;
- Checkout configuration-version invalidation;
- promotion-aware Checkout Session reuse;
- visible Flutter promo field, Apply action, and confirmed-discount feedback; and
- Stripe closure workflow coverage for the new backend and Flutter files.

## Do not repeat

Do not move discount calculation or eligibility rules into Flutter.

Do not accept a client-submitted amount, percent, coupon ID, or promotion-code ID as authoritative.

Do not remove the `promotionCodeId` check from Checkout reuse; otherwise a cached non-discounted Session can hide a newly entered code.

Do not enable `allow_promotion_codes=true` on a Checkout Session that already receives an explicit `discounts` entry.

Do not bypass Stripe's `first_time_transaction` restriction for existing customers.

Do not silently replace or stack an existing subscription discount.

Do not enable this six-month promotion path on annual Dispatch billing without explicitly defining and testing the annual invoice semantics.

Do not enable Customer Portal `subscription_update` merely to obtain promo-code support. Pipe Buyer's existing Dispatch Portal configuration intentionally disables general subscription changes; the promo-only callable keeps that boundary narrow.

Do not change marketplace buyer charges, seller transfers, platform fees, refunds, payouts, or Connect onboarding as part of this repair.
