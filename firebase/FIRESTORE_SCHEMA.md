# Pipe Buyer Firestore schema (v1)

Firestore uses collections and documents rather than SQL tables.

- `users/{uid}`: private personal account and contact preferences. Firebase
  Auth email/phone claims are synchronized into protected ownership fields by
  `syncAccountVerification`; clients cannot mark themselves verified. The
  private `primaryCommunityLocation` map stores the exact profile pin, full
  address, and private notes for the owner only.
  - `saved_locations/{locationId}`: private reusable yards, remote sites, storage/pipe locations, personal sale areas, and observed-interest pins. Each record stores purpose, exact point, privacy, nearby-notification opt-in, and radius.
  - `account_devices/{deviceHash}`: server-owned remembered app-installation
    history with a bounded platform label, first/last seen timestamps, last
    authentication time, and active/revoked state. Owners can read this
    history; callables perform all writes and remove entries after 180 days of
    inactivity. IP addresses, GPS locations, advertising IDs, and hardware
    fingerprints are not collected.
- `public_business_profiles/{uid}`: publicly visible business profile. Structured `serviceArea` supports radius, selected places, or selected regions; normalized `serviceCountryCodes`, `serviceRegionKeys`, and `servicePlaceKeys` arrays support targeting and reporting queries.
- `business_private/{uid}`: legal name, private address and team membership.
- `account_phone_registry/{sha256}`: server-owned mapping from a hashed,
  Firebase-verified E.164 phone number to one Auth UID. It supports duplicate
  account prevention without exposing phone numbers as document identifiers.
- `verification_requests/{uid}`: server-captured ownership and public-profile
  evidence for the current review revision. Users and MFA-authorized
  administrators may read it; only callable commands may submit or decide it.
- `verification_review_events/{uid-revision-event}`: immutable submission and
  administrator decision history with required review notes.
- `account_verification_command_receipts/{sha256}`: server-only retry receipts
  for verification submission and administrator decisions.
- `security_rate_limits/{sha256}`: private server-owned hourly command buckets
  containing bounded retry fingerprints, counts, expiry, and policy scope.
  Clients cannot read or write them; an expiration scheduler removes old data.
- `public_listings/{listingId}`: published searchable listings and the
  seller-selected public location. Unpublished drafts are never stored here.
- `marketplace_fee_classifications/{listingId}`: server-only administrator
  decision that can approve the discounted pipe fee for one exact listing,
  seller, catalog category/product type, and listing revision. Seller-selected
  listing fields never grant the discount; missing, revoked, stale, or
  mismatched decisions fail closed to the equipment fee.
- `marketplace_fee_classification_events/{eventId}`: immutable server-written
  audit history for pipe fee-class approvals and revocations.
- `marketplace_listing_drafts/{listingId}`: private, owner-readable,
  server-written listing payload, exact location, expected media counts, upload
  manifest, retry state, and 30-day expiry. Publication is a server transaction
  that validates the draft and uploaded Storage objects before creating the
  public listing and deleting the draft.
- `auction_private/{listingId}`: seller/admin-only reserve price and reserve
  total. Reserve amounts must never be stored in `public_listings`.
- `listing_private_locations/{listingId}`: exact address, coordinates and access notes; owner-only.
- `marketplace_catalog/{catalogId}`: administrator-managed pipe sizes, descriptions, brands and models.
- `geography_catalog/schema`: provider, hierarchy, normalization and dataset metadata.
- `geography_places/{placeId}`: normalized countries, states/provinces, regions, municipalities, towns and communities imported from the selected gazetteer.
- `marketplace_tags/{tagId}`: administrator-approved searchable marketplace taxonomy.
- `administrator_roles/{uid}`: server-owned active administrator directory used
  for secure notification routing; it does not grant authority by itself.
- `administrator_role_audits/{auditId}`: immutable operator-script history for
  administrator grants and revocations. Runtime authority comes from reviewed
  Firebase Authentication custom claims plus the signed per-session second
  factor claim.
- `tag_requests/{requestId}`: user suggestions with pending, approved, or rejected moderation status.
- `users/{uid}/profile_tags/{tagId}`: approved selections and visibly pending user suggestions.
- `public_seller_profiles/{uid}`: public discovery index containing approved
  tag IDs, account type, the legacy `baseCommunity` label, and a structured
  `primaryCommunity` broad-area map. `primaryCommunityGeoPoint`, town, region,
  and country fields support nearby discovery without exposing the private
  exact profile pin or address.
