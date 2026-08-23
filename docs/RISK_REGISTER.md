# Pipe Buyer Engineering Risk Register

Status: active register

This register tracks risks that can invalidate otherwise successful-looking development. It is not a substitute for domain-specific runbooks.

## Risk scale

- `LOW` — localized, easily reversible, limited blast radius.
- `MEDIUM` — meaningful user/workflow regression possible; normal verified branch work.
- `HIGH` — security, financial, data, dependency, provider, release, or broad compatibility impact; requires explicit risk review and human review before merge.
- `CRITICAL` — production activation, live money movement, secrets, destructive production data change, legal/tax declaration, or other irreversible/high-consequence action; autonomous execution prohibited.

## Active risks

| ID | Risk | Level | Mitigation / required evidence | Status |
| --- | --- | --- | --- | --- |
| R-001 | Autonomous change removes existing functionality during refactor | HIGH | Feature registry, compatibility contract, characterization tests, machine anchors, independent diff review, full verification | ACTIVE |
| R-002 | Large files accumulate hidden responsibilities and become unsafe to modify | MEDIUM | 450-line warning, 600-line ceiling, oversized files may shrink but not grow | ACTIVE |
| R-003 | Long-running worker stalls and loses multi-hour progress | MEDIUM | Bounded workers, no-output watchdog, verified commit checkpoints, persistent run state | MITIGATED |
| R-004 | Multiple autonomous writers corrupt or race on one worktree/branch | HIGH | Single-writer lock, one reusable writer branch, clean-worktree preflight | ACTIVE until lock gate verified |
| R-005 | AI worker incorrectly declares task complete | HIGH | Definition of Done, evidence fields, independent reviewer, domain tracker authority, human external gates | ACTIVE |
| R-006 | Billing/payment implementation appears correct but provider/ledger/reconciliation disagree | CRITICAL | Payment execution tracker, server authority, webhook idempotency, reconciliation, controlled acceptance; no autonomous live money movement | ACTIVE |
| R-007 | Cloud/provider spending increases unexpectedly | HIGH | Cost/billing governance, bounded operations, no autonomous paid-service activation, budget ownership | ACTIVE |
| R-008 | Production/staging/local resources become mixed | CRITICAL | Explicit environment config, emulator-first local mode, exact project locks, deployment runbook | ACTIVE |
| R-009 | Data migration/backfill partially mutates records or cannot be rolled back | HIGH | Dry-run, canary, checkpoints, preconditions, environment lock, restore/rollback plan | ACTIVE |
| R-010 | Dependency/provider update introduces security, licensing, cost, or compatibility problem | HIGH | Dependency/provider policy, lockfile review, audit, provider exit/failure analysis | ACTIVE |
| R-011 | Secrets or private user data enter Git/logs/model context | CRITICAL | Secret scan, path restrictions, log redaction, privacy policy, no credential copying | ACTIVE |
| R-012 | Security controls are weakened to make tests or development easier | CRITICAL | AGENTS policy, Rules tests, App Check/auth boundaries, independent reviewer | ACTIVE |
| R-013 | UI redesign drifts from product identity or loses accessibility/responsiveness | MEDIUM | Design system, reference acceptance, accessibility tests, independent UI review | ACTIVE |
| R-014 | Old clients/history break after schema, lifecycle, route, or Function changes | HIGH | Contracts/compatibility policy, additive/versioned migration, parity tests | ACTIVE |
| R-015 | Generated AI code duplicates existing architecture/service paths | MEDIUM | Search-before-edit rule, architecture contract, reviewer duplicate-path check | ACTIVE |
| R-016 | GitHub CI is unavailable or misleading while local work proceeds | HIGH | Full local verify required; CI failure independently classified; no production merge/release without required remote gates | ACTIVE |
| R-017 | Documentation becomes contradictory or too large for reliable retrieval | MEDIUM | Knowledge index, authority order, decision register, <600-line documentation policy, domain-specific files | ACTIVE |
| R-018 | Autonomous system becomes specific to Pipe Buyer and cannot safely serve other projects | MEDIUM | Central engine + per-project adapter architecture, generic schemas, project-owned knowledge | ACTIVE |
| R-019 | Same coding model misses a defect in its own change | HIGH | Separate read-only reviewer pass with blocking findings before commit | ACTIVE until reviewer gate verified |
| R-020 | Test suite passes but important non-functional quality regresses | HIGH | Non-functional requirements, risk classification, targeted performance/accessibility/security review | ACTIVE |

## Risk-handling rule

A worker must not lower a risk rating merely to proceed. If a change crosses into a higher-risk category, the result must declare it and satisfy the corresponding review/verification requirements.

`CRITICAL` means the coding system may prepare code, tests, dry-run tooling, or documentation when safe, but it may not perform the live/irreversible action.

## Updating this register

Add a risk when a defect, near miss, provider limitation, production incident, repeated model failure, or new architecture introduces a failure mode not already represented. Close or downgrade only when the mitigation is actually implemented and verified.