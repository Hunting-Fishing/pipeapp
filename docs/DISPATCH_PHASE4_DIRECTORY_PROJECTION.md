# Dispatch Phase 4 - Server-owned Directory projection

**Branch:** `design/formal-beautification-foundation`
**Phase:** 4 - Dispatch Service Directory + map
**Slice:** Directory projection/schema + security rules

## Purpose

Phase 4 starts by separating the searchable Dispatch Directory from provider-owned profile documents. Providers continue editing the bounded Phase 3 public company profile, while trusted Firebase Functions publish a smaller server-owned `dispatch_directory_entries/{companyId}` document for search, filtering, and map display.

This prevents a client from directly publishing Directory claims such as verification state or copying private insurance/contact/location fields into a searchable document.

## Source documents

The projection synchronizer reads:

- `public_business_profiles/{companyId}` - bounded provider-controlled public profile;
- `dispatch_carriers/{companyId}` - authoritative provider review/active state.

Both source paths trigger a refresh. If either source is missing, the provider is not active/available for hire, or the public profile lacks an operating name, service codes, or service-area summary, the Directory entry is removed rather than left stale.

## Directory schema v1

`dispatch_directory_entries/{companyId}` contains only bounded public search data:

- `schemaVersion`;
- `companyId`;
- public `companyName` / `operatingName`;
- stable `serviceCodes[]`;
- derived `capabilityTokens[]`;
- bounded `searchTokens[]`;
- approximate `publicLocation`;
- public `serviceAreaSummary`;
- bounded `publicServiceArea` region/place keys;
- approximate `mapPoint` and 6-character `geohash` when available;
- `availability`;
- `businessType`;
- `verified` (currently always `false` until a protected Pipe Buyer verification source is explicitly connected);
- emergency/remote-site flags;
- public description/website;
- profile completeness;
- server timestamp.

## Explicitly excluded

The projection does not copy:

- Auth UID/owner UID fields;
- email or phone;
- private/legal exact address;
- exact private service-area geometry;
- credential records;
- insurance policy/reference numbers;
- declared private insurance coverage amounts;
- uploaded evidence paths/files;
- internal moderation/review evidence;
- client-supplied verification claims.

The current bridge uses the existing provider document id as the Phase 4 `companyId`. A later company-identity migration may decouple company IDs from legacy provider IDs, but this slice does not introduce a second login or break `dispatch_carriers` compatibility.

## Security rule

Clients may read Directory entries only while Dispatch is enabled and the user is signed in. Client create/update/delete is denied for everyone, including administrator clients. Firebase Admin SDK functions bypass client rules and are the only normal publishing path.

## Verification

The focused Phase 4 gate runs:

1. Node syntax checks for the installer, projection module, and Functions index;
2. pure projection tests covering active/inactive providers, geography, search tokens, privacy exclusions, and unsupported verification claims;
3. source security-contract tests for Functions wiring and Firestore ownership boundaries;
4. a dedicated Firestore Rules emulator test proving signed-in reads and denied provider/admin client writes;
5. the Phase 3 acceptance finalizer without awarding any Phase 4 points.

Passing this engineering gate unlocks the next Phase 4 task: the Directory repository/query layer. Phase 4 points are awarded only after the corresponding implementation and acceptance criteria are complete.