- `conversations/{conversationId}/messages/{messageId}`: listing-scoped
  buyer/seller chats created only by verified, throttled communication commands.
- `media_upload_authorizations/{authorizationId}`: server-created 15-minute
  grants binding a chat/report upload to its owner, target, storage path, exact
  byte size, and MIME type. Clients may read their own grant but cannot write it.
- `communication_command_receipts/{receiptId}`: server-owned idempotency
  receipts preventing duplicate messages and reports during client retries.
- `trust_reports/{reportId}`: server-validated user or automated moderation
  cases with private evidence references and administrator review state.
- `offers/{offerId}`: server-created marketplace offer revisions. Participants
  may read their shared history, but clients cannot create, alter, accept, or
  archive offer documents directly.
- `auction_bids/{bidId}`: immutable auction bid records created and transitioned
  only by the marketplace command service.
- `marketplace_command_receipts/{receiptId}`: deterministic, server-only
  idempotency receipts for bid placement, Buy It Now, bid withdrawal,
  below-reserve acceptance, listing draft creation/publication, marketplace
  offers, and Dispatch commands.
- `dispatch_jobs/{jobId}`: live user trucking requests. Stores route labels,
  optional mapped planning points, estimated distance, requested date, load
  details, current status, bid count and revision number. Creation, revision,
  publishing, and award are server-controlled.
  - `revisions/{revision}`: immutable request creation, edit, activation and
    award history.
- `dispatch_bids/{bidId}`: one current carrier quote per carrier and job.
  Submission, revision, and award are server-controlled. Carriers may revise
  pending quotes while the job remains open.
  - `revisions/{revision}`: immutable submitted, edited, awarded or archived
    quote history.
- `dispatch_transactions/{jobId}`: participant-only awarded-job state,
  schedule, structured proof of delivery, cancellation/dispute state, and
  current revision. Only server commands may write it.
  - `revisions/{revision}`: immutable award, acceptance, schedule, in-transit,
    delivery, closure, cancellation, dispute, and resolution history.
- `dispatch_disputes/{jobId}`: participant/admin-readable server review record
  for a disputed Dispatch transaction.
- `dispatch_carriers/{uid}`: Dispatch provider profile.
  - `vehicles/{vehicleId}`: fleet vehicles, payload and services.
  - `saved_quotes/{quoteId}`: reusable lane pricing with current revision.
    - `revisions/{revision}`: immutable saved-lane pricing history.
- `location_requests/{requestId}`: controlled requests for protected listing locations.
- `users/{uid}/saved_listings/{listingId}`: saved ads.
- `users/{uid}/followed_sellers/{sellerUid}`: followed sellers and notification preference.
- `users/{uid}/notifications/{notificationId}`: server-created marketplace notifications.
- `native_membership_accounts/{uid}`: server-owned StoreKit/Play account
  binding containing the UUID passed to the store as the account token.
- `native_membership_account_tokens/{sha256}`: server-only reverse index from a
  hashed native account token to exactly one UID. The unhashed token remains a
  field only so the server can detect hash/index corruption before applying an
  App Store notification.
- `native_membership_provider_state/{uid}`: server-owned current native
  subscription provider, verified product, original transaction/order,
  expiration, renewal, and reconciliation state.
- `native_membership_reconciliation_leases/{uid}`: server-only monotonic
  generation used to prevent older Store API responses from applying after a
  newer purchase verification, notification, or scheduled reconciliation.
- `native_membership_reconciliation_checkpoints/scheduled`: server-only durable
  page cursor, execution lease, result counts, and failure state for the bounded
  scheduled reconciliation runner. A failed page preserves its starting cursor
  so the next invocation retries rather than skipping failed accounts.
- `membership_billing_intents/{uid}`: server-only purchase/restore reservation
  shared by App Store, Google Play, and Stripe membership checkout. The opaque
  nonce, owner, target product/plan, billing channel, status, and expiry prevent
  two channels from passing their pre-charge gates concurrently. Native
  `active`/`pending` reservations span the delayed-approval window; completed
  nonces retain only a bounded exact-verification replay window so a lost
  response can be recovered without authorizing a new or different purchase.
- `dispatch_subscription_checkout_state/{uid}` and
  `vip_subscription_checkout_state/{uid}`: server-owned Stripe Checkout
  reservation state. Each in-flight attempt persists the exact sanitized form
  request used with its Stripe idempotency key; ambiguous retries replay that
  snapshot rather than recomputing configuration, customer, or promotion data.
