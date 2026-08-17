# Pipe Buyer Dispatch Network Master Plan

**Status:** ACTIVE BUILD PLAN
**Branch:** `design/formal-beautification-foundation`
**Current verified completion:** **50%**
**Last updated:** 2026-08-17
**Rule:** **Do not move to the next Dispatch phase until the current phase exit gate is 100% complete and all required tests are green.**

---

## 1. Product objective

Pipe Buyer Dispatch is an industrial service network, not only a trucking load board. It connects customers, shippers, owner/operators, contractors, service companies, and large corporations across North America first, with an international-ready data model.

The finished product must support one Pipe Buyer account for all of the following:

- request trucking or field services without requiring a marketplace listing;
- request trucking from an existing marketplace listing;
- browse a searchable company/service Directory;
- filter by service type, geography, availability, capabilities, verification, equipment, and business type;
- view providers in list and map modes;
- register a company or owner/operator as a Dispatch provider;
- maintain services, equipment, service areas, credentials metadata, availability, and public company information;
- send direct quote requests to one or more providers;
- publish open service requests for matching providers;
- receive and compare quotes;
- message, award, schedule, coordinate, and complete work in-app;
- preserve structured activity data for fraud prevention, trust, analytics, and future matching.

The UX must remain simple enough for non-technical field users while still collecting structured data that can power matching and the Dispatch Yellow Pages.

---

## 2. Non-negotiable build rules

1. **One Pipe Buyer account.** Dispatch never creates a second login system.
2. **Role-aware entry.** Registered providers go directly to their provider dashboard.
3. **Customer and provider roles can coexist.**
4. **Directory is first-class.** Pilot cars, cranes, graders, hotshot, mechanics, service trucks, oilfield support, and similar businesses are searchable categories, not isolated tabs.
5. **Structured data first.** Important capabilities use stable codes/fields, not only free text.
6. **Private data stays private.** Insurance files, private contacts, exact private locations, credentials, and account-only fields are not copied into public Directory documents.
7. **No unsupported trust claims.** `Verified` is shown only when Pipe Buyer actually has a supporting verification state.
8. **No next phase before the current gate is green.**
9. **Every meaningful Dispatch change updates this plan/status.**
10. **Repairs are recorded once.** Root cause + proven fix go into `docs/REPAIR_LOG.md`.

---

## 3. Fixed 100-point completion ledger

| Phase | Scope | Total | Earned | Status |
|---|---|---:|---:|---|
| 0 | Existing Dispatch foundation verified | 10 | 10 | GREEN |
| 1 | Role-aware entry and navigation | 10 | 10 | GREEN |
| 2 | Service taxonomy and capability model | 10 | 10 | GREEN |
| 3 | Provider/company profile system | 15 | 13 | IN PROGRESS |
| 4 | Dispatch Service Directory + map | 20 | 0 | BLOCKED |
| 5 | Standalone Request Service workflow | 15 | 3 | BLOCKED |
| 6 | Matching, direct requests, quotes, messaging, award | 10 | 2 | BLOCKED |
| 7 | Security, fixtures, acceptance, release | 10 | 2 | BLOCKED |
| **TOTAL** |  | **100** | **50** | **50% COMPLETE** |

Points are awarded only after the corresponding implementation and acceptance criteria pass. Work prepared in the current phase does not unlock the next phase early.

---

# PHASE 0 - Verify and freeze existing Dispatch foundation

**Weight:** 10%
**Current:** 10/10
**Status:** GREEN

Completed:

- shared Pipe Buyer Auth session;
- `dispatch_carriers/{uid}` provider lookup;
- provider dashboard/onboarding decision;
- optional listing-linked/manual Dispatch jobs;
- jobs and carrier bids;
- fleet/equipment records;
- service tags;
- exact Firestore/server/rules/index inventory;
- focused provider -> job -> quote -> award regression bundle;
- private-route protection before/after award;
- deterministic emulator cleanup verification.

Reference: `docs/DISPATCH_PHASE0_FOUNDATION_INVENTORY.md`.

---

