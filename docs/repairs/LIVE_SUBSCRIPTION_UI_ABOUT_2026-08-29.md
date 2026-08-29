# Live Dispatch subscription UI and About repair — 2026-08-29

## Root causes
- Production Stripe Checkout, Dispatch subscription prices, webhook handling and membership grants were deployed, but the visible monthly/yearly plan cards were still readiness-only buttons.
- The public About page contained pre-payment wording that no longer matched the Separate Charges and Transfers marketplace flow.
- Dispatch Checkout itself needed the same current-policy server gate already used by the subscription catalog.
- Two attempted validators used Flutter 3.41.2; the production release is pinned to Flutter 3.44.6. The older SDK cannot resolve the repository's current `flutter_native_splash` / `meta` dependency set. No runtime dependency was changed for that CI-only mismatch.
- The production-SDK validator then found two invalid `const` wrappers around non-const Material buttons in the new helper; those exact qualifiers were removed before this retry.

## Repair
- Monthly and yearly Dispatch cards read the server catalog, show authoritative pricing and open `createDispatchSubscriptionCheckout`.
- Active subscribers are not offered duplicate checkout. Customer Portal is shown only when server readiness says it is available.
- VIP remains non-purchasable because no approved VIP Stripe price exists.
- `createDispatchSubscriptionCheckout` is wrapped in `requireCurrentPolicies` server-side.
- About copy accurately describes Stripe-processed buyer payments and delayed seller proceeds without describing Pipe Buyer as escrow/trust.
- Validation uses the exact production Flutter SDK, 3.44.6.
