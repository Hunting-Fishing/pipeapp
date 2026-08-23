# Dispatch Phase 4 - Directory Foundation

## Purpose

Phase 4 turns the structured provider profile work from Phase 3 into a searchable industrial service directory.

This first Phase 4 slice is deliberately list-first. It establishes a bounded public query, typed Directory entries, service/availability/business-type filters, public company cards, and explicit loading/error/empty states before map synchronization and direct quote workflows are added.

## Public source

The first query reads only:

```text
public_business_profiles/{uid}
    dispatchProfile {}
```

A profile becomes Directory-ready only when it has:

- operating name;
- at least one structured Dispatch service code;
- service-area label.

Private records are not queried by the Directory.

The Directory source must never read:

```text
business_private/{uid}
dispatchCredentials
private email or phone fields
exact private service-area geometry
credential document paths
```

## Entry fields used in the first slice

```text
operatingName
businessType
public description
website
serviceCodes[]
serviceAreaLabel
availability
emergencyCallout
remoteSiteCapable
approximate homeLocation
```

The approximate home point is the Phase 3 public projection. The exact owner-selected service-area geometry remains private.

## Trust boundary

This slice does not show a `Verified` badge.

Provider-supplied public profile fields are self-managed. A future public verification summary must come from a separate protected review state; it must not be inferred from an uploaded credential or from provider-supplied text.

## Bounded query

`MarketplaceDispatchDirectoryRepository` uses `loadFirestoreDocumentPage(...)` against `public_business_profiles` with a finite page size. The first screen filters the loaded public page locally.

This avoids an unbounded collection read while the later indexed query/map strategy is built.

## First filters

- company/service/area text search;
- structured service code;
- availability;
- business type;
- emergency callout;
- remote-site capable.

Geographic radius filtering and map/list synchronization are intentionally reserved for the next Phase 4 slices.

## Phase 4 sequence after this foundation

1. prove bounded public Directory repository + list/filter UI;
2. add paginated/indexed public Directory projection where needed;
3. add geography/radius filtering;
4. add open-map company pins and list/map synchronization;
5. add company detail page;
6. add capability filters;
7. wire Request Service / direct quote actions only after Directory identity and privacy are stable.

## Acceptance

Before awarding Phase 4 points for this slice:

- strict analyzer passes;
- Directory model/widget tests pass;
- Phase 3 credential/profile/equipment/geography regressions pass;
- Phase 2 taxonomy and Phase 1 navigation/auth regressions pass;
- source contract proves the Directory reads public profiles only and uses a bounded Firestore query;
- browser acceptance shows real seeded provider companies, service filters, availability filters, empty states and no private credential data.
