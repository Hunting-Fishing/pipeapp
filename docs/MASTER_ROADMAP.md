# Pipe Buyer Master Roadmap

Status: active roadmap index

## Purpose

This file gives autonomous and human developers one ordered view of the end-development plan without duplicating the detailed domain trackers. The linked source remains authoritative for task-level completion evidence.

## Priority model

- `P0` — release/revenue/security truth required before downstream activation;
- `P1` — core product completion and user experience;
- `P2` — product depth, analytics, scale, and operational maturity;
- `GATED` — implementation may be prepared but activation depends on human/provider/legal/production evidence.

## Active workstreams

| ID | Priority | Workstream | Source of truth | Current direction |
| --- | --- | --- | --- | --- |
| PB-RUN | P0 | Engineering controls and release integrity | `docs/ENGINEERING_CONTROL_BASELINE.md` + README | Keep quality, security, release, App Check, Rules, and evidence controls green. |
| PB-PAY | P0 | Billing, subscriptions, Stripe, tax boundaries, refunds, reconciliation | `docs/PAYMENTS_EXECUTION_TRACKER.md` | Finish P0/P1 truth, then Dispatch subscription acceptance, external-settlement fee flow, tax gates, refunds/reconciliation; full Connect remains gated. |
| PB-UX | P1 | Phase 1.1 product experience | `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md` | Complete adaptive shell, discovery, listing detail/create, centers, messaging/transactions/Dispatch, admin and final acceptance without weakening backend controls. |
| PB-MKT | P1 | Marketplace production data/search/offers/transactions | `docs/PHASE_2_PROGRESS_AUDIT.md` | Finish staging/acceptance gaps and complete real buyer/seller journeys. |
| PB-WNT | P1 | Wanted Ads matching/lifecycle | `docs/PHASE_2_PROGRESS_AUDIT.md` | Complete structured saved criteria, protected staging evidence, representative match quality, and device/web acceptance. |
| PB-AUC | P1 | Auctions | `docs/PHASE_2_PROGRESS_AUDIT.md` | Complete fee/invoice policy, staging acceptance, dispute/default operations, then controlled activation. |
| PB-DSP | P1 | Dispatch | `docs/PHASE_2_PROGRESS_AUDIT.md` + Dispatch runbooks | Complete privacy migration evidence, route-provider canary, saved routes, fleet matching, proof, invoicing boundary, and acceptance. |
| PB-CAT | P2 | Weight/catalog confidence | `docs/PHASE_2_PROGRESS_AUDIT.md` | Add source attribution, confidence, coverage, approval history, and verified calculations. |
| PB-ANA | P2 | Analytics definitions and aggregation | `docs/PHASE_2_PROGRESS_AUDIT.md` | Version metrics, server-own aggregation, define currency/timezone/data-quality behavior, explain metrics to users. |
| PB-E2E | P1 | End-to-end acceptance | Phase 1.1 + Phase 2 | Complete buyer, seller, bidder, dispatcher, reporter, and administrator journeys on required web/mobile targets. |

## Autonomous selection policy

The worker should not simply process this table top-to-bottom. For each iteration:

1. preserve P0 safety/release truth;
2. identify the highest-priority unfinished item whose implementation and verification are safe in the current workspace;
3. skip but record provider/legal/production/credential/device-only blockers;
4. prefer finishing an already-active coherent workstream before starting unrelated lower-priority work;
5. choose one bounded increment and update the detailed source tracker only when its wording is actually satisfied.

## Completion layers

A workstream progresses through distinct evidence layers:

1. design/contract;
2. source implementation;
3. focused tests;
4. repository quality gate;
5. protected staging/emulator acceptance when applicable;
6. provider/external evidence when applicable;
7. physical-device/user-journey acceptance when applicable;
8. operational/reconciliation readiness when applicable;
9. controlled production activation.

An autonomous worker may complete only the layers it can actually evidence. Later layers must remain open rather than being inferred from earlier ones.

## Product-wide technical debt lane

Refactoring is permitted when it directly reduces risk or enables roadmap work. Priorities:

- source files approaching or exceeding the configured size budget;
- duplicated UI/state/service implementations;
- ambiguous ownership between client and server;
- missing characterization/regression tests around high-risk workflows;
- duplicated design primitives that diverge from `docs/DESIGN_SYSTEM.md`;
- stale or contradictory project documentation;
- brittle release/verification tooling.

Technical debt work must preserve behavior and must not become an excuse for an unbounded rewrite.

## Gated activation list

The following remain explicitly outside unattended activation:

- merge to `main`;
- Firebase/Hosting/Functions production deployment;
- public paid-feature activation;
- live Stripe object mutation or live money movement;
- full Marketplace Connect activation;
- tax/legal/accounting declarations;
- regulated property workflows;
- physical store/device publication acceptance;
- provider contract or credential decisions.
