# Dispatch Phase 3 - Company Profile Persistence

## Status

Phase 3 remains in progress. The company-profile foundation gate passed locally on 2026-08-17, which verifies the company identity model and structured multi-service selection. Under the fixed 100-point ledger, that advances verified Dispatch progress from 41% to 45%.

Phase 4 remains blocked until the complete Phase 3 exit gate is green.

## Purpose of this slice

This slice turns the tested company-profile editor into a live saved profile for registered Dispatch providers without weakening the existing authoritative carrier approval workflow.

The existing `dispatch_carriers/{uid}` record remains the source for provider enrollment/review state. It is not directly mutated by the company-profile editor.

## Persistence bridge

This slice deliberately reuses existing owner-scoped business records that already have Firestore ownership rules:

- `business_private/{uid}` for the legal company/owner identity and other account-only Dispatch profile fields;
- `public_business_profiles/{uid}` for self-declared public Dispatch company information;
- `dispatch_carriers/{uid}` remains server-controlled provider enrollment/review state.

The Dispatch-specific fields are stored under a versioned `dispatchProfile` map so the feature does not overwrite unrelated business-profile fields.

This is an additive compatibility bridge. The long-term normalized `dispatch_profiles` / `dispatch_companies` model in the master plan remains the target before the full Directory is released.

## Privacy boundary

The public Dispatch projection includes only self-declared directory-safe fields:

- operating/trade name;
- business type;
- description;
- website;
- stable service codes;
- public service-area summary;
- availability;
- emergency-callout capability;
- remote-site capability;
- profile completeness.

The legal company/owner name is stored only in `business_private/{uid}` by this persistence layer. Email, phone, authentication identifiers, insurance documents, private addresses, and credential files are not copied into the public Dispatch profile.

No `Verified` flag is written by this client profile editor. Provider approval remains authoritative in `dispatch_carriers` and will be projected into the future Directory only through a controlled server-owned projection.

## User flow

For an existing registered provider:

`Dispatch -> Company Profile -> structured editor -> Save company profile`

For an unregistered user:

`Dispatch -> List your business -> existing provider enrollment`

The Phase 1 role-aware split is preserved.

## Engineering gate

`tool/verify_dispatch_phase3_profile_persistence.ps1` verifies:

- the already-passed Phase 3 foundation is recorded as 45% in the local master plan;
- registered-provider Company Profile wiring;
- owner-scoped public/private persistence contracts;
- legal identity does not enter the public persistence projection;
- strict analyzer for the profile model, repository, live page and Dispatch page;
- Phase 3 foundation regression;
- Phase 2 taxonomy regression;
- Phase 1 navigation regression;
- Dispatch auth reactivity regression;
- existing Firestore ownership-rule anchors.

The verifier backs up the exact local `marketplace_dispatch_page.dart` before wiring. If the gate fails, that product page is restored automatically.

## Browser acceptance required

After the engineering gate passes:

1. sign in with the registered carrier fixture;
2. open Dispatch;
3. select Company Profile;
4. verify existing carrier company/operating/service-area data pre-fills where available;
5. select several services from different taxonomy groups;
6. set business type and availability;
7. enter a public description and optional website;
8. save;
9. leave Company Profile and reopen it;
10. verify saved public fields return;
11. verify provider Dashboard, Jobs, Request Service and Directory still open normally.

Only after this browser acceptance should the persistence/edit points be awarded.
