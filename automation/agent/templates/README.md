# Onboarding Another Repository

The Autonomous Builder engine should be shared; product truth remains in each target repository.

A repository is **not ready for unattended autonomous development** merely because `.autobuild/project.json` exists. Bootstrap its engineering knowledge and verify its current baseline first.

## Required target-repository setup

1. Create `.autobuild/project.json` from `project.json.example`.
2. Create `.autobuild/risk_policy.json` from `risk_policy.json.example` and tailor path/risk patterns to the stack.
3. Add a concise root `AGENTS.md` with project-specific safety/engineering rules.
4. Add `docs/PROJECT_KNOWLEDGE_INDEX.md` defining authority and retrieval order.
5. Add `docs/PRODUCT_VISION.md` describing the intended finished product.
6. Add `docs/MASTER_ROADMAP.md` indexing detailed trackers rather than duplicating them.
7. Add `docs/ARCHITECTURE.md` describing client/server/data/module boundaries.
8. Add `docs/QUALITY_GATES.md` defining source/document size, change budgets, testing, review, and refactor rules.
9. Add `docs/DEFINITION_OF_DONE.md`.
10. Add `docs/NON_FUNCTIONAL_REQUIREMENTS.md`.
11. Add `docs/FEATURE_REGISTRY.md` and `docs/CONTRACTS_AND_COMPATIBILITY.md`.
12. Add `docs/DECISION_REGISTER.md` and `docs/RISK_REGISTER.md`.
13. Add `docs/TEST_STRATEGY.md`.
14. Add `docs/DATA_CHANGE_POLICY.md` when the product persists mutable business/user data.
15. Add `docs/SECURITY_AND_PRIVACY_ENGINEERING.md` for any authenticated or user-data product.
16. Add `docs/DEPENDENCY_AND_PROVIDER_POLICY.md` and `docs/COST_AND_BILLING_GOVERNANCE.md`.
17. Add `docs/RELEASE_GOVERNANCE.md` and `docs/OBSERVABILITY_AND_INCIDENTS.md`.
18. Add `docs/TECH_DEBT_REGISTER.md`.
19. Add `docs/DESIGN_SYSTEM.md` for projects with significant UI.
20. Ensure `verify_command` runs the project's real analyzer/tests/build/security/contract gates.
21. Add `.autobuild/feature_contract.json` with a deliberately small set of critical machine-readable anchors.
22. Establish a clean green baseline before allowing the agent to change product code.

## Bootstrap inventory before first autonomous task

Document the current project before asking an agent to improve it:

- supported platforms and toolchain versions;
- source/module architecture;
- routes/navigation;
- authentication/authorization model;
- major data stores/schemas;
- server/background commands;
- providers/webhooks/APIs;
- billing/payment behavior;
- feature flags and safe defaults;
- environment separation;
- deployment and rollback path;
- active features and known incomplete features;
- design language;
- test layers and known coverage gaps;
- current technical debt and oversized files;
- known incidents/risks;
- cost-sensitive operations.

Do not infer these from screenshots or a single README when the repository contains stronger evidence.

## Required safety baseline

Before unattended mode, confirm:

- direct `main` writes disabled;
- reusable isolated writer branch configured;
- single-writer lock enabled;
- independent reviewer enabled;
- critical-risk changes human-only;
- production activation human-only;
- live provider mutations human-only;
- merge to main human-only;
- source/document/change budgets configured;
- secret/forbidden-path patterns configured;
- full verification command works from a clean clone/worktree.

## Engine invocation

From the reusable builder repository:

```powershell
.\tool\autonomous_build.ps1 -ProjectPath "D:\Path\To\TargetRepo" -Hours 3 -MaxTasks 8 -Push
```

The target repository should not need its own copy of the full supervisor once the engine is extracted. It only needs its adapter, knowledge, compatibility/risk contracts, and project-specific verification tooling.

## Choosing a source-size budget

600 lines is the recommended default ceiling for ordinary hand-written source, not a universal law. Generated files and lockfiles should be excluded. Existing oversized source should shrink incrementally and must not grow.

Use a similar ceiling for new engineering knowledge documents. Prefer indexes plus domain files over multi-thousand-line master documents.

## Choosing change budgets

Start conservatively:

- 8–12 files touched;
- 500–800 total changed lines;
- one primary domain concern;
- one behavior-changing goal per increment.

Increase only after repeated calibration proves the project's tests and review process can safely absorb larger changes.

## Knowledge design

Do not create one enormous project prompt. Keep core knowledge short/stable, with domain-specific trackers loaded only when relevant. The repository, tests, decisions, and structured run state allow a new worker to reconstruct context after timeout/restart without depending on hidden conversation state.

## Graduation criteria

A new project should not graduate from calibration to multi-hour unattended mode until:

1. static builder self-test passes;
2. guard fault-injection tests pass;
3. full project verification is green before autonomous edits;
4. reviewer can demonstrably block a seeded bad change;
5. single-writer lock rejects a second supervisor;
6. timeout/stall behavior has been exercised;
7. one short supervised autonomous run produces only expected bounded commits;
8. recovery from an interrupted run is understood;
9. branch/PR review shows no functionality loss;
10. human owner approves unattended use for that repository.
