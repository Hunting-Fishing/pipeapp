# Pipe Buyer Firestore schema (v1)

Firestore uses collections and documents rather than SQL tables.

- `users/{uid}`: private personal account and contact preferences.
  - `saved_locations/{locationId}`: private reusable yards, remote sites, storage/pipe locations, personal sale areas, and observed-interest pins. Each record stores purpose, exact point, privacy, nearby-notification opt-in, and radius.
- `public_business_profiles/{uid}`: publicly visible business profile. Structured `serviceArea` supports radius, selected places, or selected regions; normalized `serviceCountryCodes`, `serviceRegionKeys`, and `servicePlaceKeys` arrays support targeting and reporting queries.
- `business_private/{uid}`: legal name, private address and team membership.
- `public_listings/{listingId}`: searchable active/draft listings and seller-selected public location.
- `auction_private/{listingId}`: seller/admin-only reserve price and reserve
  total. Reserve amounts must never be stored in `public_listings`.
- `listing_private_locations/{listingId}`: exact address, coordinates and access notes; owner-only.
- `marketplace_catalog/{catalogId}`: administrator-managed pipe sizes, descriptions, brands and models.
- `geography_catalog/schema`: provider, hierarchy, normalization and dataset metadata.
- `geography_places/{placeId}`: normalized countries, states/provinces, regions, municipalities, towns and communities imported from the selected gazetteer.
- `marketplace_tags/{tagId}`: administrator-approved searchable marketplace taxonomy.
- `tag_requests/{requestId}`: user suggestions with pending, approved, or rejected moderation status.
- `users/{uid}/profile_tags/{tagId}`: approved selections and visibly pending user suggestions.
- `public_seller_profiles/{uid}`: public discovery index containing approved tag IDs and account type.
- `conversations/{conversationId}/messages/{messageId}`: listing-scoped buyer/seller chats.
- `offers/{offerId}`: server-created marketplace offer revisions. Participants
  may read their shared history, but clients cannot create, alter, accept, or
  archive offer documents directly.
- `auction_bids/{bidId}`: immutable auction bid records created and transitioned
  only by the marketplace command service.
- `marketplace_command_receipts/{receiptId}`: deterministic, server-only
  idempotency receipts for bid placement, Buy It Now, bid withdrawal,
  below-reserve acceptance, marketplace offers, and Dispatch commands.
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
- `dispatch_carriers/{uid}`: Dispatch provider profile.
  - `vehicles/{vehicleId}`: fleet vehicles, payload and services.
  - `saved_quotes/{quoteId}`: reusable lane pricing with current revision.
    - `revisions/{revision}`: immutable saved-lane pricing history.
- `location_requests/{requestId}`: controlled requests for protected listing locations.
- `users/{uid}/saved_listings/{listingId}`: saved ads.
- `users/{uid}/followed_sellers/{sellerUid}`: followed sellers and notification preference.
- `users/{uid}/notifications/{notificationId}`: server-created marketplace notifications.

## Marketplace decision boundary

Financial decisions are never accepted from a direct client document update.
The Flutter application calls the deployed callable command service, which
re-reads authoritative listing and offer state inside a Firestore transaction,
recalculates eligibility and minimums, writes the decision, and records an
idempotency receipt. The current callable commands are:

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

Firestore rules deny client writes to auction bid state, offer decisions,
Dispatch jobs, Dispatch quote state, and their immutable revision histories.
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
