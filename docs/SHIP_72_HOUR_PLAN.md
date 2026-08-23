# Pipe Buyer 48–72 Hour Ship Plan

Status: active acceleration plan  
Target: fully operational core Pipe Buyer application as quickly as safely possible  
Priority rule: finish working user journeys and revenue-enabling code before optional depth or broad cleanup.

## Definition of "operational" for this sprint

The application is operational when the required core journeys work against real non-mock application code, repository verification is green, controlled staging acceptance is complete, production-only gates are clearly separated, and a human can approve an exact verified release.

This sprint does **not** require autonomous activation of legally/provider-gated capabilities such as full Stripe Connect money movement, unresolved tax declarations, regulated property workflows, or destructive production migrations.

## Phase 0 — Autonomous builder graduation for bounded work

Complete before multi-hour unattended coding:

1. builder static governance tests green;
2. guard fault suite green;
3. recovery fault suite green;
4. compatibility inventory tests green;
5. complete Pipe Buyer `tool/verify.ps1` green on a clean baseline;
6. one watched bounded worker completes one task with no unexpected files;
7. reviewer blocks at least one seeded material regression;
8. real timeout/stall behavior proven to leave the last verified commit intact.

Remote GitHub Actions failure may remain an external merge blocker if it is conclusively classified as pre-runner/account infrastructure and local verification is green. It does not authorize merging to `main` without required remote checks.

## Phase 1 — Core Marketplace journeys

Finish and verify before lower-value enhancements:

- browse/search/filter/sort/pagination using production data paths;
- listing detail and seller/public profile;
- authenticated create/edit/publish listing;
- saved listings/discovery state;
- create/counter/accept offer lifecycle;
- buyer/seller transaction lifecycle and recovery states;
- listing/transaction-aware messaging;
- loading, empty, denied, offline/retry and error states;
- phone plus desktop/web usability.

Avoid broad visual rewrites. Use the existing Pipe Buyer design system and repair only inconsistent or broken surfaces that affect completion.

## Phase 2 — Dispatch and first revenue path

Dispatch is the first subscription revenue target.

Repository-verifiable priority:

1. confirm/build Monthly and Yearly subscription actions in Flutter;
2. ensure redirect success never grants entitlement without provider evidence;
3. complete recurring lifecycle UI/states;
4. complete customer self-service subscription management path;
5. complete Dispatch job create/publish/quote/award/update journey;
6. preserve private exact route/location data boundaries;
7. complete carrier/provider/fleet operational surfaces required for bidding;
8. complete emulator/integration tests and admin recovery states.

Live Stripe/tax/provider evidence remains human/external and is recorded rather than fabricated.

## Phase 3 — Wanted Ads and Auctions

Wanted Ads:

- create/edit/lifecycle;
- saved structured criteria;
- matching/contact/dismiss/restore;
- representative match quality and negative paths.

Auctions:

- create/convert listing;
- bid/withdraw/buy-now/reserve/finalization;
- transaction states;
- default/dispute operational handling required for safe use;
- fee/invoice UX consistent with active payment policy.

Activation requiring unresolved billing/tax/provider evidence remains gated.

## Phase 4 — External-settlement Marketplace fee

Complete code/test layers for the second revenue target:

- both-party external settlement confirmation;
- one-party confirmation cannot start billing;
- server-generated immutable fee amount;
- duplicate checkout/webhook protection;
- success/failure/receipt/admin states;
- reconciliation identifiers and exception handling.

Do not activate until applicable tax and provider readiness evidence is approved.

## Phase 5 — Admin, trust and operations

Required operational surfaces:

- account/provider verification;
- moderation/report queue;
- support cases;
- payment/readiness visibility;
- unpaid/paid/review billing states;
- financial/reconciliation exception views where implemented;
- account privacy/deletion/security journeys;
- actionable error and audit context without secrets.

## Phase 6 — End-to-end acceptance

Minimum acceptance personas:

- public visitor;
- buyer;
- seller;
- bidder;
- Dispatch shipper;
- Dispatch carrier/provider;
- reporter/support user;
- administrator.

For each required persona, test the primary happy path plus at least one important denied/failure/retry path.

Required targets for this sprint:

- desktop/web;
- phone-sized Flutter/web layout;
- Android compile/runtime evidence where local tooling permits;
- iOS compile evidence through CI when GitHub hosted runners are available.

## Phase 7 — Controlled staging and release

After code completion:

1. exact commit passes the complete repository gate;
2. staging deployment uses the approved staging Firebase project only;
3. core journeys are accepted against staging;
4. provider/payment staging evidence is reconciled where available;
5. rollback procedure and release manifest are retained;
6. unresolved external gates are explicitly listed;
7. human approves production deployment of the exact accepted SHA.

## Autonomous task selection during the sprint

Workers should select tasks in this order unless a higher-priority blocker is exposed:

1. broken quality/security/release truth;
2. broken core user journey;
3. Dispatch subscription/core Dispatch gap;
4. Marketplace offer/transaction/messaging gap;
5. Wanted Ads gap;
6. Auction gap;
7. external-settlement fee code/test gap;
8. admin/trust/operations gap;
9. targeted refactor that directly enables one of the above;
10. optional analytics/catalog/polish only after operational gates are satisfied.

A worker must skip external-only items and continue to the next independent code-capable task rather than stopping the entire sprint.

## Scope-control rules

- one bounded behavior goal per autonomous increment;
- ordinary source remains within the 600-line policy;
- no unrelated cleanup;
- no new framework/state-management/design system without explicit decision;
- no broad rewrite of working functionality;
- no mock production path;
- no weakening tests to save time;
- no live-provider/production mutation;
- verified commits are checkpoints and remain on the reusable writer branch until human review.

## Completion signal

The sprint can be called code-complete only when the master/domain trackers show no remaining **code-now** P0/P1 blockers for the operational scope, the full verification gate is green, and remaining open items are explicitly external/staging/production/legal/provider acceptance rather than unfinished implementation.
