# Repair record — Dispatch Founding 500 launch offer

Date: 2026-08-23
Branch: `p2-dispatch-subscription-hardening`
Policy revision: `2026-08-23-founding500-v2-trial`

## Final business decision

Pipe Buyer will offer the first **500 eligible Pipe Buyer Dispatch accounts** six calendar months free using launch code:

`FOUNDING500`

The offer must work correctly whether the customer chooses CAD 25/month or CAD 300/year.

## Provider coupon attempt — retired before use

An initial LIVE Stripe coupon/promotion code was created:

- Coupon: `PIPEBUYER_FOUNDING500_6M`
- Promotion-code object: `promo_1U7d2oDkO07WMXyRDdMQJAzN`
- Code: `FOUNDING500`
- 100% off, repeating 6 months, max 500
- redemptions: 0

Stripe documentation confirms that a coupon active for a limited number of months can discount the **entire yearly invoice** when the coupon is applied during that active period. Because Dispatch also offers a yearly upfront price, the 100%-off repeating coupon could have given a Yearly customer a full year free instead of six months.

The coupon was therefore deleted before any redemption. Stripe now reports promotion-code object `promo_1U7d2oDkO07WMXyRDdMQJAzN` as `active=false`, `times_redeemed=0`. It is retained only as provider audit history and must not be reactivated.

## Root-cause repair

`FOUNDING500` is now a Pipe Buyer server-controlled launch code, not a Stripe percentage coupon.

For an eligible first subscription:

1. the authenticated Pipe Buyer user enters `FOUNDING500` before Checkout;
2. the server atomically claims one of 500 slots in `dispatch_promotion_programs/dispatch_founding500_2026` and `dispatch_promotion_claims/{uid}`;
3. the server calculates an exact six-calendar-month `subscription_data[trial_end]`;
4. Stripe Checkout creates the chosen Monthly or Yearly subscription with that fixed trial end;
5. Checkout collects the payment method under Stripe's normal subscription-trial behavior so normal billing can begin at trial end;
6. Stripe promotion-code entry is disabled on this Founding Checkout so another discount cannot be stacked on the free period.

A server-managed 1-year/5-year Dispatch entitlement coupon and Founding 500 cannot be combined.

## First-500 enforcement

The server-owned promotion program has:

- code: `FOUNDING500`
- max claims: 500
- claimed count: transactionally incremented
- one claim document per Pipe Buyer UID
- a prior/current/retired Dispatch subscription blocks another Founding grant
- an expired/abandoned first Checkout can reuse the same user's already-counted claim rather than consuming another slot
- a provider-creation failure releases a newly incremented slot when the same reservation is still safe to release

This is a cap on Pipe Buyer account claims. It is not a claim that one human can never create multiple platform accounts; broader account-abuse controls remain a separate anti-fraud layer.

## Exact six-month semantics

The trial end uses calendar-month arithmetic rather than a fixed 180-day approximation. End-of-month dates clamp to the last valid day of the target month.

Examples covered by regression tests:

- 2026-08-23 -> 2027-02-23
- 2026-08-31 -> 2027-02-28

Stripe documents `subscription_data.trial_end` as the timestamp before the first charge and documents that Checkout collects a payment method by default for post-trial billing.

## Client UX

The Dispatch subscription panel contains one optional **Pipe Buyer promo code** field before the Monthly/Yearly plan cards. The code is normalized before the authenticated callable request. Eligibility and trial duration remain server-authoritative.

## Regression coverage

- `firebase/functions/test/dispatch_founding500_policy.test.js`
- `firebase/functions/test/dispatch_subscription_promotion_code_policy.test.js`
- `test/marketplace_dispatch_subscription_client_test.dart`

Full intentional manual Financial Safety / Callable Safety / Quality acceptance remains required before P2 deploy/activation.

## Release boundary

Public Dispatch subscription activation remains OFF. The live retired Stripe coupon had zero redemptions and created no Checkout Session, subscription, invoice, or charge.

The Customer Portal must separately be saved and provider-verified with plan-change proration `none` before the Portal readiness gate can pass.

## Do not repeat

- Do not use a percent-off repeating coupon to represent a fixed free-time benefit across mixed monthly/yearly upfront billing intervals without checking invoice semantics.
- Do not reactivate `promo_1U7d2oDkO07WMXyRDdMQJAzN`.
- Do not grant Founding 500 from client state or browser return.
- Do not allow Founding 500 to stack with another Pipe Buyer entitlement/discount.
- If the offer changes later, create a new versioned server policy and preserve this provider/code history for audit.