# PHASE 1 - Role-aware entry and navigation

**Weight:** 10%
**Current:** 10/10
**Status:** GREEN

Permanent top-level Dispatch navigation:

`Dashboard | Request Service | Directory | Jobs`

Completed:

- customer-only / provider-only / customer+provider account states;
- registered provider auto-dashboard entry;
- customer first-entry actions;
- Signup removed from permanent primary navigation;
- Pilot removed from permanent top-level navigation;
- `List your business` for unregistered providers;
- `Company Profile` for existing providers;
- desktop/mobile navigation tests;
- browser acceptance;
- auth-reactivity repair so Dispatch updates when Firebase Auth finishes after the page mounts.

Reference: `docs/DISPATCH_PHASE1_ROLE_NAVIGATION.md` and `docs/REPAIR_LOG.md`.

---

# PHASE 2 - Service taxonomy and structured capability model

**Weight:** 10%
**Current:** 10/10
**Status:** GREEN

Completed and browser accepted:

- stable service codes separate from display labels;
- category/subcategory hierarchy;
- structured capability fields;
- canonical units for payload, lift capacity, dimensions, distance, and tank capacity;
- legacy-label compatibility;
- taxonomy-backed Directory preview;
- uniqueness/stability/public-label tests;
- Phase 1 navigation regression;
- strict analyzer.

Primary groups:

- Transportation;
- Pilot & Oversize Support;
- Crane & Lifting;
- Oilfield & Industrial Field Services.

Reference: `docs/DISPATCH_PHASE2_SERVICE_TAXONOMY.md`.

---

# PHASE 3 - Provider and company profile system

**Weight:** 15%
**Current verified:** 13/15
**Status:** IN PROGRESS

The purpose of Phase 3 is to turn the legacy provider record into a structured industrial company profile that can safely power the future Directory.

## Target ownership model

```text
dispatch_profiles/{uid}
    roles[]
    companyId
    onboardingStatus
    preferences

dispatch_companies/{companyId}
    companyName
    operatingName
    businessType
    description
    logo
    website
    homeLocation
    serviceAreas
    availability
    publicVerificationSummary
    contactPreferences

dispatch_companies/{companyId}/services/{serviceId}
dispatch_companies/{companyId}/equipment/{equipmentId}
dispatch_companies/{companyId}/credentials/{credentialId}
```

Existing `dispatch_carriers` behavior remains live and must be bridged carefully. It is not deleted during this phase.

## Phase 3 checklist

- [x] Current provider signup captures company/operating name and service area. **2 pts**
- [x] Current provider fleet records provide an equipment foundation. **2 pts**
- [x] Company identity/public profile model. **2 pts**
- [x] Multi-service structured selection. **2 pts**
- [x] Equipment/fleet capability profiles. **2 pts**
- [ ] Service area and home-base map setup. **1 pt**
- [x] Availability: now/today/this week/unavailable. **1 pt**
- [ ] Credential/insurance metadata with private document separation. **1 pt**
- [x] Owner/operator and corporation/business-type support. **1 pt**
- [x] Profile completeness + edit experience. **1 pt**

## Current Phase 3 engineering slice prepared

The branch now contains:

- `lib/marketplace/marketplace_dispatch_company_profile.dart`;
- `test/marketplace_dispatch_company_profile_test.dart`;
- `docs/DISPATCH_PHASE3_COMPANY_PROFILE.md`;
- `tool/verify_dispatch_phase3_profile_foundation.ps1`.

This slice establishes:

- business identity model;
- owner/operator and company business types;
- structured multi-service selection using Phase 2 taxonomy codes;
- availability states;
- emergency-callout and remote-site flags;
- public profile projection with private-field exclusion;
- profile completeness;
- responsive profile editor.

**Phase 3 foundation gate passed locally on 2026-08-17. Company identity and structured multi-service selection are now verified.**

Phase 3 company-profile persistence browser acceptance passed on 2026-08-17. Saved profile fields survive leaving and reopening the page, and the Dispatch navigation remained healthy.

