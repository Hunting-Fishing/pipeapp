# Dispatch unified product, Stripe Customer reuse, and plan switching

Date: 2026-08-23

## Problem

Dispatch Monthly and Yearly were represented by two separate LIVE Stripe Products. That made controlled self-service Monthly ↔ Yearly switching harder and left replacement Checkout able to create a second Stripe Customer for a Pipe Buyer user even when `dispatch_subscriptions/{uid}.stripeCustomerId` already existed.

The previous Billing Portal provider policy also required subscription updates to be disabled, so enabling customer plan switching would deliberately fail readiness.

## Provider evidence before repair

LIVE Pipe Buyer Stripe account: `acct_1U2QmKDkO07WMXyR`.

Original catalog:

- Monthly: `prod_V2WkE5D16GhGaD` / `price_1U2SYGDkO07WMXyRm6xbprUn` — CAD 25/month.
- Legacy Yearly: `prod_V2WsPl25y7Qe6A` / `price_1U2XDVDkO07WMXyRS0eCYKCh` — CAD 300/year.

Provider reads confirmed **zero subscriptions** on both original Dispatch prices before catalog consolidation. No subscriber migration was required.

## Stripe repair performed

1. Kept `prod_V2WkE5D16GhGaD` as the canonical Dispatch Product and renamed it **Pipe Buyer Dispatch**.
2. Created LIVE yearly Price `price_1U7bTCDkO07WMXyRvLkWVHHu` for CAD 300/year under that same Product.
3. Transferred lookup key `pipe_buyer_dispatch_yearly_cad` to the new yearly Price.
4. Marked legacy Product `prod_V2WsPl25y7Qe6A` as retired and then deactivated it.
5. Stripe refused to archive legacy Price `price_1U2XDVDkO07WMXyRS0eCYKCh` because it remains the default Price of its legacy Product. That provider guard was respected; no forced workaround was attempted. The inactive legacy Product is retained for historical/audit references.
6. No live Checkout Session, charge, invoice, or subscription was created during this repair.

Canonical Dispatch catalog after repair:

- Product: `prod_V2WkE5D16GhGaD`
- Monthly: `price_1U2SYGDkO07WMXyRm6xbprUn`
- Yearly: `price_1U7bTCDkO07WMXyRvLkWVHHu`

## Application repair performed

`firebase/functions/stripe_marketplace_config.js`

- Monthly and Yearly now intentionally share `prod_V2WkE5D16GhGaD`.
- Yearly Checkout now references `price_1U7bTCDkO07WMXyRvLkWVHHu`.
- Legacy Stripe identifiers are retained in a non-purchasable audit block.

`firebase/functions/dispatch_subscription_commands.js`

- Replacement Checkout reuses a valid stored `stripeCustomerId` by sending the existing `cus_...` as Stripe Checkout `customer`.
- First-time users still let Stripe create the first Customer.
- A non-empty malformed stored Stripe Customer ID fails closed before provider creation.
- Customer identity remains preserved across canceled/restartable subscription replacement.

`firebase/functions/dispatch_billing_portal_policy.js`

Provider policy revision is now `2026-08-23-p2-v2-dispatch-plan-switching`.

Provider verification now requires:

- LIVE + active Billing Portal configuration;
- payment-method updates ON;
- customer updates ON for exactly `address`, `email`, `name`, `phone`, and `tax_id`;
- shipping-address editing absent from the allowed customer-update set;
- invoice history ON;
- cancellation ON, `at_period_end`, no cancellation proration;
- subscription update ON;
- allowed subscription update field exactly `price` — quantity is not allowed;
- subscription update proration `none`;
- exactly one switchable Product: `prod_V2WkE5D16GhGaD`;
- exactly two switchable Prices: Monthly `price_1U2SYGDkO07WMXyRm6xbprUn` and Yearly `price_1U7bTCDkO07WMXyRvLkWVHHu`.

Stored provider proof is bound to those exact fields and identifiers. Runtime provider drift fails closed.

`.github/workflows/production-readiness-audit.yml`

- Production audit now checks the exact customer-update fields and exact two-price Dispatch switching catalog instead of requiring plan switching OFF.

## Tests updated

Updated focused contracts cover:

- exact Portal provider policy;
- no quantity switching;
- no extra product/price switching;
- exact customer-update field allowlist;
- no shipping-address edit in the reviewed Portal profile;
- replacement Checkout reuses existing Stripe Customer;
- malformed Customer identity fails closed;
- unified yearly Price is selected for Yearly Checkout;
- provider verification and runtime drift checks;
- payment-readiness activation requires current exact provider proof;
- production-readiness workflow contract.

## Remaining provider step

The connected Stripe API surface available to this workspace exposes Billing Portal configuration reads but not a writable Billing Portal configuration operation. Therefore the LIVE default Portal still must be changed in Stripe Dashboard before provider verification can pass the new v2 policy.

Required Dashboard state:

- **Customers can switch plans: ON**
- **Customers can change quantity: OFF**
- eligible Product: **Pipe Buyer Dispatch** (`prod_V2WkE5D16GhGaD`)
- eligible Prices: Monthly `price_1U2SYGDkO07WMXyRm6xbprUn` and Yearly `price_1U7bTCDkO07WMXyRvLkWVHHu` only
- plan-change proration: **none**

After that Dashboard save, run `verifyDispatchBillingPortalConfiguration` against LIVE config `bpc_1U7aEmDkO07WMXyRjjSqn4SF`. The new provider revision must be recorded before Dispatch subscription Checkout can become financially ready.

## Do not repeat

Do not create another yearly Dispatch Product. New Dispatch billing intervals belong under canonical Product `prod_V2WkE5D16GhGaD` unless a future reviewed migration explicitly changes the catalog.

Do not remove Stripe Customer reuse from replacement Checkout. One Pipe Buyer user should retain one billing Customer identity unless an audited customer-identity repair explicitly replaces it.
