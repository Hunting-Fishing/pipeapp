# Stripe seller capability dependency diagnostic — 2026-08-30

## Symptom

Live seller onboarding continued to fail in `createStripeSellerOnboardingLink` with Stripe code:

`capability_not_available_without_other_capability`

No connected seller account was created.

## What was ruled out

1. Stripe Connect platform liability acknowledgement was incomplete at first. The platform owner completed it in the Stripe Dashboard, but the capability dependency error remained.
2. Seller Accounts v2 calls were moved from the older preview to the current marketplace recipient preview while keeping other Stripe surfaces isolated. Production deployment and parity passed, but the same capability dependency error remained.
3. The production account creation payload still matches the intended marketplace recipient model: Express dashboard, platform-owned fees/losses, recipient configuration, and `stripe_balance.stripe_transfers` requested. We did not add merchant/card-processing capabilities merely to suppress the error.

## Root diagnostic gap

The Functions error contract retained only Stripe's error `code` and request ID. Stripe's explanatory `message` and rejected `param` were discarded at the callable boundary, so the specific missing dependent capability could not be proven.

## Repair

`firebase/functions/stripe_marketplace_commands.js` now:

- sanitizes Stripe support text and tokens,
- redacts email addresses and URLs from diagnostic text,
- captures Stripe error `message`, `param`, and request ID,
- exposes the sanitized Stripe explanatory sentence only for `capability_not_available_without_other_capability`,
- retains the sanitized fields in `HttpsError.details`,
- continues using the existing privacy-safe messages for all other known Stripe setup errors.

Regression coverage is in `firebase/functions/test/stripe_seller_onboarding_error_contract.test.js`.

## Do not repeat

- Do not add `card_payments` or merchant configuration until Stripe's own dependency message proves it is required for this account configuration.
- Do not globally change Stripe API versions as a diagnostic shortcut.
- Do not repeatedly click seller onboarding while the same error code is unchanged.
- Do not return Stripe raw error payloads, seller identity data, banking data, tax data, or unbounded provider messages to the Flutter client.

## Next acceptance step

After this diagnostic contract is deployed, perform one seller-onboarding attempt. Use the returned sanitized Stripe explanatory sentence and request reference to determine the exact missing capability or platform configuration before applying the next repair.