Phase 3 equipment/fleet capability browser acceptance passed on 2026-08-17. Existing and newly created fleet capability records remain available through Company Profile -> Manage fleet.

## Phase 3 remaining after the foundation gate

1. protected persistence + compatibility bridge from `dispatch_carriers`;
2. connect the Company Profile action to the new editor;
3. equipment/fleet capability normalization;
4. home-base + service-area map integration;
5. credential/insurance metadata with private-file separation;
6. emulator persistence tests;
7. browser acceptance;
8. only then mark Phase 3 = 15/15 and unlock Phase 4.

Public profiles must never expose private email, phone, Auth UID, insurance files, exact private addresses, or internal moderation data.

Reference: `docs/DISPATCH_PHASE3_COMPANY_PROFILE.md`.

---

# PHASE 4 - Dispatch Service Directory + map

**Weight:** 20%
**Current:** 0/20
**Status:** BLOCKED BY PHASE 3

This is the industrial Yellow Pages layer.

Required search/filter inputs:

- service/category;
- city/region/map area;
- radius/distance;
- availability;
- business type;
- verified profile state;
- equipment/capability requirements;
- 24/7 / emergency;
- cross-border / remote-site capability where applicable.

Views:

- List;
- Open-map map view with synchronized company pins.

Target public projection:

```text
dispatch_directory_entries/{companyId}
    companyName
    operatingName
    serviceCodes[]
    capabilityTokens[]
    searchTokens[]
    publicLocation
    serviceAreaSummary
    mapPoint/geohash
    availability
    businessType
    verified
    publicSummary
    updatedAt
```

Checklist:

- directory projection/schema + security rules **3 pts**;
- repository/query layer **2 pts**;
- service filters **2 pts**;
- geography/radius filters **2 pts**;
- availability/capability filters **2 pts**;
- list cards **2 pts**;
- map/list synchronization **3 pts**;
- company detail page **2 pts**;
- loading/error/empty states **1 pt**;
- privacy/query/widget tests **1 pt**.

No fabricated ratings, job counts, or trust metrics.

---

# PHASE 5 - Standalone Request Service workflow

**Weight:** 15%
**Current:** 3/15
**Status:** BLOCKED

Required request sources:

```text
listing
standalone
directory_direct
```

Target request model:

```text
dispatch_requests/{requestId}
    requesterUid
    requestedServiceCode
    sourceType
    listingId?
    title
    serviceLocation/pickup
    destination?
    timing
    equipmentOrLoadDetails
    dimensions?
    weight?
    requirements{}
    requestedCompanyIds[]?
    status
    createdAt
    updatedAt
```

Remaining checklist:

- service-first request start **2 pts**;
- taxonomy-driven dynamic fields **3 pts**;
- non-freight standalone requests **2 pts**;
- listing-linked compatibility **1 pt**;
- unknown/confirm-later measurements **1 pt**;
- review/publish **1 pt**;
- draft/edit/cancel **1 pt**;
- widget/repository/emulator tests **1 pt**.

---

# PHASE 6 - Matching, direct requests, quotes, messaging, award

**Weight:** 10%
**Current:** 2/10
**Status:** BLOCKED

Remaining:

- deterministic match by service + geography + availability **2 pts**;
- direct request to one/multiple Directory companies **2 pts**;
- provider direct-request inbox **1 pt**;
- comparable quote responses with company context **1 pt**;
- in-app message handoff **1 pt**;
- award/schedule/completion for freight and non-freight **1 pt**.

Matching begins deterministic and explainable. AI may rank later but must never invent provider capabilities.

---

# PHASE 7 - Security, fixtures, acceptance, release

**Weight:** 10%
**Current:** 2/10
**Status:** BLOCKED

Required emulator provider fixtures:

1. pilot/escort company;
2. heavy-haul/lowboy carrier;
3. crane/picker company;
4. grading/road-maintenance company;
5. hotshot owner/operator;
6. mobile mechanic/service truck provider.

Remaining:

