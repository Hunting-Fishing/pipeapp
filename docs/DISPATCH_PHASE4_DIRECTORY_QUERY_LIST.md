# Dispatch Phase 4 - Directory query + provider list slice

Date: 2026-08-20
Branch: `design/formal-beautification-foundation`

## Purpose

This slice turns the earlier taxonomy-only Directory preview into a real provider-results experience backed by the server-owned Phase 4 projection:

```text
dispatch_directory_entries/{companyId}
```

The Flutter Directory must not query `public_business_profiles` directly for customer search. The projection is the privacy and eligibility boundary: only active, Directory-ready providers are published, while private contacts, exact addresses, credentials, evidence, Auth identifiers and unsupported verification claims stay out of the Directory document.

## Implemented in this slice

- bounded Directory repository/query layer;
- server-side primary query constraint for structured service, search token, availability or business type;
- local refinement for combined filters without creating an uncontrolled composite-index dependency;
- service filter using Phase 2 stable service codes;
- availability filter;
- business-type filter;
- emergency-callout and remote-site capability filters;
- real provider list cards;
- explicit loading, error and empty states;
- retained provider legacy tools below the customer Directory results;
- deterministic six-company local Directory fixture set;
- formal acceptance launcher integration for the Directory fixtures;
- retained last-successful results during filter refreshes;
- 180 ms debounce for rapid filter/search changes;
- generation protection so stale async results cannot replace newer filter results;
- inline refresh/error feedback instead of a blank full-page loading replacement.

## Deterministic local Directory fixtures

The formal local acceptance environment seeds six representative provider profiles:

1. Northline Heavy Haul - Edmonton / Western Canada;
2. Peace Country Pilot & Escort - Fort St. John / Dawson Creek;
3. Grande Prairie Picker & Crane;
4. Dawson Creek Road & Site Services;
5. Prairie Hotshot Services;
6. Northern Mobile Mechanical - Fort St. John.

The fixture seeder is hard-locked to the local Firestore emulator and calls the same server-owned Directory projection module used by Functions.

## Query discipline

Firestore supports only one array-contains constraint per query and complex combinations can require composite indexes. This first bounded repository therefore chooses one primary server-side constraint in this order:

```text
service code
-> search token
-> availability
-> business type
-> otherwise bounded Directory collection
```

The remaining selected filters are applied to the bounded returned entries in Flutter. This keeps the first Directory slice deterministic and avoids silently adding unreviewed indexes. Geography/radius query strategy is deliberately left to the next Phase 4 slice.

## Runtime filter lifecycle

Browser acceptance exposed an important lifecycle requirement that seeded widget tests did not originally reproduce: selecting a real Firestore-backed filter must not replace a usable Directory page with a blank/full-page loading state while the query refreshes.

The accepted pattern is:

```text
last successful Directory page
-> user changes filter
-> visible results refine immediately
-> debounce bounded remote refresh
-> keep prior results while waiting
-> accept only newest async completion
-> inline updating/error state
```

The permanent root-cause record is:

```text
docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md
```

The main Phase 4 query/list gate now installs and verifies this lifecycle automatically.

## Privacy rules

Provider list cards may show only information that exists in the Directory projection. Do not re-fetch private provider/business records to enrich the card.

Do not show fabricated ratings, job counts, trust scores or verification badges.

## Acceptance target

Browser acceptance should prove:

- Directory opens as real provider results rather than a taxonomy preview;
- six deterministic provider cards appear in the formal local environment;
- Lowboy service filter reduces results to Northline Heavy Haul;
- Pilot / Escort filter returns the Peace Country pilot provider and Northline where applicable;
- Hotshot selection keeps the Directory visible and updates results without a blank page;
- `Available now` reduces results correctly;
- Emergency callout and Remote-site filters work in combination;
- company/service/location text search works for exact indexed words such as `Fort`, `Grande`, `Northline`, `hotshot`;
- clearing filters restores the full result set;
- no private email, phone, exact address, policy number or credential evidence appears in result cards.

## Next slice

After browser acceptance of this list/query slice, add geography/radius controls and synchronized OpenStreetMap pins using the existing approximate `mapPoint` and service-area projection fields.
