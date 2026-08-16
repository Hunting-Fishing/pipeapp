# Pipe Buyer Dispatch Network Master Plan

**Status:** ACTIVE BUILD PLAN  
**Branch:** `design/formal-beautification-foundation`  
**Current engineering completion:** **24%**  
**Last updated:** 2026-08-16  
**Rule:** **Do not move to the next Dispatch phase until the current phase exit gate is 100% complete and all required tests are green.**

---

## 1. Product objective

Pipe Buyer Dispatch is not only a trucking load board. It will be an industrial service network that connects customers, shippers, owner/operators, private contractors, and large companies across North America.

The finished Dispatch product must support all of the following from one Pipe Buyer account:

- request trucking or field services without requiring a marketplace listing;
- request trucking from an existing marketplace listing;
- browse a searchable company/service directory;
- search by service type, geography, availability, capabilities, verification, and equipment;
- view providers on a list or map;
- register a company or owner/operator as a Dispatch provider;
- maintain services, equipment, service areas, credentials, availability, and public company information;
- send a direct quote request to one or more providers from the directory;
- publish an open service request for matching providers;
- receive and compare quotes;
- message, award, schedule, coordinate, and complete work in-app;
- preserve a structured activity record for trust, fraud prevention, analytics, and future matching systems.

The design target is simple enough for non-technical field users while retaining enough structured data to become a useful industrial network and matching platform.

---

## 2. Non-negotiable build rules

1. **One Pipe Buyer account.** Dispatch does not create a second username/password system.
2. **Role-aware entry.** A registered Dispatch provider goes directly to their Dispatch dashboard. Signup is not shown as a permanent navigation destination after registration.
3. **Customer and provider can coexist.** A single account may request services and also provide services.
4. **Directory first-class.** Pilot cars, cranes, graders, hotshot, mechanics, service trucks, oilfield support, and similar businesses are searchable company/service categories, not isolated tabs.
5. **Structured data first.** Important capabilities must use fields/taxonomy rather than only free text.
6. **Private data stays private.** Insurance documents, private contacts, exact private locations, credentials, and account-only records are not copied into public directory documents.
7. **No unsupported trust claims.** `Verified` is shown only for verification that Pipe Buyer actually performs or records.
8. **No next phase until the current exit gate is complete.** Partial work in a later phase does not increase the official percentage until the previous gate is green.
9. **Every Dispatch implementation change updates this file.** Completion percentage, checklist, evidence, and known blockers must stay current.
10. **Repairs are recorded once.** If a Dispatch repair is required, document root cause and the successful fix instead of repeating speculative repair chains.

---

## 3. Completion accounting

Completion is tracked with a fixed **100-point ledger**. One point equals one percent. Points are awarded only when the associated work is implemented and passes its phase acceptance criteria.

| Phase | Scope | Total points | Current earned | Status |
|---|---|---:|---:|---|
| 0 | Existing Dispatch foundation verified | 10 | 8 | IN PROGRESS |
| 1 | Role-aware entry and navigation architecture | 10 | 3 | BLOCKED BY PHASE 0 |
| 2 | Service taxonomy and structured capability model | 10 | 2 | BLOCKED |
| 3 | Provider/company profile system | 15 | 4 | BLOCKED |
| 4 | Dispatch Service Directory + map | 20 | 0 | BLOCKED |
| 5 | Standalone Request Service workflow | 15 | 3 | BLOCKED |
| 6 | Matching, direct requests, quotes, messaging and award | 10 | 2 | BLOCKED |
| 7 | Security, emulator fixtures, acceptance and release gate | 10 | 2 | BLOCKED |
| **TOTAL** |  | **100** | **24** | **24% COMPLETE** |

### Why the baseline is 24%

The repository already contains useful Dispatch infrastructure: shared Pipe Buyer authentication, a `dispatch_carriers/{uid}` provider profile lookup, provider onboarding/dashboard switching, Dispatch jobs and bids, optional listing-linked job creation, fleet records, service tags, saved quotes, and Dispatch transaction records. These existing capabilities earn baseline points.

The new network is still early because the service directory, normalized company model, full taxonomy, generic non-freight service request model, direct multi-provider requests, directory search/map, and complete role-aware navigation do not yet exist.

---

# PHASE 0 - Verify and freeze the existing Dispatch foundation

**Weight:** 10%  
**Current:** 8/10  
**Exit gate:** 100% required before Phase 1 earns additional points.

## Existing capability checklist

