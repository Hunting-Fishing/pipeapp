# Pipe Buyer Project Knowledge Index

Status: active engineering index

## Purpose

This file tells autonomous and human engineers where Pipe Buyer product truth lives. It is an index, not a duplicate roadmap. When two sources disagree, do not silently choose; apply the authority order below and record unresolved conflicts.

The reusable Autonomous Builder engine lives outside this repository in `Hunting-Fishing/366-AI-Software-Homebrew/autonomous-builder`. This repository owns the Pipe Buyer adapter, knowledge, compatibility contracts, and project verification.

## Authority order

1. Explicit current operator decision recorded in `docs/DECISION_REGISTER.md`.
2. Safety, legal, financial, security, data-integrity, and production controls.
3. Domain-specific active tracker or runbook.
4. `docs/PRODUCT_VISION.md`, `docs/MASTER_ROADMAP.md`, and the active accelerated ship plan.
5. `docs/ARCHITECTURE.md`, `docs/DESIGN_SYSTEM.md`, and `docs/QUALITY_GATES.md`.
6. `docs/FEATURE_REGISTRY.md` and compatibility contracts.
7. Implementation and tests as evidence of current behavior, not automatic proof of intended behavior.

A newer implementation does not override a documented safety or product decision merely because it exists.

## Always-read engineering knowledge

- `docs/PRODUCT_VISION.md` — intended finished product.
- `docs/MASTER_ROADMAP.md` — ordered workstream index.
- `docs/SHIP_72_HOUR_PLAN.md` — current acceleration priority and operational sprint scope.
- `docs/ARCHITECTURE.md` — system boundaries and refactor contract.
- `docs/QUALITY_GATES.md` — autonomous change limits and verification rules.
- `docs/DEFINITION_OF_DONE.md` — what must be true before work is called complete.
- `docs/NON_FUNCTIONAL_REQUIREMENTS.md` — reliability, accessibility, performance, security, privacy, operability, and cost expectations.
- `docs/DECISION_REGISTER.md` — durable operator and architecture decisions.
- `docs/RISK_REGISTER.md` — known engineering/product risks and mitigations.

## Compatibility and information preservation

- `docs/FEATURE_REGISTRY.md` — durable capability inventory.
- `docs/CONTRACTS_AND_COMPATIBILITY.md` — routes, commands, data, lifecycle, and backward-compatibility rules.
- `.autobuild/feature_contract.json` — machine-readable critical anchors.
- `.autobuild/reviewer_fault_cases.json` — Pipe-specific seeded reviewer graduation cases.
- `tool/autonomous_compatibility.mjs` — compares route/Function compatibility surfaces and rejects accidental removals.
- Tests, Rules tests, Function parity controls, and release manifests — executable compatibility evidence.

## Quality and testing

- `docs/TEST_STRATEGY.md` — testing layers and regression policy.
- `docs/TECH_DEBT_REGISTER.md` — known debt that should be reduced without turning unrelated work into rewrites.
- `tool/verify.ps1` — complete Pipe Buyer verification gate consumed by the central engine.

Generic worker containment, crash recovery, risk guarding, independent reviewer orchestration, and engine fault tests are owned by the central 366 Autonomous Builder, not by Pipe Buyer.

## UI and product experience

- `docs/DESIGN_SYSTEM.md` — canonical visual and interaction rules.
- `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md` — active UX delivery plan.
- `docs/MOBILE_RELEASE_AND_ACCESSIBILITY.md` — mobile and accessibility acceptance details.

## Payments, billing, tax, and provider money flows

- `docs/PAYMENTS_EXECUTION_TRACKER.md` — payment implementation/evidence queue and authoritative completion state.
- `docs/PAYMENTS_CURRENT_CONFIGURATION.md` — current source-controlled Stripe/checkout/webhook architecture; does not claim live provider evidence.
- `docs/PHASE_1_BILLING_BOUNDARY.md` — cloud billing versus product payment boundary.
- `docs/COST_AND_BILLING_GOVERNANCE.md` — spend controls and autonomous no-spend rules.
- `docs/MARKETPLACE_REFUND_DISPUTE_RUNBOOK.md` — refund/dispute operations.
- `docs/MARKETPLACE_TAX_INFORMATION_AND_EXEMPTION_TERMS.md` — tax information boundaries.

## Marketplace, Offers, Auctions, Wanted, Dispatch

- `docs/PHASE_2_PROGRESS_AUDIT.md` — current broad implementation status.
- `docs/DISPATCH_TRUCK_ROUTING.md` — routing/privacy contract.
- `docs/MARKETPLACE_SEARCH_INDEX.md` — search/index contract.

## Data, migrations, backup, and recovery

- `docs/DATA_CHANGE_POLICY.md` — schema/migration/backfill requirements.
- `firebase/FIRESTORE_SCHEMA.md` — current Firestore schema reference.
- `docs/FIREBASE_BACKUP_RESTORE_RUNBOOK.md` — backup and restore procedure.

## Security, privacy, and production operations

- `docs/ENGINEERING_CONTROL_BASELINE.md` — controlled baseline.
- `docs/SECURITY_AND_PRIVACY_ENGINEERING.md` — application security/privacy review rules.
- `docs/APP_CHECK_ROLLOUT.md` — App Check controls.
- `docs/FIREBASE_ENVIRONMENTS_AND_DEPLOYMENT.md` — environment separation/deployment.
- `docs/RELEASE_GOVERNANCE.md` — release/rollback approval model.
- `docs/OBSERVABILITY_AND_INCIDENTS.md` — diagnostics and incident ownership.

## Dependencies and third-party services

- `docs/DEPENDENCY_AND_PROVIDER_POLICY.md` — package/provider selection, lockfiles, cost, licensing, failure modes, and exit strategy.

## Autonomous Builder adapter

- `.autobuild/project.json` — Pipe Buyer adapter for central engine schema v3.
- `.autobuild/risk_policy.json` — Pipe-specific risk escalation and protected-governance rules.
- `.autobuild/feature_contract.json` — critical project anchors.
- `.autobuild/reviewer_fault_cases.json` — Pipe-specific reviewer fault cases.
- `AGENTS.md` — Pipe Buyer worker constitution.
- `docs/AUTONOMOUS_BUILD_AGENT.md` — how this project connects to the central 366 engine.
- `docs/AUTONOMOUS_BUILDER_READINESS.md` — Pipe-specific graduation/calibration checklist.

## Documentation rule

Do not create a new authoritative document when an existing source can be extended cleanly. New documents should have one clear responsibility and remain below the configured documentation size ceiling. Historical evidence belongs in domain runbooks or append-only registers rather than duplicated summaries.
