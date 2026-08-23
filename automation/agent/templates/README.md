# Onboarding Another Repository

The Autonomous Builder engine should be shared; project truth remains in each target repository.

Minimum target-repository setup:

1. create `.autobuild/project.json` from `project.json.example`;
2. add a concise root `AGENTS.md` with project-specific safety/engineering rules;
3. add `docs/PRODUCT_VISION.md` describing the intended finished product;
4. add `docs/MASTER_ROADMAP.md` indexing detailed trackers rather than duplicating them;
5. add `docs/ARCHITECTURE.md` describing major client/server/data/module boundaries;
6. add `docs/QUALITY_GATES.md` defining refactoring, test, source-size, and change-budget rules;
7. add `docs/FEATURE_REGISTRY.md` for durable capability inventory;
8. add `docs/DECISION_REGISTER.md` for active/superseded decisions;
9. add `docs/DESIGN_SYSTEM.md` for projects with significant UI;
10. ensure `verify_command` runs the project's real analyzer/tests/build/security gates;
11. optionally add `.autobuild/feature_contract.json` with a small set of machine-readable critical anchors.

## Engine invocation

From the reusable builder repository:

```powershell
.\tool\autonomous_build.ps1 -ProjectPath "D:\Path\To\TargetRepo" -Hours 3 -MaxTasks 8 -Push
```

The target repository should not need its own copy of the full supervisor once the engine is extracted. It only needs its adapter, knowledge, and project-specific quality tooling.

## Choosing a source-size budget

600 lines is a useful default ceiling for ordinary hand-written source, not a universal law. A project may choose a different threshold if its language/framework strongly justifies it. Generated files and lockfiles should be excluded. Existing oversized files should be allowed to shrink incrementally but not grow.

## Choosing change budgets

Start conservatively. Typical defaults:

- 8–12 files touched;
- 500–800 total changed lines;
- one primary domain concern;
- one behavior-changing goal per increment.

Increase only after repeated calibration proves the project's tests and review process can safely absorb larger changes.

## Knowledge design

Do not create one enormous project prompt. Keep core knowledge short and stable, with domain-specific trackers loaded only when relevant. This lets a new worker invocation reconstruct accurate context after timeout/restart without depending on hidden conversation state.
