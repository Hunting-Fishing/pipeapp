# Pipe Buyer Product Vision

Status: active product contract

## Product outcome

Pipe Buyer is a professional industrial marketplace and operating platform for pipe, tubing, casing, equipment, materials, wanted demand, offers, auctions, messaging, and Dispatch services. The finished product must let a user discover supply or demand, evaluate counterparties, communicate, negotiate, coordinate logistics, and complete the applicable commercial workflow without relying on demo-only behavior or hidden manual state.

This document describes the destination. Domain trackers describe the current implementation work required to reach it.

## Core product domains

### Marketplace

- browse and search industrial listings with server-owned filters and deterministic pagination;
- support pipe, tubing, casing, equipment, assets, materials, and Wanted Ads;
- responsive map/list and density-aware discovery;
- detailed listing pages with structured specifications, media, seller identity, verification, ratings, User Score, saves, shares, report actions, offers, quotes, messaging, and freight/Dispatch entry points;
- guided create/edit listing workflows with category-specific validation, media ordering, logistics, privacy, offer/RFQ, and auction settings;
- buyer and seller centers with saved items, searches, offers, inventory, drafts, listing health, inquiries, and meaningful performance metrics.

### Offers and transactions

- revision-safe offers and counteroffers;
- immutable accepted-commercial snapshots;
- clear transaction lifecycle, confirmations, cancellation, disputes, and participant history;
- server-authoritative commercial calculations and fail-closed provider state.

### Auctions

- safe bidding, Buy It Now, reserve privacy, below-reserve handling, withdrawal rules, finalization, settlement state, and participant history;
- launch locks remain until fee, operational, provider, and acceptance evidence are complete.

### Wanted Ads

- server-owned lifecycle states;
- bounded, explainable matching between demand and supply;
- ranked participant-safe matches, dismissal/restoration, contact, immutable activity, saved criteria, and alerts.

### Dispatch

- job creation, provider/carrier discovery, quotes and revisions, award, route context, participant-private exact locations, progress, proof, and operational history;
- external route providers, billing, and settlement remain gated until specifically approved and accepted.

### Communication

- listing/transaction-aware messaging;
- notifications with safe error states and bounded delivery behavior;
- customer support and administrator operational queues.

### Trust and safety

- account and provider verification;
- ratings and User Score foundations;
- reporting, moderation, appeals, anti-scam signals, abuse controls, audit history, and role-safe administration;
- no client-side authority for privileged financial, moderation, or lifecycle actions.

### Billing and revenue

- Dispatch subscription billing;
- external-settlement Marketplace fee collection;
- optional full Marketplace money movement only after its separate legal, tax, provider, risk, operational, reconciliation, and acceptance gates are satisfied;
- every monetary state must reconcile provider evidence to server state and accounting evidence.

### Administration

- dense, safe operational views for account verification, providers, moderation, support, billing, payment exceptions, disputes, audits, lifecycle review, and analytics;
- all privileged actions must retain authorization, MFA/App Check where required, auditability, idempotency, and safe failure behavior.

## Experience outcome

Pipe Buyer should feel like a modern industrial marketplace rather than a generic Flutter template. The UI must be responsive across phone, tablet, desktop, and web, preserve the established industrial brand, remain understandable at 200% text, support keyboard/screen-reader use where applicable, and consistently represent loading, empty, offline, denied, failed, and recovery states.

`docs/DESIGN_SYSTEM.md` is authoritative for visual implementation details.

## Definition of product completion

A domain is not complete merely because a screen or code path exists. Completion requires, as applicable:

1. coherent user journey;
2. server-authoritative state and calculations;
3. real persistence and security rules;
4. error, retry, offline, denied, and empty-state behavior;
5. appropriate automated tests;
6. supported responsive and accessibility behavior;
7. provider or external evidence where the feature depends on a provider;
8. operational/admin handling;
9. reconciliation/audit evidence for financial or privileged workflows;
10. acceptance on the required web/mobile targets.

## Deliberate boundaries

The product vision does not authorize an autonomous agent to activate production, move live money, change tax/legal declarations, weaken security, merge to `main`, or claim external acceptance without evidence. Those gates remain human controlled.
