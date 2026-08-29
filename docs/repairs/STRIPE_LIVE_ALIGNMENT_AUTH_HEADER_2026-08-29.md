# Stripe Live Alignment — Custom Header Repair — 2026-08-29

Status: production completion repair
Firebase project: `flutter-flow-pipe`
Stripe account: Pipe Buyer (`acct_1U2QmKDkO07WMXyR`)

## Root cause

The first temporary billing activator failed with HTTP 401 because it was not publicly invokable at the 2nd-gen infrastructure layer. Adding Firebase `invoker: "public"` was necessary but not sufficient.

The second attempt still returned HTTP 401 even with `invoker: "public"`. The request used the standard HTTP header:

`Authorization: Bearer <random one-time Pipe Buyer token>`

For Cloud Run / Firebase Functions 2nd gen, the standard `Authorization: Bearer` channel is reserved for platform identity-token authentication. The random Pipe Buyer application token is not a Google-signed identity token, so the serving layer can reject it before the application handler receives the request.

The cleanup step successfully deleted the temporary endpoint after both failed attempts.

## Repair

The completion workflow separates infrastructure invocation from application authorization:

- temporary 2nd-gen HTTPS endpoints use `invoker: "public"` only so GitHub Actions can reach the handler;
- billing activation uses `X-PipeBuyer-Activation-Token` instead of `Authorization`;
- policy publication uses `X-PipeBuyer-Policy-Token` instead of `Authorization`;
- each token is a random 256-bit value created for one run and stored in Firebase Secret Manager;
- handlers compare tokens with `crypto.timingSafeEqual`;
- endpoints accept POST only;
- the billing write is a fixed pending-tax production profile and cannot enable full marketplace checkout;
- the policy publisher accepts only exact SHA-256 hashes of the already-live Terms and Privacy bytes;
- both temporary endpoints are deleted immediately after their authorized operation.

## Tax and payment boundary retained

This repair does **not** set Canadian tax registration ready and does **not** enable full buyer-to-seller marketplace Checkout.

The authorized pending-tax production profile remains:

- Stripe mode: production
- Stripe Connect seller onboarding: enabled
- Dispatch subscriptions: enabled
- Pipe Buyer marketplace fee billing: enabled
- Stripe webhook: verified
- reconciliation readiness: enabled
- Canadian tax registration: pending
- Stripe tax ready: false
- full buyer-to-seller Stripe Checkout: disabled
- affiliate payouts: disabled
- automatic financial-resolution/dispute overrides: disabled

## Regression rule

For Google Cloud Run / Firebase Functions 2nd-gen HTTP endpoints, never place a non-Google application bearer token in the standard `Authorization` or `X-Serverless-Authorization` headers. Use a dedicated application header for one-time release secrets, keep the infrastructure invoker policy explicit, verify the exact returned state, and always delete privileged temporary endpoints after use.