- `app_store_notification_events/{sha256}`: server-only App Store Server
  Notifications V2 idempotency leases and outcomes. Signed payloads and private
  keys are never stored in this collection. `retentionExpiresAt` is a Firestore
  timestamp set at least 35 days after the latest processing attempt; production
  must configure a TTL policy on that field only after retention approval.
- `platform_configuration/native_membership_billing`: server-owned global and
  per-store readiness switches. Source availability does not imply that a
  mutation endpoint is exported or enabled. The recognized purchase fields are
  `enabled`, `appleEnabled`, `appleSandboxEnabled`, and `googleEnabled`. App
  Store lifecycle notifications additionally require the environment-specific
  `appleSandboxNotificationMutationsEnabled` or
  `appleProductionNotificationMutationsEnabled` switch; neither is implied by a
  purchase-readiness field.
- `platform_configuration/payment_provider_readiness`: server-owned Stripe
  activation and callback policy. Full buyer-sale checkout additionally
  requires `stripeFullGmvEconomicsApproved`, an auditable
  `stripeFullGmvEconomicsPolicyRevision`, an approved
  `stripeFullGmvPaymentMethodConfigurationId`, and positive integer values for
  `stripeFullGmvMaximumChargeMinorUsd`,
  `stripeFullGmvMaximumProviderFeeBps`,
  `stripeFullGmvMaximumProviderFeeFixedMinorUsd`, and
  `stripeFullGmvMaximumTaxUpliftBps`, and
  `stripeFullGmvMinimumNetRevenueMinorUsd`. Missing or zero economics values
  fail closed. These fields are conservative approved bounds, not provider
  fees guessed by the client or server. Runtime checkout rejects non-USD sales,
  sales over the approved charge limit, and sales whose snapshotted Pipe Buyer
  fee, after its affiliate commission, cannot cover the configured provider-cost
  ceiling plus minimum net revenue. When automatic tax is active, the provider
  cost base also includes the approved maximum tax uplift. Fee-only external
  settlement uses a separate readiness gate.
- `payment_provider_accounts/{uid}`: server-owned Stripe recipient state. New
  records store `mode`, `connectAccountApiVersion=v2`, account object/config,
  transfer and payout capability status, and payout holds. A legacy migration
  stores the exact old/new account IDs and modes in `legacyMigration` while the
  old account remains active; successful activation appends the old ID to
  `legacyStripeAccountIds` and archives its immutable identity under
  `legacy_accounts/{legacyAccountId}`. Clients cannot choose or swap accounts.
- `stripe_provider_migration_audit/{auditId}`: immutable MFA-administrator
  prepare/activation evidence, including operator, reason, seller, both Stripe
  account IDs, both modes, and whether the active account was replaced.
- Stripe-backed `marketplace_transactions/{transactionId}` records bind all
  later Checkout, webhook, refund/dispute, seller-release and recovery work to
  `stripeMode`. Full-GMV transactions also retain
  `stripeSellerDestinationAccountId`; legacy migration annotates resolved
  history with the old destination before activating a replacement account.

## Listing query budgets

User-facing listing discovery must remain bounded:

- Marketplace Browse, Auctions, public seller profiles, and owner listing
  history use 24-document pages with document cursors and duplicate-ID
  suppression.
- Auction filters apply `status`, `transactionType`, schedule, and owner
  constraints on the server using the declared composite indexes.
- The public map reads at most the 200 newest active listings and creates
  markers only for `exact` or `approximate` public locations.
- The Dispatch listing chooser reads at most the 50 newest active listings.
- Dispatch open jobs, owner requests, carrier quotes, per-job bids, and job/bid
  revision histories keep a live first page of 24 records and use document
  cursors for older pages. Queries constrain status, owner, carrier, or job on
  the server through declared composite indexes.
- Dispatch activity totals use Firestore aggregate counts. Fleet, saved-lane,
  verified-scale, and transaction-support reads use explicit safety caps.

Full-text and route-aware geospatial discovery require a dedicated indexed
search provider; increasing these Firestore caps is not a substitute.

## Marketplace decision boundary

Financial decisions are never accepted from a direct client document update.
The Flutter application calls the deployed callable command service, which
re-reads authoritative listing and offer state inside a Firestore transaction,
recalculates eligibility and minimums, writes the decision, and records an
idempotency receipt. The current callable commands are:

