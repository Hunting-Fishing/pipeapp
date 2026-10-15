# Pipe Buyer App Store metadata draft

Status: local review draft only. Nothing in this file has been submitted to App Review.

Verified in App Store Connect on 2026-10-16:

- App Store app ID: `6795847447`
- Bundle ID: `Pipe.Buyerapp`
- Subscription group: `Pipe Buyer Memberships` (`22481870`)
- `pipebuyer_dispatch_monthly`: one month, USD 24.99 tier, 175 storefronts
- `pipebuyer_dispatch_yearly`: one year, USD 299.99 tier, 175 storefronts
- Both subscriptions: level 1, `Prepare for Submission`
- iOS version `1.0.0`: `Prepare for Submission`

Worldwide storefront availability does not mean every marketplace, Dispatch,
payment, carrier, or regulated feature is available in every jurisdiction.

## Proposed listing copy

### Subtitle

Oil & Gas Equipment Market

### Promotional text

Buy and sell oil and gas equipment worldwide. Browse listings, post wanted ads,
message securely, manage auctions, and coordinate eligible Dispatch services.

### Keywords

oil,gas,pipe,industrial,equipment,machinery,materials,auction,trucking,dispatch,marketplace

### Description

Pipe Buyer is an industrial marketplace for oil and gas equipment, materials,
and services.

Use Pipe Buyer to:

- Browse industrial equipment and material listings.
- Create listings and wanted ads.
- Make offers and participate in timed buying and auctions.
- Message buyers and sellers inside the app.
- Request and manage eligible Dispatch services.

Dispatch Membership

Choose a monthly or yearly auto-renewable subscription to access eligible
Dispatch membership features. Payment is charged to your Apple Account at
confirmation. The subscription renews automatically unless canceled at least
24 hours before the end of the current period. Manage or cancel it in your App
Store subscription settings.

Availability of marketplace, Dispatch, payment, carrier, and regulated
features varies by location and account eligibility.

Terms of Service: https://www.pipebuyer.com/terms

Privacy Policy: https://www.pipebuyer.com/privacy

## App Review notes draft

- Explain the exact navigation path from sign-in to the Dispatch membership
  paywall and the Restore Purchase control.
- Identify both approved product IDs and their visible durations/prices.
- State that Apple transactions are verified on the server before access is
  granted and that App Store Server Notifications V2 reconciles lifecycle
  changes.
- Supply review credentials only through App Store Connect. Never place test
  credentials, private keys, or secret values in this repository.
- Explain any feature, geographic, role, or account-eligibility gates that the
  reviewer may encounter.

## Assets and evidence still required

- App Store device screenshots for every required display class.
- One review screenshot for each subscription showing the paywall and purchase
  context.
- A signed release build selected on iOS version `1.0.0`.
- Sandbox evidence for buy, cancel, restore, renewal, expiration, billing retry,
  grace period, refund/revocation, delayed approval, and lost-response replay.
- TestFlight evidence on supported physical iPhone and iPad devices.
- Final legal/product approval of the listing copy and subscription disclosures.

