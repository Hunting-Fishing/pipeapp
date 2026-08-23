# Pipe Buyer Feature Registry

Status: active compatibility inventory

## Purpose

This registry prevents autonomous refactors from treating existing capability as disposable implementation detail. It is an index, not a replacement for tests or domain trackers.

Rules:

- do not delete or materially reduce a registered capability without an explicit deprecation decision;
- when adding a durable user/admin capability, add or extend a registry entry;
- when refactoring, preserve routes, server commands, roles, security behavior, and lifecycle semantics associated with the feature;
- if implementation evidence conflicts with this registry, investigate and update the registry only after the real behavior is understood.

## Registry

| ID | Capability | Surface | Authority / persistence | Primary users | Status source |
| --- | --- | --- | --- | --- | --- |
| PB-MKT-001 | Marketplace browse/search/filter/sort/pagination | Marketplace discovery | Firestore + server query contracts | Public / users | `docs/PHASE_2_PROGRESS_AUDIT.md` |
| PB-MKT-002 | Listing details and structured industrial specifications | Listing detail | Firestore listings | Public / users | Phase 1.1 + Phase 2 |
| PB-MKT-003 | Create/edit listing workflow | Listing creation | Server/rules protected listing state | Sellers | Phase 1.1 |
| PB-MKT-004 | Saved listings and buyer discovery state | Buyer center | Firestore | Buyers | Phase 1.1 |
| PB-OFR-001 | Offers, counteroffers, acceptance, archive | Listing / transactions | Server-authoritative offer commands + revisions | Buyers / sellers | Phase 2 |
| PB-TRX-001 | Transaction lifecycle, confirmations, cancellation, disputes | Transaction views | Server state + immutable history | Buyers / sellers / admin | Phase 2 |
| PB-AUC-001 | Auctions, bids, Buy It Now, reserve handling, finalization | Auctions | Server-authoritative auction state | Buyers / sellers | Phase 2 |
| PB-WNT-001 | Wanted Ads lifecycle | Marketplace / Wanted | Server-owned lifecycle | Buyers / sellers | Phase 2 |
| PB-WNT-002 | Wanted/supply matching, ranked suggestions, contact, dismiss/restore | Listing detail / notifications | Bounded server matching + participant-safe records | Buyers / sellers | Phase 2 |
| PB-MSG-001 | Listing/transaction-aware messaging | Messages | Conversation records + security rules | Users | Phase 1.1 / Phase 2 |
| PB-DSP-001 | Dispatch job creation and public operational job board | Dispatch | Server-owned Dispatch state | Shippers / carriers | Phase 2 |
| PB-DSP-002 | Dispatch quotes/revisions/award/lifecycle | Dispatch workspace | Server commands + immutable history | Shippers / carriers | Phase 2 |
| PB-DSP-003 | Participant-private exact route/location details | Dispatch transaction | Protected private records | Awarded participants | Phase 2 |
| PB-ACC-001 | Authentication/account access | Login/account | Firebase Auth + App Check/security controls | Users | engineering/release runbooks |
| PB-TRU-001 | Account/provider verification and admin review | Account/admin | Protected claims and review records | Users / admin | admin runbooks |
| PB-MOD-001 | Reporting/moderation/support operational queues | User/admin | Server/rules + audit history | Users / admin | Phase 2 / runbooks |
| PB-NOT-001 | Notifications and safe delivery/recovery states | Account / app | Notification records/providers | Users / admin | Phase 2 |
| PB-BIL-001 | Dispatch monthly/yearly subscription checkout | Billing/account | Stripe + server configuration + webhook evidence | Dispatch users / admin | `docs/PAYMENTS_EXECUTION_TRACKER.md` |
| PB-BIL-002 | External-settlement Marketplace fee checkout | Transactions/billing | Stripe fee-only checkout + immutable fee snapshot | Buyers / sellers / admin | Payments tracker |
| PB-BIL-003 | Full Marketplace Stripe Connect money movement | Transactions | Stripe Connect + server ledger | Buyers / sellers / admin | Payments tracker; gated |
| PB-ADM-001 | Administrator operational surfaces | Admin | Protected server data/actions + audit | Administrators | Phase 1.1 / runbooks |
| PB-DSN-001 | Shared Pipe Buyer visual theme and adaptive design primitives | Entire Flutter app | `lib/core/design/pipe_buyer_theme.dart` | All | `docs/DESIGN_SYSTEM.md` |
| PB-QA-001 | Complete repository verification gate | Engineering | `tool/verify.ps1` | Engineering | README / engineering baseline |

## Compatibility review for autonomous work

Before a refactor that touches an entry above, the worker should identify:

1. current UI entry points;
2. relevant server commands/Functions;
3. persistent collections/documents and security rules;
4. roles/authorization requirements;
5. tests protecting the behavior;
6. any external/provider or production gate.

If one of those cannot be located, treat that as investigation work rather than permission to delete the feature.
