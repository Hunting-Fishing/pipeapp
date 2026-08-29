# VIP Subscription Billing — 2026-08-29

## Symptom
Pipe Buyer already displayed a VIP early-access membership card, but the card intentionally stopped at “VIP billing coming soon” because no approved Stripe VIP price or authoritative billing lifecycle existed.

## Proven root cause
The application had VIP presentation/early-access logic but no dedicated live Stripe VIP product/price in server config and no VIP Checkout, provider-state, paid-invoice entitlement, status, or renewal-management callables. A Checkout redirect must not grant VIP access.

## Approved launch pricing
- Dispatch Monthly: CAD $25/month (unchanged)
- Dispatch Yearly: CAD $300/year (unchanged)
- Pipe Buyer VIP: CAD $100/month
- No VIP yearly plan at launch
- Live VIP product: prod_VA12LaMiaCMRqZ
- Live VIP monthly price: price_1U9h0tDkO07WMXyRgdzAmm43

## Repair
- Added exact non-secret VIP product/price configuration.
- Added a separate `stripeVipSubscriptionsEnabled` readiness switch in addition to the generic subscription gate.
- Added dedicated VIP catalog, Checkout, provider lifecycle, paid-invoice entitlement, private status, and renewal-management modules.
- VIP access is established/extended only from verified `invoice.paid` processing.
- Checkout completion records provider state only and cannot grant VIP.
- Existing `users/{uid}` VIP fields are mirrored server-side from paid membership state so the current early-access gate continues to work.
- Replaced only the intentional VIP “coming soon” action in the existing responsive membership dialog; Dispatch controls remain unchanged.
- Added safe end-of-period cancellation/resume. Paid access remains through the current period.
- No real customer charge was made during validation.

## Safety posture
The code is deployable fail-closed. Creating the live Stripe product/price does not itself expose VIP Checkout. Production VIP Checkout requires `stripeVipSubscriptionsEnabled=true` plus the existing verified production subscription, webhook, reconciliation, tax-billing, policy, and paid-feature gates.

## Regression coverage
Validation checks the exact product/price IDs and CAD $100 monthly amount, monthly-only plan selection, duplicate Checkout blocking, explicit VIP webhook identity, paid-invoice context, server catalog price rendering, responsive membership artwork, Functions lint/check/tests, Dart analysis, and the full Flutter test suite.
