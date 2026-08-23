# Pipe Buyer Project Knowledge Index

Status: active engineering index

## Purpose

This file tells autonomous and human engineers where product truth lives. It is an index, not a duplicate roadmap. When two sources disagree, do not silently choose; apply the authority order below and record unresolved conflicts.

## Authority order

1. Explicit current operator decision recorded in `docs/DECISION_REGISTER.md`.
2. Safety, legal, financial, security, data-integrity, and production controls.
3. Domain-specific active tracker or runbook.
4. `docs/PRODUCT_VISION.md` and `docs/MASTER_ROADMAP.md`.
5. `docs/ARCHITECTURE.md`, `docs/DESIGN_SYSTEM.md`, and `docs/QUALITY_GATES.md`.
6. `docs/FEATURE_REGISTRY.md` and compatibility contracts.
7. Implementation and tests as evidence of current behavior, not automatic proof of intended behavior.

A newer implementation does not override a documented safety or product decision merely because it exists.

## Always-read engineering knowledge

- `docs/PRODUCT_VISION.md` — intended finished product.
- `docs/MASTER_ROADMAP.md` — ordered workstream index.
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
- Tests, Rules tests, Function parity controls, and release manifests — executable compatibility evidence.

## Quality and testing

- `docs/TEST_STRATEGY.md` — testing layers and regression policy.
- `docs/TECH_DEBT_REGISTER.md` — known debt that should be reduced without turning unrelated work into rewrites.
- `tool/verify.ps1` — complete repository verification gate.

## UI and product experience

- `docs/DESIGN_SYSTEM.md` — canonical visual and interaction rules.
- `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md` — active UX delivery plan.
- `docs/MOBILE_RELEASE_AND_ACCESSIBILITY.md` — mobile and accessibility acceptance details.

## Payments, billing, tax, and provider money flows

- `docs/PAYMENTS_EXECUTION_TRACKER.md` — payment implementation/evidence queue.
- `docs/PHASE_1_BILLING_BOUNDARY.md` — cloud billing versus product payment boundary.
- `docs/COST_AND_BILLING_GOVERNANCE.md` — spend controls, provider cost ownership, and autonomous no-spend rules.
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

## Autonomous builder configuration

- `.autobuild/project.json` — project-specific builder configuration.
- `.autobuild/risk_policy.json` — machine-readable path/risk escalation rules.
- `AGENTS.md` — repository worker constitution.
- `docs/AUTONOMOUS_BUILD_AGENT.md` — supervisor operation and extraction plan.

## Documentation rule

Do not create a new authoritative document when an existing source can be extended cleanly. New documents should have one clear responsibility and should remain below the configured documentation size ceiling. Detailed historical evidence belongs in domain runbooks or append-only registers rather than duplicated summaries.