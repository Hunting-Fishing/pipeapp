# Dispatch Promotion Code Entry Repair — 2026-08-29

## Problem

Pipe Buyer had live Dispatch subscription pricing and historical promotion assets in Stripe, but the active Dispatch Checkout creator explicitly set `allow_promotion_codes=false`. Users therefore had no secure place to type a Stripe promotion code.

The historical live Stripe promotion code `FOUNDING500` was also inactive and referenced a missing coupon, so simply exposing the Checkout field would not have restored the intended promotion.

## Stripe repair

The intended historical offer was reconstructed from the existing Stripe promotion metadata:

- code: `FOUNDING500`
- audience: first 500 Dispatch customers
- offer: six months free Dispatch
- first-time transaction restriction: enabled

A live coupon was created as `PIPEBUYER_FOUNDING500_6M` with 100% off for six repeating months and restricted to the Dispatch product `prod_V2WkE5D16GhGaD`.

A new live active `FOUNDING500` promotion code was created against that coupon with `max_redemptions=500` and `first_time_transaction=true`.

No customer, charge, refund, transfer, or payout was modified while repairing the promotion objects.

## Application root cause and repair

`firebase/functions/dispatch_subscription_commands.js` previously always sent `allow_promotion_codes=false` to Stripe Checkout.

The repaired behavior is intentionally narrower than a global switch:

1. User-entered promotion codes are enabled only for the monthly Dispatch Checkout.
2. If Pipe Buyer has already granted a server-authoritative Dispatch coupon through `promotion_entitlements`, promotion-code entry remains disabled so Checkout does not combine an automatic entitlement with a second user-entered discount path.
3. Yearly Dispatch Checkout does not expose user-entered promotion codes for the current `FOUNDING500` offer. Monthly and yearly Dispatch prices share one Stripe product, and a 100% six-month coupon applied to the annual invoice could zero the first annual invoice instead of representing six months of value.
4. Existing one-year and five-year server-granted promotion entitlements are unchanged.
5. VIP Checkout remains unchanged with promotion-code entry disabled because `FOUNDING500` is a Dispatch promotion.

## Stale Checkout protection

Dispatch Checkout state now includes `CHECKOUT_CONFIGURATION_VERSION = 2`.

A cached Checkout Session created under the old configuration is not reused after this repair. This prevents an account that opened Checkout before deployment from being sent back to a stale Stripe Session that still lacks the promotion-code field.

## User experience

The monthly Dispatch subscription UI now states:

> Have a promo code? Enter it on the secure Stripe checkout screen.

Stripe remains responsible for validating the customer-entered code and calculating the discount. Pipe Buyer does not accept or trust a client-submitted discount amount.

## Regression coverage

Added coverage verifies:

- monthly Dispatch without a pre-applied entitlement allows user promotion-code entry;
- monthly Dispatch with a pre-applied entitlement does not;
- yearly Dispatch does not expose the current user-entered promotion path;
- stale pre-repair Checkout sessions are not reused;
- the Flutter UI only advertises promo entry for monthly Dispatch.

## Do not repeat

Do not build a second custom promo-code validator in Flutter or trust a client-submitted discount. Continue using Stripe-hosted Checkout for customer-entered promotion codes and keep offer scope enforced by Stripe coupon/product configuration plus server-side Checkout policy.

Do not enable user-entered promo codes globally across VIP, marketplace equipment payments, or annual Dispatch Checkout without first defining a product/price-specific promotion policy and testing the invoice-period effect.
