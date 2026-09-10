# Pipe Buyer Active Product Build Plan — 2026-09-01

## Authority and scope

This file is the active implementation sequence for the current Pipe Buyer product build. Launch-readiness status remains governed by `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`; older Phase 1.1, Phase 2 and Dispatch percentages are historical checkpoints unless the current audit carries a requirement forward.

North America remains the first operating scope. The product must stay simple for non-technical field users while preserving server-authoritative payments, App Check, Firebase Rules, moderation evidence, exact release controls and existing repair boundaries.

## Release sequence

### Release 1 — Simple Pipe Buyer flow

**Production status: COMPLETE.** PR #168 is deployed from exact application SHA `996bd3f782a89639aaf12527193cb1ecf4d92f84` by protected production run `33493435243` (#56) with App Check `enforce`. The run passed analyzer/tests, release-manifest and Function-parity controls, both Functions codebases, Firestore rules, authenticated callable workflows/retries, exact web build, Firebase deployment, post-deploy parity, release identity, and production mobile/desktop visual acceptance. Evidence: `firebase-release-evidence-production-996bd3f782a89639aaf12527193cb1ecf4d92f84-33493435243` (artifact `9794901956`) and `visual-acceptance-production-33493435243` (artifact `9794932834`).

- Make Home start with four understandable intents: Browse inventory, Sell something, Request service, Post wanted / RFQ.
- Keep mobile navigation to Home, Browse, Sell, Messages and Account.
- Keep the existing desktop grouped Marketplace / Deals / Logistics navigation.
- Route Home intents into existing Marketplace, listing, Wanted and Dispatch workflows instead of creating duplicate systems.
- Do not change Firebase schemas, Stripe settlement, moderation evidence or release controls.

### Release 2 — Marketplace journey closure

Prove and refine ordinary-user buyer, seller, offer/counteroffer, Timed Buying, Wanted, messaging/block/report, payment/support and Dispatch-handoff journeys. Every transaction surface must show current status, next action and responsible party.

### Release 3 — Dispatch Directory

**Production status: COMPLETE.** Exact SHA `a6bc1ffb4d887af39ac4e9a8ea75851e0a39d214` is live from protected production run `33538007190`. The retry passed analyzer/tests, release-manifest and Function-parity controls, Functions validation, Firestore rules, authenticated callable workflows/retries, exact web build, Firebase deployment, post-deploy parity, release identity, and production mobile/desktop visual acceptance. Evidence: Firebase release artifact `9848902855` and visual acceptance artifact `9848948030`. The proven transient Gen-2 rollout repair is recorded in `docs/repairs/R3_FIREBASE_GEN2_TRANSIENT_ROLLOUT_2026-09-03.md`; do not reopen Dispatch Directory code for that resolved deployment signature.

Validate representative provider records, privacy classes, filters, location/radius behavior, list/map synchronization, company details and direct Request Quote.

### Release 4 — Dispatch Request Service

**Build status: ACTIVE.** Work is isolated on `codex/r4-dispatch-request-service` in draft PR #181 from the exact deployed R3 SHA.

Finish the service-first wizard with taxonomy-driven questions, freight and non-freight paths, direct-provider requests, open requests, review, edit and cancel.

Current preserved R4 boundaries:

- reuse the existing `dispatch_jobs` command/revision architecture for open requests;
- keep Directory direct-provider Get Quote on its private business-conversation path rather than leaking it into the signed-in-readable open job collection;
- derive freight-route versus field-service semantics from the approved Dispatch service taxonomy;
- keep contact preference and cancellation reason private;
- use server-authoritative pre-award cancellation and invalidate pending carrier quotes when an open request is cancelled;
- reuse the existing upload-authorization/Storage security pattern for supporting photos/documents rather than permitting arbitrary client Storage writes;
- do not expand quote comparison, award, scheduling, proof/BOL, completion or freight settlement beyond what R4 needs; those remain Release 5/6 boundaries.

### Release 5 — Dispatch quotes and jobs

Complete provider inbox, structured quotes/revisions, quote comparison, messaging, award, schedule, work, proof/BOL and completion.

### Release 6 — Dispatch financial ledger

Only if per-job transaction fees are intended: build a freight-specific immutable ledger, charge/fee/provider-proceeds records, refunds, disputes, payout state and reconciliation before enabling job charging.

### Release 7 — Native store release

Complete physical Android/iOS acceptance, App Check attestation, notifications/deep links, native subscription verification/reconciliation, accessibility and store publication.

### Release 8 — Advanced platform

Truck routing/ETA, saved routes, fleet-capacity optimization, catalog provenance/confidence, analytics definitions and country-by-country international expansion.

## Build control

Every slice follows requirement -> existing-code inspection -> bounded change -> focused tests -> full regression -> acceptance -> repair record when a defect is found -> merge -> exact-SHA production release. Once a root cause and repair are proven, record and preserve that repair boundary instead of repeating speculative fixes.