- new Firestore rules/indexes **1 pt**;
- public projection privacy proof **1 pt**;
- deterministic multi-company seed **1 pt**;
- customer journey **1 pt**;
- provider journey **1 pt**;
- dual-role journey **1 pt**;
- strict analyzer + full targeted regression suite **1 pt**;
- desktop/mobile visual acceptance + 100% tracker update **1 pt**.

Mandatory final journey:

```text
Customer
-> Dispatch
-> Directory
-> choose service + area
-> select provider(s)
-> Request Quote
-> provider receives request
-> provider submits quote
-> customer compares
-> message
-> award
-> schedule / coordinate
-> completion record
```

A second final journey must prove a non-transport service such as crane/picker or grading.

---

## 4. Dashboard target states

### Customer dashboard

- Request Service;
- Find Companies;
- open requests;
- responses/quotes;
- scheduled/awarded work;
- saved companies;
- messages;
- recent Directory/request activity.

### Provider dashboard

- company identity/profile completeness;
- availability;
- matching opportunities;
- direct requests;
- quotes out;
- awarded/scheduled work;
- fleet/equipment;
- services;
- service areas;
- credentials status;
- messages.

### Dual-role account

Provide a simple customer/provider context switch or combined dashboard without a second account.

---

## 5. Structured data strategy

Prefer yes/no fields, dropdowns, normalized capacities, service areas, equipment, availability, and credential states over free text for matching-critical information.

Examples:

```text
Pilot high-pole capable?       Yes
24/7 callout?                  Yes
Travel radius                  500 km
Cross-border                   No
Picker truck available         Yes
Rated picker capacity          45 ton
Lowboy available               Yes
Maximum declared payload       structured value
Remote-site capable            Yes
```

Free text remains available for company description, unusual capabilities, and job-specific notes.

---

## 6. Integration roadmap

Connect only after the relevant core model is stable:

- OpenStreetMap/open mapping + current geocoding stack;
- business/licensing verification sources where legally appropriate;
- insurance/credential verification services;
- existing Pipe Buyer messaging/notifications;
- payment providers after legal/fee approval;
- protected server-side equipment/spec AI;
- dedicated search/ranking index if Firestore search limits require it.

No privileged API key belongs in Flutter client code.

---

## 7. Required status format

Every meaningful Dispatch build update reports:

```text
DISPATCH NETWORK STATUS
Overall: NN/100 = NN%
Current phase: Phase X - <name>
Phase completion: N/M points
Gate: BLOCKED | IN PROGRESS | GREEN
Last verified: YYYY-MM-DD
Analyzer: PASS/FAIL/NOT RUN
Targeted tests: PASS/FAIL/NOT RUN
Emulator journey: PASS/FAIL/NOT RUN
Visual acceptance: PASS/FAIL/NOT RUN
Blockers: <none or exact blocker>
Next permitted task: <one current-phase task>
```

### Current report

```text
DISPATCH NETWORK STATUS
Overall: 50/100 = 50%
Current phase: Phase 3 - Provider/company profile system
Phase completion: 13/15 points verified
Gate: IN PROGRESS
Last verified: 2026-08-17
Analyzer: Phase 3 equipment PASS
Targeted tests: Phase 3 equipment + Phase 2 + Phase 1 regressions PASS
Emulator journey: provider profile/fleet persistence preserved
Visual acceptance: company profile + equipment/fleet PASS
Blockers: mapped service area/home base and credential metadata remain
Next permitted task: build mapped service area/home-base persistence with privacy projection
```

---

## 8. Change-control rule

For every checklist item:

1. implement the smallest coherent change;
2. run formatter/analyzer/tests;
3. run emulator behavior when data/security changes;
4. visually inspect user-facing changes;
5. update checkbox/points/status;
6. record any repair root cause once;
7. only then begin the next unchecked item.

**A phase is complete only when checklist, security behavior, tests, emulator behavior, and visual acceptance are all green.**

---

# Current next action

Run the **Phase 3 company-profile foundation gate**. If green, continue inside Phase 3 with protected profile persistence and a compatibility bridge from the current `dispatch_carriers` provider record. Do not start the Directory implementation yet.
