# Pipe Buyer Dispatch Phase 0 Foundation Inventory

**Purpose:** Freeze the current Dispatch behavior before the Dispatch Network restructure begins.  
**Applies to branch:** `design/formal-beautification-foundation`  
**Status:** Phase 0 preservation contract  
**Last reviewed:** 2026-08-16

---

## 1. Existing client entry behavior

Dispatch uses the existing authenticated Pipe Buyer account. It does not have a second authentication system.

Current client behavior:

- `MarketplaceDispatchPage` requires a signed-in Firebase user.
- `MarketplaceDispatchDashboard` subscribes to `dispatch_carriers/{uid}` through `MarketplaceDispatchRepository.carrierProfile()`.
- when `dispatch_carriers/{uid}` does not exist, the current onboarding experience is shown;
- when `dispatch_carriers/{uid}` exists, the provider dashboard is shown;
- the current primary navigation is `Dashboard | Jobs | Post | Signup | Pilot`;
- Phase 1 may replace that navigation, but it must preserve provider lookup, existing jobs, quote/award behavior, private-route protection, and current data compatibility.

The provider/onboarding decision is the compatibility seam for the future role-aware Dispatch entry.

---

## 2. Current Firestore collections that Dispatch depends on

### Provider enrollment and equipment

`dispatch_carriers/{uid}`

Private provider enrollment/review record. Current fields include owner identity, operating/company name, verified account contact copied by trusted server code, service-area data, review status, availability state, review revision, and timestamps.

Important current statuses include:

- `pending_review`
- `active`
- `changes_requested`
- `rejected`
- `suspended`

`dispatch_carriers/{uid}/vehicles/{vehicleId}`

Current fleet/equipment records. Existing client fields include:

- `ownerUid`
- `name`
- `vehicleType`
- `maximumPayloadKg`
- `tareWeightKg`
- `grossWeightKg`
- `calculatedPayloadKg`
- `weightSource`
- `services[]`
- `pilotTruck`
- `available`
- notes/timestamps

`dispatch_carriers/{uid}/saved_quotes/{quoteId}` and `revisions/{revision}`

Provider-private reusable lane/rate planning history.

`dispatch_provider_review_events/{eventId}`

Immutable provider application/review history.

### Job/request state

`dispatch_jobs/{jobId}`

Signed-in-readable public Dispatch job-board record. Existing jobs include route labels, broad planning route state, requested date, load details, optional listing reference, source type, optional planning weight, bid count, status, and revision.

`dispatch_jobs/{jobId}/revisions/{revision}`

Immutable server-created job history.

`dispatch_job_private/{jobId}`

Private exact route/location and access information. It must stay separated from the signed-in public job-board projection.

`dispatch_job_private/{jobId}/revisions/{revision}`

Immutable private route/request history.

### Quote and award state

`dispatch_bids/{bidId}`

One current server-controlled carrier quote per carrier/job relationship. Client code reads participant-authorized quote state; direct client creation/update/delete is denied.

`dispatch_bids/{bidId}/revisions/{revision}`

Immutable quote history.

`dispatch_transactions/{jobId}`

Participant-only awarded-job transaction state, including customer/carrier identities, awarded bid, amount, schedule/progress/completion state and revision.

`dispatch_transactions/{jobId}/revisions/{revision}`

Immutable transaction history.

`dispatch_disputes/{jobId}`

Participant/admin-readable server review record for a disputed Dispatch transaction.

### Planning/support data

`dispatch_scales/{scaleId}`

Verified scale locations used by the Dispatch operations map.

`weight_catalog/{weightId}`

Reviewed equipment/spec planning references used by Dispatch weight/spec assistance.

`weight_suggestions/{suggestionId}`

User-submitted pending weight/reference suggestions with administrator review.

### Cross-cutting server state

`marketplace_command_receipts/{receiptId}`

Server-only idempotency receipts used by Dispatch commands as well as marketplace commands. Request IDs must remain retry-safe.

`platform_configuration/phase1_features`

The `dispatch` feature flag gates existing Dispatch reads and commands.

---

## 3. Existing callable/server command boundary

The current Dispatch command factory exposes exactly these Dispatch commands:

1. `submitDispatchProviderApplication`
2. `reviewDispatchProvider`
3. `createDispatchJob`
4. `updateDispatchJob`
5. `publishDispatchJob`
6. `submitDispatchQuote`
7. `awardDispatchQuote`
8. `updateDispatchTransaction`

### Preservation requirements

- provider application contact ownership comes from verified Firebase Authentication identity, not arbitrary client profile fields;
- provider approval/review state remains server-controlled;
- every Dispatch command is gated by the Dispatch feature flag and Dispatch abuse/rate-limit scope;
- command writes remain idempotent through deterministic command receipts;
- client-supplied route-calculation output remains rejected;
- job creation can remain `manual`, `marketplace`, or internal legacy `auction` source type until a deliberate compatibility migration is approved;
- `manual` jobs may omit `listingId`;
- listing-backed jobs must re-read authoritative listing state on the server;
- exact listing pickup coordinates come from protected listing location state when available;
- quote eligibility must continue to require an active approved provider and an available owned vehicle;
- vehicle payload checks continue to reject a selected vehicle that is below a known job planning weight;
- only the job owner can award a quote;
- awarded/completed job state cannot be silently changed through direct client document writes.

