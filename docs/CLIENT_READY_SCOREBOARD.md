# Pipe Buyer — Client-Ready Project Scoreboard

**Audit snapshot:** August 21, 2026  
**Overall project estimate:** ~81%  
**Core engineering foundation:** ~95%  
**Controlled colleague soft-launch readiness:** ~80%

> This is a dated project audit snapshot, not live telemetry. Percentages represent implemented behavior plus remaining verification, integration and release acceptance.

## Parallel-work rule

Stripe / Payments / Tax is being completed in a separate branch and PR. This scoreboard work must not change payment commands, Stripe configuration, webhooks, tax policy, payment readiness, seller payouts, Messaging behavior or Dispatch behavior.

## Client scoreboard

| Workstream | Completion | Status | Remaining focus |
|---|---:|---|---|
| Firebase / Backend / Security | 95% | Substantially complete | Branch reconciliation, dependable CI, exact release gate |
| Accounts / Profiles / Admin | 92% | Substantially complete | Physical MFA and multi-account acceptance |
| Marketplace / Listings | 92% | Substantially complete | Behavior-stack reconciliation and formal UI integration |
| Search / Filters / Discovery | 90% | Substantially complete | Radius search, backfill and volume acceptance |
| Wanted Ads / Smart Matching | 90% | Substantially complete | Match quality, saved criteria and acceptance |
| Offers / Transactions | 88% | In progress | Smart Offers, Deal Room integration, settlement acceptance |
| Messaging / Deal Room | 85% | In progress | Reconcile PR #82 and PR #84 before new Messaging work |
| Anti-Scam / Trust | 82% | In progress | Similar-image, account/device and suspicious-price risk |
| Trucking / Dispatch | 82% | In progress | Routing, lanes, fleet capacity, proof/signatures, acceptance |
| Stripe / Payments / Tax | 75% | Active separate workstream | Subscription lifecycle, tax, reconciliation, controlled acceptance |
| Formal Product UI | 70% | In progress | Wire formal components around reconciled behavior |
| Mobile / Store Release | 65% | In progress | Exact release builds, physical-device acceptance, stores |
| Analytics / Market Intelligence | 48% | Future / partial | Server definitions, quality tests, demand and price intelligence |
| Verified Catalog Intelligence | 46% | Future / partial | Verified specs, sources, confidence and approval history |
| International Expansion | 20% | Future | Tax, payments, currencies, localization and regional rules |

## What is substantially completed

- Firebase Authentication, Firestore, Storage and Cloud Functions foundation.
- Security rules, App Check architecture, emulator tooling and controlled deployment foundations.
- Personal/business profiles, account recovery, deletion/export and administrator authorization.
- Core Pipe Buyer Marketplace listing lifecycle and media.
- Search/filter/sort/pagination foundation.
- Wanted Ads matching foundation.
- Offers/transactions foundation.
- Moderation/reporting/evidence foundation.
- Dispatch request/provider/quote/award lifecycle foundation.
- Responsive/mobile presentation foundation.

## What is semi-completed

- Messaging / Deal Room — ~85%.
- Offers / transaction settlement — ~88%.
- Dispatch — ~82%.
- Anti-Scam / Trust — ~82% basic foundation.
- Payments / Tax — ~75%, being handled on a separate branch.
- Formal product UI integration — ~70%.
- Mobile/store release — ~65%.
- Analytics and verified catalog intelligence — partial foundations.

## Major work not yet complete

- Full international rollout.
- Advanced AI anti-scam/fraud intelligence.
- Fully verified industrial catalog intelligence.
- Mature Marketplace analytics / pricing / demand intelligence.
- Multi-provider international payment strategy.
- Advanced fleet capacity and automated Dispatch matching.

## Recommended client priority order

### 1. Release-candidate reconciliation — mandatory

- Reconcile the active behavior stack.
- Preserve current Marketplace, location, offer, Messaging and Dispatch behavior.
- Produce one exact release candidate SHA.
- Run the full release gate.
- Complete web/mobile rendered acceptance.

### 2. Messaging / Deal Room — after PR reconciliation

Messaging is a strong next customer-value area, but **do not start a competing implementation branch while PR #82 and PR #84 still own Messaging behavior and formal Deal Room presentation**.

Once those branches are reconciled:

- finish attachment behavior;
- wire formal Deal Room presentation;
- preserve offer privacy;
- preserve listing context;
- complete multi-user acceptance;
- complete mobile/desktop acceptance.

### 3. Mobile acceptance & colleague soft launch

- Buyer journey.
- Seller journey.
- Wanted buyer journey.
- Dispatcher journey.
- Carrier journey.
- Administrator journey.
- Reporting/fraud test journey.

### 4. Advanced Anti-Scam / Trust

- Similar-image/perceptual matching.
- Suspicious price signals.
- Cross-account/device relationship risk.
- Fraud review prioritization.

### 5. Analytics / Market Intelligence

- Seller conversion.
- Days-to-sale.
- Search demand.
- Regional demand.
- Price trends.
- Dispatch lane intelligence.

## Soft-launch definition of done

- [ ] One reconciled release candidate identified by exact commit SHA.
- [ ] Flutter/Firebase automated gates pass, or any CI infrastructure blocker is explicitly recorded.
- [ ] Buyer, seller, Messaging, Dispatch and administrator journeys pass controlled acceptance.
- [ ] Payment work remains governed by its separate readiness, tax and reconciliation gates.
- [ ] Every material repair records root cause, exact repair, verification and commit/PR.

## Branch ownership

**Scoreboard branch:** `feature/client-readiness-scoreboard`

This branch should remain additive/read-only and should not modify:

- Stripe/payment Functions;
- tax policy;
- payment readiness;
- Marketplace settlement;
- Messaging behavior;
- Dispatch behavior;
- Firebase security rules;
- active production configuration.

The initial implementation consists of a self-contained Flutter scoreboard component, this Markdown client snapshot and focused widget/contract tests. Integration into the Admin Portal can occur after the active behavior/UI stack is reconciled, minimizing merge conflicts.
