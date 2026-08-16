# Pipe Buyer Dispatch Phase 1 - Role-Aware Entry and Navigation

**Master plan:** `docs/DISPATCH_NETWORK_MASTER_PLAN.md`  
**Phase:** 1 of 7  
**Official overall progress before local acceptance:** 26%  
**Phase 1 starting score:** 3/10  
**Phase 1 target after full acceptance:** 10/10  
**Overall target after full acceptance:** 33%  
**Rule:** Phase 2 is blocked until the Phase 1 browser acceptance gate is green.

---

## 1. Scope implemented in this phase

Phase 1 changes the Dispatch entry architecture without changing the Phase 0 server contracts, collections, quote/award behavior, route privacy, provider approval, or current job schema.

The permanent top-level Dispatch sections become:

```text
Dashboard | Request Service | Directory | Jobs
```

The old top-level `Signup` and `Pilot` destinations are removed from primary navigation.

Provider/account actions move outside the main section navigation:

- no provider record: `List your business`;
- existing provider record: `Company Profile`.

Pilot/escort remains an existing capability and provider equipment tool. It is no longer treated as a special top-level product area because Pilot/escort belongs inside the broader service taxonomy, Directory, Request Service, and Jobs architecture.

---

## 2. Role-aware account state

`DispatchAccountState` provides a compatibility model before the normalized `dispatch_profiles` collection is introduced in Phase 3.

Supported role states:

- `customerOnly`;
- `providerOnly`;
- `customerAndProvider`.

Compatibility behavior:

- no `dispatch_carriers/{uid}` record -> customer-only;
- legacy provider record with no explicit role array -> customer + provider;
- future `dispatchRoles: ['provider']` -> provider-only;
- future `dispatchRoles: ['customer', 'provider']` -> dual-role.

This is deliberately additive. Phase 1 does not write a new role schema into production data.

---

## 3. Entry behavior

### Customer without a provider profile

Opening Dispatch lands on a customer home that presents:

- Request Service;
- Find Companies / Browse Directory;
- Browse Jobs;
- List your business.

The user keeps the existing Pipe Buyer authentication session. No second Dispatch login exists.

### Registered provider

Opening Dispatch lands directly on the existing provider Dashboard. The user does not land on signup first.

The provider can still access customer actions from the dashboard and top-level navigation.

### Provider profile management

`Company Profile` opens the existing provider enrollment/account manager as a separate screen instead of consuming a permanent navigation tab.

This preserves current provider application, review, service-area, fleet, and account behavior while Phase 3 prepares the expanded company model.

---

## 4. Directory boundary in Phase 1

The Directory receives a permanent top-level navigation location now, but Phase 1 does not pretend that company search is complete.

The Directory foundation screen identifies the future network categories and preserves the existing Pilot/escort provider equipment tool for registered providers during migration.

Actual searchable company profiles, filters, radius/geography queries, list/map synchronization, capability matching, and public directory projections remain gated to Phases 2 through 4.

---

## 5. Request Service boundary in Phase 1

`Request Service` currently routes to the existing protected trucking request workflow so Phase 0 behavior is preserved.

The generalized dynamic forms for Pilot, crane/picker, grading, mobile mechanic, and other non-freight service requests are Phase 5 work and must not be simulated with fake fields before the taxonomy and company capability model are complete.

---

## 6. Acceptance evidence required

Engineering gate:

- guarded integration only against the verified Phase 0 `marketplace_dispatch_page.dart` blob;
- strict analyzer clean;
- role-state unit coverage;
- desktop navigation widget coverage;
- mobile navigation widget coverage;
- customer first-entry action coverage;
- existing Dispatch onboarding/distance/privacy tests still green;
- server command-policy and query-index tests still green;
- isolated emulator provider signup/approval -> job -> quote -> award journey still green;
- private route remains hidden before award and available to the awarded carrier afterward;
- deterministic formal emulator fixtures remain intact after cleanup.

Browser visual acceptance:

1. Sign in as a customer fixture with no provider record.
2. Open Dispatch and verify customer home appears.
3. Verify only `Dashboard | Request Service | Directory | Jobs` appear.
4. Verify `List your business` appears and there is no permanent Signup tab.
5. Open Directory and verify the foundation screen renders without overflow.
6. Open Request Service and verify the existing trucking form still works.
7. Sign in as the approved carrier fixture.
8. Open Dispatch and verify the provider Dashboard appears automatically.
9. Verify `Company Profile` replaces `List your business`.
10. Verify there is no permanent Pilot tab and existing Pilot equipment remains accessible through the Directory foundation during migration.
11. Repeat the navigation check at a narrow/mobile viewport.

Only after all 11 visual checks pass may the master plan move to:

```text
Phase 1: 10/10 GREEN
Overall: 33/100 = 33%
Next permitted phase: Phase 2 - service taxonomy and structured capability model
```

---

## 7. Repair/change-control boundary

Phase 1 uses a guarded integrator that verifies the exact Git blob of the Phase 0 Dispatch page before making the localized navigation change. If the local file differs, the integrator stops before mutation and requires inspection of the actual file.

The verifier backs up the exact local page and restores it if formatting, analyzer, widget tests, server tests, emulator behavior, or fixture cleanup fails.

No speculative V1/V2/V3 repair chain is permitted for this phase.