- [x] Existing Pipe Buyer Auth session is reused by Dispatch. **2 pts**
- [x] Provider profile lookup exists at `dispatch_carriers/{uid}`. **1 pt**
- [x] Dashboard vs onboarding decision exists based on provider profile presence. **1 pt**
- [x] Dispatch job creation supports optional `listingId` and manual source. **1 pt**
- [x] Dispatch jobs and carrier bids exist. **1 pt**
- [x] Fleet/equipment subcollection exists for provider vehicles. **1 pt**
- [x] Existing service tags include trucking, pilot/escort, route survey, traffic control, picker/crane, towing/recovery, and oilfield service. **1 pt**
- [ ] Document the exact current Firestore collections, server commands, rules, indexes, and production behavior that must be preserved. **1 pt**
- [ ] Add a focused baseline Dispatch regression test bundle before restructuring navigation/data. **1 pt**

## Phase 0 exit evidence

Required evidence:

- strict Dart analyzer clean for current Dispatch files;
- existing Dispatch repository tests green;
- Auth/emulator provider lookup proven;
- existing post -> quote -> award behavior proven before new schema is introduced;
- baseline schema/rules inventory committed to this plan or linked documentation.

**STOP CONDITION:** No Phase 1 product restructuring until the two unchecked items above are complete.

---

# PHASE 1 - Role-aware Dispatch entry and navigation

**Weight:** 10%  
**Current:** 3/10

## Target navigation

For normal signed-in users:

`Dashboard | Request Service | Directory | Jobs`

Provider/account action area:

- unregistered provider: **List your business / Join Dispatch**;
- registered provider: **Company Profile**;
- provider signup is removed from permanent primary navigation after registration;
- `Pilot` is removed as a top-level tab and becomes a service category throughout Directory, Request Service, and Jobs.

## Checklist

- [x] Existing dashboard/onboarding profile decision provides a reusable starting point. **3 pts**
- [ ] Introduce explicit Dispatch account state: customer only / provider / both. **1 pt**
- [ ] Auto-open provider dashboard for a registered provider. **1 pt**
- [ ] Build first-entry customer/provider choice for users without provider setup. **1 pt**
- [ ] Replace current five-tab navigation with the four core sections. **2 pts**
- [ ] Hide signup after provider registration and expose Company Profile instead. **1 pt**
- [ ] Mobile/desktop navigation tests and browser acceptance. **1 pt**

## Phase 1 exit gate

A new Pipe Buyer user, a customer-only user, a registered provider, and a dual-role user must each land in the correct Dispatch experience without a second login or confusing signup tab.

---

# PHASE 2 - Dispatch service taxonomy and capability model

**Weight:** 10%  
**Current:** 2/10

## Required top-level taxonomy

### Transportation

Flat deck, step deck, lowboy, winch truck, hotshot, pipe hauling, heavy-equipment hauling, general freight, local haul, long distance, oversize/overweight.

### Pilot and oversize support

Pilot/escort vehicle, lead car, chase car, high-pole car, route survey, traffic control, permit assistance.

### Crane and lifting

Picker truck, crane truck, mobile crane, knuckle boom, telehandler, forklift, rigging.

### Oilfield and industrial field services

Grading, road maintenance, snow removal, water truck, vacuum truck, hydrovac, mobile mechanic, mobile welding, tire service, fuel/lube service, towing/recovery, equipment servicing, field labour, site support.

The taxonomy must be designed to expand internationally without changing existing public records.

## Checklist

- [x] Existing flat service list provides initial vocabulary. **2 pts**
- [ ] Create stable service codes separate from display labels. **2 pts**
- [ ] Create category/subcategory hierarchy. **2 pts**
- [ ] Define structured capability fields per service type. **2 pts**
- [ ] Define equipment/capacity fields and units. **1 pt**
- [ ] Add taxonomy tests ensuring codes are unique/stable and public labels contain no obsolete terminology. **1 pt**

## Examples of structured capability fields

Pilot service: high-pole, lead/chase, 24-hour, route survey, jurisdictions served.  
Crane/picker: crane type, rated capacity, boom/reach, rigging available.  
Lowboy/haul: deck type, maximum payload, axle/configuration, oversize capability.  
Field service: emergency callout, 24/7, mobile unit, remote-site capability.

---

# PHASE 3 - Provider and company profile system

**Weight:** 15%  
**Current:** 4/15

## Target data ownership

Recommended additive model:

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

Existing `dispatch_carriers` behavior must be migrated/bridged carefully; do not delete it until compatibility and production migration are explicitly approved.

## Checklist

- [x] Current provider signup captures company/operating name and service area. **2 pts**
- [x] Current provider fleet records provide an equipment foundation. **2 pts**
- [ ] Company identity/public profile model. **2 pts**
- [ ] Multi-service structured selection. **2 pts**
- [ ] Equipment/fleet capability profiles. **2 pts**
- [ ] Service area and home-base map setup. **1 pt**
- [ ] Availability status: available now/today/this week/unavailable. **1 pt**
- [ ] Credential/insurance metadata with private document separation. **1 pt**
- [ ] Owner/operator and corporation/business-type support. **1 pt**
- [ ] Profile completeness + edit experience. **1 pt**

