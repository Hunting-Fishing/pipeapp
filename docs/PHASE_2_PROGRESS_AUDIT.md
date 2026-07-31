# Phase 2 progress audit

Last updated: July 31, 2026

## Objective

Complete and stabilize the equipment, materials, Marketplace, Auctions,
Wanted Ads, Offers, messaging, and Dispatch product without exposing demo data,
unapproved automation, paid features, or regulated property workflows.

## Current checkpoint

- Overall Phase 2 engineering completion: **70% provisional**
- Active workstream: **Wanted Ads matching, alerts, and lifecycle — 90% provisional**
- Completed Phase 2 workstreams: **0 of 9 verified**
- Phase 1 remains **99% provisional**, Gate 7 is **86% provisional**, and
  **4 of 8 Phase 1 gates are verified** pending external release acceptance.

Percentages credit existing source and emulator work inherited from Phase 1.
They remain provisional until the Phase 2 web/mobile acceptance matrix passes.

## Workstream inventory

| Workstream | Estimate | Current evidence | Remaining exit evidence |
| --- | ---: | --- | --- |
| 1 — Production data states | 96% | Compiled demo Marketplace records and the demo seller identity were removed. A shared accessible state component now provides safe loading, empty, offline, unavailable, and retry presentation across Marketplace and Wanted results, Saved listings, Auctions, Offers and messaging, Dispatch, public profiles, seller listings, bid history, notifications, support, auction settlement, Dispatch transaction progress, public policy documents, and administrator review queues. Context-specific map and inline history states retain bounded, safe presentations. Backend exception details are classified without being exposed to users. | Pass the web plus physical-mobile acceptance matrix, including offline recovery and 200% text. |
| 2 — Search, filters, sorting, pagination, and geography | 96% | Indexed keyword search, structured filters, bounded cursors, query contracts, and required composite indexes exist. Search now keeps category, listing type, condition, price range, and deterministic sort in the server query rather than filtering a partial page afterward. Version 2 folds common French and Spanish place-name diacritics consistently across client and server. The existing search backfill is dry-run first, page/canary bounded, hard-locked to isolated staging for mutation, update-time protected, checkpointed before writes, clean-state validated, and conflict-safe to roll back. Dispatch rejects client-authored distance analytics, computes a server Haversine planning estimate, versions and hashes route inputs, separates exact locations from the public job board, and includes a tested dormant HERE truck-routing adapter. | Run the search backfill and Dispatch privacy migration through protected staging, activate and accept an approved truck-routing provider, add indexed geospatial radius querying, then run representative-volume acceptance. |
| 3 — Offers and transactions | 82% | Revision-safe offers, counteroffers, acceptance, archive, conversation linkage, transaction states, confirmations, cancellation, and disputes exist in source/emulators. | Staging and physical-device journey acceptance plus operational settlement ownership. |
| 4 — Auctions | 78% | Bid, Buy It Now, reserve privacy, below-reserve acceptance, withdrawal rules, expiry finalization, and settlement records exist behind launch locks. | Fee/invoice policy, staging acceptance, operational defaults/disputes, and controlled activation. |
| 5 — Wanted Ads | 90% | Wanted Ads use server-owned open, paused, fulfilled, and archived states. A bounded deterministic service compares new requests and For Sale listings, stores participant-only explainable scores and public snapshots, updates idempotent counters, and creates safe notifications. Both Wanted owners and supply sellers now see ranked matches in the existing listing detail flow, can open the related listing or request, start a conversation, dismiss or restore a suggestion, and review immutable revision history. Contact is idempotent and counted once. Keyword-watch writes are schema bounded. A single staging-only backfill path is dry-run first, checkpointed, resumable, clean-state aware, deterministic, and conflict-safe to roll back. | Deploy the new index and command to protected staging, run creation tests in both directions, execute the bounded backfill with approved staging credentials, review match quality with representative categories, add structured saved criteria, then pass web and physical-mobile acceptance. |
| 6 — Dispatch | 78% | Provider review, jobs, quotes, revisions, award, delivery lifecycle, immutable history, bounded queries, and notifications exist. Manual jobs now require mapped endpoints; route analytics are server owned; exact points, addresses, and access notes use participant-only records; awarded parties can view private route details; and the tested truck-routing provider contract fails closed while external routing is disabled. | Migrate existing public exact-location fields in staging, approve and activate the route provider, add saved routes, fleet-capacity matching, proof attachments, invoicing/payment boundary, and staging acceptance. |
| 7 — Weight and catalog confidence | 46% | Catalog fallbacks, weight disclosure, correction suggestions, and administrator review foundations exist. | Source attribution, confidence levels, model/pipe coverage, approval history, and verified calculations. |
| 8 — Analytics definitions | 38% | Offer, listing, auction, and Dispatch summaries expose several bounded metrics. | Versioned metric definitions, server-owned aggregation, timezone/currency rules, data-quality tests, and user explanations. |
| 9 — End-to-end acceptance | 24% | Unit, widget, policy, Rules, callable-emulator, release-manifest, and visual smoke coverage exists. | Complete buyer, seller, bidder, dispatcher, reporter, and administrator journeys on supported web and physical mobile targets. |

## Phase 2 foundation completed in this increment

- Added tracked standalone source for the exact Firebase Function ID `agent`.
- Upgraded the tracked runtime target to Node.js 22.
- Enforced administrator claims, MFA, and App Check in the handler contract.
- Disabled execution by default and reduced the disabled warm-instance default
  from three to zero while retaining explicit bounded capacity controls.
