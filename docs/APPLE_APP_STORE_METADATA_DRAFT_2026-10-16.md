# Pipe Buyer App Store metadata draft

Status: local review draft only. Nothing in this file has been submitted to App Review.

Verified in App Store Connect on 2026-10-16, with the yearly price schedule
changed and re-verified on 2026-10-18:

- App Store app ID: `6795847447`
- Bundle ID: `Pipe.Buyerapp`
- Subscription group: `Pipe Buyer Memberships` (`22481870`)
- `pipebuyer_dispatch_monthly`: one month, USD 24.99 tier, 175 storefronts
- `pipebuyer_dispatch_yearly`: one year, current verified USD 249.99 tier,
  175 storefronts
- Both subscriptions: level 1, `Prepare for Submission`
- iOS version `1.0.0`: `Prepare for Submission`
- The app itself is free (`USD 0.00`) and available in all 175 storefronts.
- The Production App Store Server Notifications URL is unset; the verified
  Sandbox URL is configured separately.

Worldwide storefront availability supports global discovery and advertising;
it does not mean transactions or seller payouts are available worldwide. New
Marketplace and Timed Buying listings are currently USD-denominated, while
Stripe seller payout onboarding initially supports eligible sellers in Canada
and the United States. Marketplace payment, Dispatch, carrier, and regulated
feature availability remains subject to location and account eligibility.

## Launch-blocker audit

The following App Store Connect state was reviewed read-only on 2026-10-16.
No item in this section was submitted or published by that audit.

### Apple business account

- The Free Apps Agreement is active.
- The Paid Apps Agreement is `Pending User Info`.
- Digital Services Act trader compliance is incomplete.
- No bank account has been added.
- The Canadian GST/HST form and U.S. tax questionnaire both report missing tax
  information.

Paid subscriptions cannot be treated as launch-ready until the Account Holder
completes those identity, banking, and tax steps directly in App Store Connect.
Do not copy bank, tax, identity, or private contact values into this repository.

### App record and version metadata

- The app subtitle is blank and the category selection requires final review.
- Version `1.0.0` has no selected build.
- Promotional text and description are blank.
- App Store device screenshots and the optional header asset have not been
  supplied.
- Automatic release after approval is selected. Change to manual release for
  the controlled first launch unless the release owner explicitly approves
  automatic release.
- App Review sign-in and contact fields are populated, but their secret or
  personal values were not copied into this repository.
- The App Store support, marketing, and privacy fields still use the Firebase
  Hosting domain. The equivalent custom-domain routes returned HTTP 200 in the
  2026-10-16 audit and should replace them after final content-owner review:
  `https://www.pipebuyer.com/support`,
  `https://www.pipebuyer.com`, and `https://www.pipebuyer.com/privacy`.

### Privacy and accessibility

- The published App Privacy response currently lists only name, email address,
  phone number, physical address, user ID, device ID, and product interaction.
- That response omits 11 types already declared in the checked-in iOS privacy
  manifest: other contact information, other financial information, precise
  location, coarse location, emails/text messages, photos/videos, customer
  support, other user content, purchase history, crash data, and other
  diagnostic data.
- Source and dependency review found three additional types that must be
  reconciled into the final answers: Payment Info for stored payment-method
  state, Search History for account-linked saved alert queries, and Performance
  Data collected by Firebase Performance. Current evidence supports App
  Functionality and no tracking for all three; determine whether Performance
  Data is linked from the final Xcode archive privacy report rather than
  guessing from source alone.
- Generate and review the final Xcode privacy report so Runner, Swift Package,
  Firebase, and required-reason API manifests are aggregated. Do not publish
  the App Privacy update until every collected, linked, purpose, and tracking
  answer is confirmed against that exact release archive. Current source shows
  no ATT/IDFA, advertising SDK, data-broker, or cross-app tracking path.
- Accessibility Nutrition Labels have not been started. Do not claim a label
  until all common tasks, including sign-in, purchase, settings, listings,
  messaging, and Dispatch, pass Apple's device-specific criteria on physical
  iPhone and iPad hardware. VoiceOver also has an unresolved content gap:
  listing, message, and report images do not yet have consistent user-provided
  alt text or semantic labeling.

### Subscriptions and TestFlight

- The owner-approved prices are saved: USD 24.99 monthly and USD 249.99 yearly.
  Twelve monthly payments total USD 299.88, so yearly billing saves USD 49.89,
  or approximately 16.6%. Describe that as "about two months" or "about 17%";
  do not claim an exact two free months. The 2026-10-18 price verification does
  not activate production billing or replace Sandbox/TestFlight acceptance.
- Billing Grace Period is not configured. Use Sandbox-only configuration for
  the acceptance matrix before considering Production.
- Both subscription products still need a review screenshot.
- The first auto-renewable subscription and its group must be submitted with a
  new app version.
- The only uploaded TestFlight build is the older `1.0.0 (9)` candidate, which
  predates the current Apple billing source and reports missing compliance.
- There are no TestFlight groups or testers and no completed Test Information.
- Current source declares `1.0.5+6`; choose one marketing version and upload a
  fresh build number of at least `10` from the exact reviewed `main` commit.

## Proposed listing copy

### Subtitle

Oil & Gas Equipment Market

### Promotional text

Discover oil and gas equipment advertised worldwide. Browse USD listings, post
wanted ads, message securely, and access eligible Marketplace and Dispatch
features.

### Keywords

oil,gas,pipe,industrial,equipment,machinery,materials,auction,trucking,dispatch,marketplace

### Description

Pipe Buyer is an industrial marketplace where oil and gas equipment, materials,
and services can be discovered and advertised to a worldwide audience. New
Marketplace and Timed Buying listings are currently denominated in USD. Seller
payout onboarding initially supports eligible sellers in Canada and the United
States; transaction availability varies by buyer, seller, and location.

Use Pipe Buyer to:

- Browse industrial equipment and material listings.
- Create USD-denominated listings and wanted ads.
- Make offers and participate in timed buying and auctions.
- Message buyers and sellers inside the app.
- Request and manage eligible Dispatch services.

Dispatch Membership

Choose a monthly or yearly auto-renewable subscription to access eligible
Dispatch membership features. Payment is charged to your Apple Account at
confirmation. The subscription renews automatically unless canceled at least
24 hours before the end of the current period. Manage or cancel it in your App
Store subscription settings.

Apple shows the applicable localized storefront price before purchase. The
United States base prices are USD 24.99 monthly and USD 249.99 yearly. At those
prices, yearly billing saves about 17%, or about two monthly payments. Apple's
localized price and final purchase sheet control in each storefront.

Worldwide discovery and advertising do not imply worldwide transactions. New
listings use USD, seller payout onboarding initially supports eligible sellers
in Canada and the United States, and Marketplace payment, Dispatch, carrier,
and regulated features vary by location and account eligibility.

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
