# Pipe Buyer Firestore schema (v1)

Firestore uses collections and documents rather than SQL tables.

- `users/{uid}`: private personal account and contact preferences. Firebase
  Auth email/phone claims are synchronized into protected ownership fields by
  `syncAccountVerification`; clients cannot mark themselves verified.
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
- `public_seller_profiles/{uid}`: public discovery index containing approved tag IDs and account type.
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
- `placeAuctionBid`
- `buyAuctionNow`
- `withdrawAuctionBid`
- `acceptAuctionBidBelowReserve`
- `createMarketplaceOffer`
- `acceptMarketplaceOffer`
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
