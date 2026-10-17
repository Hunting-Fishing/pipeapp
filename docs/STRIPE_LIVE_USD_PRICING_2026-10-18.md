# Stripe live USD Dispatch pricing — 2026-10-18

## Verified live catalog

Account: Pipe Buyer live platform (`acct_1U2QmKDkO07WMXyR`)

Unified product: Pipe Buyer Dispatch (`prod_V2WkE5D16GhGaD`)

| Cadence | Live Price ID | Price | Use |
| --- | --- | ---: | --- |
| Monthly | `price_1UReXRDkO07WMXyRFyrSKpR4` | US$25/month | New web checkout; product default |
| Yearly | `price_1UReYXDkO07WMXyRwonGROt3` | US$250/year | New web checkout |

The annual price saves US$50 against twelve US$25 monthly payments. That is
exactly two monthly payments, or 16.667%. The saving is built into the recurring
annual Price and is not implemented with a coupon.

Product metadata was updated to `currency=usd`, `market=global`, and
`catalog_revision=2026-10-18-global-usd-catalog`.

## Compatibility boundary

The existing CA$25/month and CA$300/year recurring Price objects remain active
and had zero active subscriptions when checked. They are not selected for new
checkout sessions. The server retains them as recognition aliases so delayed
invoices, event retries, and historical provider records still resolve to the
correct membership plan.

No one-time price or separate legacy Dispatch product was archived in this
change. Provider objects are immutable references and must remain available
until old clients, links, events, and records have been dependency-audited.

## Activation boundary

This catalog change does not make production payments ready. Keep production
readiness, paid-feature, mutation, and native-billing flags false until all of
the following have current acceptance evidence:

- restricted live secret and least-privilege review;
- snapshot plus Accounts v2 production webhook destinations and signing-secret
  bindings;
- required event coverage, including Checkout expiration;
- Connect seller re-onboarding/migration to the reviewed Accounts v2 contract;
- tax-liability and registration decision;
- refund, dispute, duplicate, out-of-order, and reconciliation tests;
- current signed store builds and store/device acceptance.

The live catalog was changed; no customer was charged, no subscription was
created, no seller funds were moved, and no production feature flag was enabled.
