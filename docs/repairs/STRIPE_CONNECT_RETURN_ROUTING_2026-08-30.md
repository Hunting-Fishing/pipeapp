# Stripe Connect return routing repair — 2026-08-30

## Scope

Stripe-hosted seller onboarding return/refresh routing only. This repair does not change buyer charges, marketplace fees, transfers, payouts, refunds, subscriptions, tax, webhook processing, or Stripe connected-account creation parameters.

## Production observation

A real authenticated seller test successfully opened Stripe-hosted onboarding and progressed through the seller information flow. After the seller confirmed the address step, Stripe returned the browser to Pipe Buyer, but the user landed at a generic fresh Pipe Buyer login/start surface instead of returning to seller payout setup. The user then had to manually find the seller payout area and open Stripe again to continue.

This proves the previously deployed Express-account creation repair is reaching Stripe-hosted onboarding. The remaining defect is Pipe Buyer return routing.

## Root cause

Production payment readiness was activated with these legacy callback URLs:

- `https://www.pipebuyer.com/?connect=return`
- `https://www.pipebuyer.com/?connect=refresh`

The application router had no code that interpreted either `connect` query value. The root `/` route simply opened the marketplace shell. Therefore Stripe's return was valid, but Pipe Buyer discarded the callback intent.

Stripe's `return_url` is a handoff back to the platform; the platform must then read the connected account state. Stripe's `refresh_url` is used when an Account Link is expired, already visited, or otherwise needs replacement; the platform must create a fresh Account Link rather than treating refresh as a generic home-page return.

## Corrected repair

The application now has one canonical authenticated seller-payout route:

`/account/seller-payouts`

Behavior:

1. Legacy `/?connect=return` redirects to `/account/seller-payouts?connect=return`.
2. Legacy `/?connect=refresh` redirects to `/account/seller-payouts?connect=refresh`.
3. The seller-payout route requires authentication, so if Firebase authentication must be restored, GoRouter keeps the intended callback location and returns the user there after sign-in.
4. `connect=return` calls the existing authenticated `refreshStripeSellerStatus` command and shows the seller a clear payout-readiness result.
5. `connect=refresh` calls the existing authenticated `createStripeSellerOnboardingLink` command to create a new single-use Account Link and redirects the seller back to Stripe.
6. On web, a refreshed Stripe link uses the current browser tab (`_self`) so the Pipe Buyer browser/auth context and callback remain together. Native clients continue to use the system browser for Stripe-hosted onboarding.
7. Opening `/account/seller-payouts` without a callback continues to show the normal seller payout settings page.

## Compatibility decision

The live Firestore payment-readiness document still contains the legacy root callback URLs. This repair intentionally supports them at the router boundary instead of mutating production payment configuration during the routing fix. That makes the repair deploy-safe and prevents a partial state where Stripe points to a new URL before the new application route is live.

A future controlled payment-readiness configuration revision may update the stored callbacks directly to the canonical route after this release is proven in production. The legacy redirects should remain for backward compatibility with already-issued Account Links.

## Regression coverage

`test/stripe_connect_return_routing_contract_test.dart` locks these conditions:

- the canonical seller-payout route exists;
- the route is authenticated;
- legacy root Connect return and refresh callbacks are recognized;
- return callbacks read Stripe seller status;
- refresh callbacks regenerate a Stripe Account Link;
- returned Stripe URLs are restricted to HTTPS Stripe hosts;
- the web refresh flow targets the current tab;
- client code does not read the private `payment_provider_accounts` collection directly.

## Do not repeat

- Do not point Stripe Connect callbacks at the generic `/` route without a router handler.
- Do not treat `return_url` as proof that onboarding is complete; read the connected account status.
- Do not treat `refresh_url` as a home-page redirect; create a new Account Link.
- Do not expose or persist Stripe Account Link URLs.
- Do not bypass authenticated Firebase callables to read or mutate seller payout state from the client.
- Do not alter buyer charge, fee, transfer, refund, or payout logic to repair a browser-routing defect.

## Production acceptance

After deployment, repeat seller onboarding from a signed-in Pipe Buyer account. Acceptance requires:

1. Stripe-hosted onboarding opens.
2. Stripe returns to the authenticated `/account/seller-payouts` experience rather than a generic start/login surface.
3. Pipe Buyer automatically reads and displays the seller's current Stripe payout readiness.
4. If Stripe requests a refreshed Account Link, Pipe Buyer creates a fresh link and returns to Stripe without requiring the user to manually find seller payout settings.
