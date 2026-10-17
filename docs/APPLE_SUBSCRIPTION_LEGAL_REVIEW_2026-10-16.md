# Apple subscription legal-review checkpoint — 2026-10-16

## Scope

The public Terms and Privacy Policy now distinguish:

- Stripe-hosted Dispatch subscriptions purchased on the web;
- Apple App Store Dispatch Monthly and Dispatch Yearly purchases on iOS;
- Apple storefront-localized pricing and currency;
- automatic renewal, cancellation, subscription management, and refund routing;
- the App Store transaction metadata and pseudonymous app-account token retained by Pipe Buyer for server-side entitlement verification.

Worldwide App Store storefront availability is explicitly separated from the geographic availability of Pipe Buyer marketplace, Dispatch, payment, carrier, and regulated features.

## Required review before submission

These edits are a technical product-disclosure update, not legal advice or final legal approval. Before submitting the first auto-renewable subscription with an app version, the responsible legal/compliance reviewer should confirm:

1. the subscription, renewal, cancellation, refund, tax, and provider wording for every intended launch jurisdiction;
2. that the public Terms and Privacy URLs resolve to the exact reviewed versions referenced by the app and App Store Connect;
3. that App Store Connect privacy answers match the final client, Firebase backend, StoreKit transaction handling, diagnostics, and linked SDK behavior;
4. that worldwide storefront availability does not overstate where the underlying Pipe Buyer or Dispatch service is operational;
5. that the displayed United States prices and Apple-localized storefront prices match the products submitted for review.

Do not treat this checkpoint as approval to activate native billing, submit the subscriptions, or release an app build. Server verification, App Store Server Notifications, reconciliation, Sandbox/TestFlight acceptance, review screenshots, and the controlled release gate remain separate requirements.