## Public profile principle

A public profile may display that a credential or verification exists only when the underlying workflow supports that statement. Private documents, email addresses, phone numbers, exact private addresses, authentication identifiers, and internal moderation data remain protected.

---

# PHASE 4 - Pipe Buyer Dispatch Service Directory

**Weight:** 20%  
**Current:** 0/20

This is the industrial Yellow Pages layer and a core Pipe Buyer data product.

## Search experience

Primary search inputs:

- service/category;
- city/region/current map area;
- radius/distance;
- availability;
- business type;
- verified profile state;
- equipment/capability requirements;
- 24/7/emergency;
- cross-border/remote-site capability where applicable.

Views:

- **List**;
- **Map** using the existing open-map/location system.

## Recommended search projection

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

This collection is a bounded public/search projection. Private company/account records are not queried directly for directory search.

## Checklist

- [ ] Directory projection/schema and security rules. **3 pts**
- [ ] Directory repository/query layer. **2 pts**
- [ ] Service/category filters. **2 pts**
- [ ] Geography/radius filters. **2 pts**
- [ ] Availability/capability filters. **2 pts**
- [ ] List result cards. **2 pts**
- [ ] Open-map company pins and map/list synchronization. **3 pts**
- [ ] Company detail profile from a directory result. **2 pts**
- [ ] Search-empty/error/loading states. **1 pt**
- [ ] Directory privacy, query-bound, and widget tests. **1 pt**

## Directory card minimum

Company name, primary services, general service area, availability, verified state when true, key equipment/capabilities, and actions for View Company / Message / Request Quote.

No fabricated ratings, job counts, or trust metrics.

---

# PHASE 5 - Standalone Request Service workflow

**Weight:** 15%  
**Current:** 3/15

The current manual Dispatch job path provides a base for standalone freight requests, but the new workflow must support services that are not freight loads.

## Request sources

```text
listing
standalone
directory_direct
```

## Generic request structure

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

## Checklist

- [x] Existing Dispatch job creation can be manual and listing ID is optional. **3 pts**
- [ ] First step: `What service do you need?`. **2 pts**
- [ ] Dynamic form fields based on service taxonomy. **3 pts**
- [ ] Standalone requests that do not require freight origin/destination when irrelevant. **2 pts**
- [ ] Listing-linked request remains supported. **1 pt**
- [ ] Unknown/confirm-later measurements supported where safe. **1 pt**
- [ ] Review/publish screen. **1 pt**
- [ ] Draft/edit/cancel lifecycle. **1 pt**
- [ ] Widget + repository + emulator tests. **1 pt**

Examples:

- Need a pilot truck tomorrow near Grande Prairie.
- Need a 45-ton picker at a lease site.
- Need grading/road repair at a remote site.
- Need lowboy transport for a marketplace excavator listing.

---

# PHASE 6 - Matching, direct quote requests, messaging and award

**Weight:** 10%  
**Current:** 2/10

## Checklist

- [x] Existing Dispatch bid/award mechanics provide a foundation. **2 pts**
- [ ] Match open requests to service codes + geography + availability. **2 pts**
- [ ] Select one or multiple directory companies and send direct request. **2 pts**
- [ ] Provider direct-request inbox/opportunity state. **1 pt**
- [ ] Comparable quote responses with provider/company context. **1 pt**
- [ ] In-app message handoff tied to request/company. **1 pt**
- [ ] Award/schedule/completion lifecycle works for freight and non-freight service requests. **1 pt**

## Matching rule

Matching begins deterministic and explainable. AI ranking may be added later, but a provider must first qualify through explicit service, location, availability, and capability fields. AI must not invent provider capabilities.

---

# PHASE 7 - Security, emulator fixtures, acceptance and release gate

**Weight:** 10%  
**Current:** 2/10

## Required emulator companies

Seed realistic **test-only** providers representing at minimum:

1. pilot/escort company;
2. heavy-haul/lowboy carrier;
3. crane/picker company;
4. grading/road-maintenance company;
5. hotshot/owner-operator;
6. mobile mechanic/service truck provider.

Each fixture must have different services, service areas, equipment, availability, and verification states so filters can be proven.

## Checklist

- [x] Existing formal emulator/Dispatch fixture infrastructure exists. **2 pts**
- [ ] New collection Firestore rules and indexes. **1 pt**
- [ ] Public directory projection cannot expose private profile/credential fields. **1 pt**
- [ ] Deterministic multi-company emulator seed. **1 pt**
- [ ] Customer acceptance journey. **1 pt**
- [ ] Provider acceptance journey. **1 pt**
- [ ] Dual-role account acceptance journey. **1 pt**
- [ ] Strict analyzer + targeted tests + full regression suite. **1 pt**
- [ ] Desktop/mobile visual acceptance + plan updated to 100%. **1 pt**