- Allowed only a non-mutating `status` operation; unapproved operations fail
  closed.
- Added deterministic audit records and tests for authorization, configuration,
  validation, disabled behavior, and enabled status behavior.
- Extended CI, release manifests, and deployed-function parity to cover both
  the Marketplace and standalone agent codebases.
- Removed compiled demo listings and demo seller identities from Marketplace
  runtime paths; development now uses the same real empty-state behavior as
  production.
- Added one production data-state contract for Marketplace, Wanted Ads, Saved,
  Auctions, Offers, messaging, Dispatch, public profiles, seller listings, and
  bid history. The component provides accessible live-region status, safe
  failure classification, bounded retry actions, and layouts that remain
  scrollable at 200% text.
- Added widget and classification tests for redaction, semantics, retry
  interaction, loading labels, and large-text behavior. The repository passed
  a clean analyzer and all **151 Flutter tests** at this checkpoint.
- Extended the same contract through account notifications, customer and
  administrator support, auction settlement, awarded Dispatch progress,
  public policy publication, notification-delivery review, account
  verification review, Dispatch provider review, and moderation queues. The
  former raw Firestore exception on the notifications page has been removed.
- Upgraded the existing Marketplace search backfill instead of adding a second
  indexing path. Mutation is restricted to `pipebuyer-5c77f`, requires an
  exact project confirmation, writes a tamper-evident checkpoint before any
  update, uses Firestore update-time preconditions, and supports conflict-safe
  rollback. Bounded canaries and `--require-clean` validation provide explicit
  rollout exit criteria.
- Corrected the search result pipeline so brand, model, description, town, and
  other server-token matches are not discarded by a second narrower client
  filter. Search filters and price/newest sorting now remain server-owned and
  paginated, backed by exact composite-index contract tests. Search index
  version 2 folds common French and Spanish place-name diacritics consistently
  in Flutter and Functions.
- Made Dispatch route analytics server-owned and reject client-authored
  distance, provider, status, duration, hash, and version fields. New jobs use
  a clearly labelled straight-line planning estimate until a reviewed truck
  route exists.
- Split exact Dispatch points, full addresses, postal details, and access notes
  into participant-only `dispatch_job_private` records. The public job board
  keeps broad operational labels; awarded carriers can open protected route
  details through the transaction card.
- Added a tested HERE Routing API v8 truck-mode request/response contract with
  vehicle weight and dimension parameters, critical-notice review state, route
  input hashing, and no embedded credential. External routing remains disabled
  pending provider, privacy, staging, and budget approval.
- Added one Wanted Ads matching path to the existing listing-create trigger.
  Candidate reads are capped at 100 records and each listing stores at most 20
  matches. Deterministic match and notification identifiers make retries safe;
  match documents expose only bounded public snapshots and are readable only
  by the request owner, supply seller, or an administrator.
- Added explainable product, specification, quantity, compatible-price-basis,
  and broad-location scoring. Owners can review ranked matches and follow the
  existing listing deep link. Wanted Ads now use fulfilled rather than sold
  semantics and cannot be converted into auctions.
- Added a rollout specification covering staging acceptance, privacy checks,
  an idempotent existing-listing backfill, and the intentional fan-out limits.
  No production backfill or deployment was performed in this increment.
- Added one participant-safe Wanted match action command for dismiss, restore,
  and contact outcomes. It enforces role-specific state transitions, request
  idempotency, one-time response counting, participant notifications, and an
  immutable revision event for every accepted transition.
- Integrated ranked Wanted matches into both sides of the existing listing
  detail experience. Request owners and supply sellers can inspect matching
  details, open the related listing, contact the other party through the
  established conversation workflow, dismiss or restore a suggestion, and
  review the permanent match activity history.
- Added a staging-hard-locked Wanted match backfill rather than a second live
  matching implementation. Dry runs are bounded; apply, resume, and rollback
  require the exact isolated staging project and confirmation. Checkpoints are
  tamper evident, existing deterministic matches are skipped, and rollback
  refuses any match that was contacted, revised, or changed by a participant.
- Verified the complete authenticated callable journey on the local Firebase
  Auth, Firestore, Functions, and Storage emulators. The suite passed listing,
  offer, auction, Dispatch, account, notification, and Wanted match lifecycle
  assertions with a clean exit code.
- The checkpoint passes a clean Flutter analyzer, all **154 Flutter tests**,
  all **143 Marketplace Function tests**, all **24 release-tool tests**, and a
  production web release build including the Wasm compatibility dry run.

## Next work in order

1. Deploy the reviewed Wanted command, Rules, and composite index only to the
   isolated staging project, then run publication and match delivery in both
   directions and retain participant-privacy evidence.
2. Run the bounded Wanted backfill dry run and canary in staging, verify its
   tamper-evident checkpoint, then review false-positive and false-negative
   samples with representative Marketplace categories before any full apply.
3. Run the search-index canary and full backfill only through protected
   staging, then retain the checkpoint and clean validation output.
4. Run the production data-state web/mobile offline and 200%-text acceptance
   matrix.
5. Run the Dispatch exact-location migration and truck-routing provider canary
   only through protected staging, then retain the evidence.
6. Add structured saved Wanted criteria and run the first complete Phase 2
   buyer, seller, and dispatcher acceptance slice.

No paid, regulated-property, or autonomous AI operation may be enabled by this
Phase 2 checkpoint.
