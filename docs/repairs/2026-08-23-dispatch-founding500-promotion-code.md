# Repair record — Dispatch Founding 500 promotion code

Date: 2026-08-23
Branch: `p2-dispatch-subscription-hardening`

## Business decision

Pipe Buyer will offer the first 500 eligible Dispatch subscription redemptions **6 months free** through a customer-facing Stripe promotion code.

Live Stripe resources created for the launch offer:

- Coupon: `PIPEBUYER_FOUNDING500_6M`
- Promotion code: `FOUNDING500`
- Promotion-code object: `promo_1U7d2oDkO07WMXyRDdMQJAzN`
- Discount: 100%
- Duration: repeating for 6 months
- Product scope: `prod_V2WkE5D16GhGaD` (`Pipe Buyer Dispatch`) only
- Coupon maximum redemptions: 500
- Promotion-code maximum redemptions: 500
- Promotion-code restriction: first-time transaction only
- Redemptions at creation: 0

The existing internal `PIPEBUYER_FREE_1Y` and `PIPEBUYER_FREE_5Y` entitlement coupons were not modified.

## Root cause

The P2 Dispatch Checkout command explicitly sent `allow_promotion_codes: "false"`. Enabling promotion codes in the Stripe Customer Portal therefore did not make a promotion-code field available during a new subscriber's initial hosted Checkout.

A second constraint also existed: Pipe Buyer can pre-apply a server-managed 1-year or 5-year entitlement coupon. Customer-entered promotion codes must not be offered on the same Checkout when one of those entitlement coupons is already applied.

## Exact repair

`firebase/functions/dispatch_subscription_commands.js` now derives promotion-code entry from the server-controlled entitlement result:

- no pre-applied entitlement coupon -> `allow_promotion_codes: "true"`;
- pre-applied 1-year/5-year entitlement coupon -> `allow_promotion_codes: "false"` and the existing `discounts[0][coupon]` remains authoritative.

Helper: `dispatchPromotionCodeEntryEnabled(couponId)`.

This makes `FOUNDING500` usable at initial Dispatch Checkout without creating a discount-stacking path for special entitlement users.

## Regression coverage

`firebase/functions/test/dispatch_subscription_promotion_code_policy.test.js` proves:

1. promotion-code entry is enabled when no entitlement coupon exists;
2. a 1-year entitlement coupon disables promotion-code entry;
3. a 5-year entitlement coupon disables promotion-code entry.

Full manual Financial Safety / Callable Safety / Quality acceptance is still required before P2 deploy/activation.

## Provider state and release boundary

The promotion code is live in Stripe, but public Dispatch subscription activation remains OFF. Creating the coupon/code does not create a Checkout Session, subscription, invoice, or charge.

The live Customer Portal plan-switch configuration must separately be saved and provider-verified with no plan-change proration before the Portal readiness gate can pass.

## Future modification rule

Do not mutate historical discount semantics after customers have redeemed the offer. If the launch promotion needs to change, deactivate the existing promotion code for new redemptions and create a new versioned coupon/promotion code with documented limits. Preserve old provider objects for audit and invoice history.