- `syncAccountVerification`
- `submitAccountVerification`
- `reviewAccountVerification`
- `cleanupExpiredSecurityRateLimits` (scheduled)
- `cleanupExpiredMediaUploadAuthorizations` (scheduled)
- `openMarketplaceConversation`
- `markMarketplaceConversationRead`
- `authorizeMarketplaceUpload`
- `confirmMarketplaceUpload`
- `sendMarketplaceMessage`
- `submitMarketplaceReport`
- `reviewModerationReport`
- `appealModerationDecision`
- `reviewModerationAppeal`
- `createSupportCase`
- `replySupportCase`
- `updateSupportCase`
- `publishPolicyDocument`
- `acceptRequiredPolicies`
- `setPolicyEnforcement`
- `placeAuctionBid`
- `buyAuctionNow`
- `withdrawAuctionBid`
- `acceptAuctionBidBelowReserve`
- `createMarketplaceOffer`
- `acceptMarketplaceOffer`
- `setMarketplaceListingFeeClassification` (MFA administrator only)
- `createDispatchJob`
- `updateDispatchJob`
- `publishDispatchJob`
- `submitDispatchQuote`
- `awardDispatchQuote`
- `updateDispatchTransaction`

Trust & Safety records are split by audience:

- `trust_reports/{reportId}` retains reporter evidence for administrators and
  the submitting reporter. Intake and every status change are server-only.
- `trust_report_events/{eventId}` is immutable administrator-only decision and
  appeal history.
- `moderation_notices/{reportId}` contains only the sanitized decision visible
  to the affected account; it never includes reporter identity or attachments.
- `moderation_command_receipts/{receiptId}` provides private retry safety for
  review and appeal commands.
- `support_cases/{caseId}` contains the owner-private current support state and
  server-derived response target.
- `support_case_events/{eventId}` is immutable customer-visible case history.
- `support_command_receipts/{receiptId}` makes intake and replies retry-safe.
- `platform_policies/{policyId}` exposes only current published policy metadata,
  including the reviewed HTTPS URL, version, and SHA-256 content hash.
- `policy_acceptances/{uid}` is the owner-private exact current acceptance set;
  `policy_acceptance_events/{eventId}` is immutable history.
- `policy_publication_events/{eventId}` and
  `policy_enforcement_events/{eventId}` are administrator-only audit records.
- `platform_configuration/policy_enforcement` activates commercial policy
  gating only after every required document has been published.

Firestore rules deny client writes to auction bid state, offer decisions,
Dispatch jobs, Dispatch quote state, and their immutable revision histories.
All marketplace callable Functions share the typed deploy-time parameter
`PIPE_ENFORCE_APP_CHECK`. It defaults to `false` so registered clients can be
distributed and measured before enforcement. Follow
`docs/APP_CHECK_ROLLOUT.md`; do not enable it before the Firebase Console
providers and current client releases are verified.
Auction sellers retain direct access only to the explicit notification
preferences on their own live auctions. Reserve amounts are read from
`auction_private` by server commands and the owning seller's analytics; public
auction readers do not receive the amount or reserve-progress calculation.

Exact listing coordinates must never be stored in `public_listings` unless the seller explicitly selects exact visibility.

## Property and rights control plane (design foundation)

Property publishing is disabled. The following collections are reserved for
server-controlled, eXp-reviewed North American property workflows:

- `jurisdiction_policies/{policyId}`: versioned country and subdivision policy
  packs. Country baselines never authorize production features.
- `brokerage_entities/{entityId}`: responsible eXp legal entities by country.
- `brokerage_licenses/{licenseId}`: jurisdiction-specific brokerage licences
  with validity and verification records.
- `professional_profiles/{profileId}`: controlled professional identities.
- `agent_licenses/{licenseId}`: agent, broker, and compliance credentials.
- `role_assignments/{assignmentId}`: least-privilege jurisdiction roles.
- `compliance_reviews/{reviewId}`: approval, return, rejection, suspension, and
  escalation decisions.
- `property_listings/{listingId}`: future controlled property/rights records.
  All client access is denied until the server command layer is implemented.
- `property_audit_events/{eventId}`: future immutable server audit stream.
- `property_feature_flags/{flagId}`: independently switchable jurisdiction
  capabilities and emergency suspension controls.

The design-only policy fixtures are stored under
`firebase/config/jurisdictions/`. They cover Canada, the United States, and
Mexico, but do not contain a subdivision licence, compliance owner, legal
approval, or enabled publishing feature and therefore cannot authorize a live
listing.