---

## 4. Current Firestore security boundaries

### `dispatch_carriers`

- provider enrollment record is private to the owner/admin;
- client create/update is denied because provider enrollment/review is authoritative server workflow;
- owner/admin may delete under the current Dispatch flag policy;
- vehicle reads require signed-in Dispatch access;
- vehicle create requires owner identity and matching `ownerUid`;
- saved quotes remain owner-private.

### `dispatch_jobs`

- signed-in users may read the job board while Dispatch is enabled;
- direct client create/update/delete is denied;
- revisions are signed-in readable and server-write-only.

### `dispatch_job_private`

Read is limited to:

- job owner;
- awarded carrier;
- administrator.

Direct client writes are denied.

### `dispatch_bids`

Read is limited to:

- the quoting carrier; or
- the owner of the associated job.

Direct client writes are denied.

### `dispatch_transactions` and `dispatch_disputes`

Read is limited to customer, carrier, or administrator as applicable. Direct client writes are denied.

### Planning catalogs

`dispatch_scales` and `weight_catalog` are signed-in readable while Dispatch is enabled and administrator-write-only. `weight_suggestions` accepts bounded user submissions but normal users cannot approve them.

---

## 5. Current composite indexes required by Dispatch feeds

The following indexes are part of the existing bounded-feed contract and must not be removed during the restructure:

### `dispatch_jobs`

1. `status ASC`, `createdAt DESC`
2. `createdByUid ASC`, `updatedAt DESC`

### `dispatch_bids`

1. `carrierUid ASC`, `updatedAt DESC`
2. `jobId ASC`, `updatedAt DESC`
3. `carrierUid ASC`, `jobId ASC`, `updatedAt DESC`

Existing query contracts also require bounded page sizes, aggregate counts for totals, job-constrained bid queries, and a one-result current-carrier-bid lookup.

---

## 6. Current service vocabulary that must remain mappable

The legacy service list currently includes:

- Flat deck
- Step deck
- Lowboy
- Winch
- Hotshot
- Pipe hauling
- Heavy equipment
- Oversize load
- General freight
- Oilfield service
- Picker / crane
- Towing / recovery
- Local haul
- Long distance
- Pilot / escort
- Route survey
- Traffic control
- Hazmat qualified

Phase 2 will replace display-string-only matching with stable service codes and categories. Existing service strings must receive explicit compatibility mappings rather than being silently discarded.

---

## 7. Existing user journeys that must stay green

### Provider enrollment

`Pipe Buyer account -> Dispatch -> provider application -> pending review -> administrator approval -> active Dispatch provider`

### Customer freight request

`Signed-in customer -> create manual or listing-linked Dispatch job -> open job`

### Carrier quote

`Active reviewed provider + available owned vehicle -> review open job -> submit quote -> pending quote`

### Award

`Job owner -> select valid pending quote -> award -> job status awarded -> participant transaction created`

### Private route protection

`Job owner/awarded carrier/admin -> private route detail` while unrelated signed-in users remain blocked.

---

## 8. Phase 0 test evidence already present in the repository

Existing automated coverage includes:

- Dispatch command-policy unit tests;
- Dispatch composite-index/query contract tests;
- Firestore rules tests for provider privacy, immutable review history, server-only job/quote/award state, bounded discovery and participant-only transaction history;
- Flutter Dispatch onboarding tests;
- Flutter Dispatch route/privacy contracts;
- the larger authenticated callable emulator integration, which already exercises provider application/review, job creation, carrier quote and award.

Phase 0 adds a smaller focused emulator journey so future Dispatch changes can run a fast preservation gate without depending only on the large whole-platform callable integration.

---

## 9. Freeze boundary for Phase 1+

The new Dispatch Network may add role state, companies, directory projections, service taxonomy, generic service requests, direct requests and matching. It must be additive until a separately reviewed migration proves compatibility.

Do not delete or repurpose these existing collections during Phase 1:

- `dispatch_carriers`
- `dispatch_jobs`
- `dispatch_job_private`
- `dispatch_bids`
- `dispatch_transactions`
- their revision collections

Do not weaken their current security rules to make the Directory easier to build. Public/search data belongs in a separate bounded projection with an explicit public schema.

---

## 10. Phase 0 inventory result

**Inventory status:** COMPLETE BY SOURCE REVIEW  
**Regression status:** pending focused local/emulator gate  
**Next permitted Phase 0 task:** run the focused baseline Dispatch regression bundle and record a green result in `DISPATCH_NETWORK_MASTER_PLAN.md` before Phase 1 begins.