## Mandatory final end-to-end acceptance journey

```text
Customer
-> Dispatch
-> Directory
-> Pilot / Escort
-> Grande Prairie area filter
-> select provider(s)
-> Request Quote
-> provider receives request
-> provider submits quote
-> customer compares quote
-> customer messages provider
-> customer awards provider
-> schedule / coordinate
-> completion record
```

A second journey must prove a non-transport service such as crane/picker or grading.

---

## 4. Dispatch dashboard target states

### Customer dashboard

Must surface:

- Request Service;
- Find Companies;
- open requests;
- responses/quotes;
- scheduled/awarded work;
- saved companies;
- messages;
- recent directory/request activity.

### Provider dashboard

Must surface:

- company identity/profile completeness;
- availability toggle/state;
- new matching opportunities;
- direct requests;
- quotes out;
- awarded/scheduled work;
- fleet/equipment;
- services;
- service areas;
- credentials status;
- messages.

### Dual-role account

Must provide a simple customer/provider context switch or a combined dashboard without forcing a second account.

---

## 5. Data collection strategy

The Dispatch network should collect useful structured information while keeping forms simple.

Prefer yes/no, dropdowns, structured capacities, service areas, equipment, availability, and certification state over unstructured descriptions for important matching fields.

Examples:

```text
Pilot high-pole capable?       Yes
24/7 callout?                  Yes
Travel radius                  500 km
Cross-border                   No
Picker truck available         Yes
Rated picker capacity          45 ton
Lowboy available               Yes
Maximum declared payload       [structured value]
Remote-site capable            Yes
```

Free text remains available for company description, special notes, and unusual capabilities.

---

## 6. Integration roadmap - connect only after the core model is stable

Potential integrations should use protected server endpoints and be added only when the relevant phase is complete:

- OpenStreetMap/open mapping + current geocoding stack for directory geography and map pins;
- business verification sources where jurisdiction and licensing permit;
- insurance/credential verification providers where legally and commercially appropriate;
- messaging/notification infrastructure already present in Pipe Buyer;
- payment providers only after Dispatch pricing/fee/legal acceptance is approved;
- equipment/spec AI for load/service planning behind a server endpoint;
- future search/ranking service when Firestore search limits require a dedicated index.

No API key or privileged provider credential belongs in Flutter client code.

---

## 7. Progress reporting format

Every meaningful Dispatch build update must report exactly this block in this document:

```text
DISPATCH NETWORK STATUS
Overall: NN/100 = NN%
Current phase: Phase X - <name>
Phase completion: N/M points
Gate: BLOCKED | IN PROGRESS | GREEN
Last verified: YYYY-MM-DD
Analyzer: PASS/FAIL
Targeted tests: PASS/FAIL
Emulator journey: PASS/FAIL/NOT RUN
Visual acceptance: PASS/FAIL/NOT RUN
Blockers: <none or exact blocker>
Next permitted task: <one task from current phase>
```

### Current report

```text
DISPATCH NETWORK STATUS
Overall: 24/100 = 24%
Current phase: Phase 0 - Verify and freeze existing Dispatch foundation
Phase completion: 8/10 points
Gate: IN PROGRESS
Last verified: 2026-08-16
Analyzer: NOT RUN FOR THIS PLAN BASELINE
Targeted tests: NOT RUN FOR THIS PLAN BASELINE
Emulator journey: EXISTING DISPATCH FIXTURES ONLY
Visual acceptance: CURRENT LEGACY DISPATCH SCREEN OBSERVED
Blockers: baseline schema/rules inventory and focused Dispatch regression bundle still required
Next permitted task: complete Phase 0 inventory and baseline regression tests
```

---

## 8. Change-control rule

When a checklist item is completed:

1. implement the smallest coherent change;
2. run required analyzer/tests;
3. run the relevant emulator flow;
4. visually inspect when the change is user-facing;
5. update the checkbox and points in this file;
6. update the `DISPATCH NETWORK STATUS` block;
7. record any repair root cause if a failure required a repair;
8. only then begin the next unchecked item.

**A phase is not complete because the UI looks finished. It is complete only when its checklist, security behavior, tests, emulator behavior, and visual acceptance are all green.**

---

# Current next action

**Complete Phase 0.**

Do not redesign the Dispatch tabs yet. First inventory the current Dispatch Firestore collections/commands/rules/indexes and create a focused regression bundle proving the existing provider signup/dashboard, job post, quote, and award behavior. Once Phase 0 reaches **10/10**, update this document to **26%** and begin Phase 1 role-aware navigation.