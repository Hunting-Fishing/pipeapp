# Pipe Buyer Autonomous Quality Gates

Status: active engineering contract

## Intent

Autonomous development is allowed to move quickly only when each increment is small, reviewable, behavior-preserving unless intentionally changed, and verified against the real repository.

## Source-size policy

For ordinary hand-written source files:

- under 350 lines: healthy;
- 350–450 lines: acceptable;
- 450–550 lines: refactoring candidate;
- 550–600 lines: do not add substantial new responsibility;
- over 600 lines: oversized; do not increase it and prefer a behavior-preserving extraction before adding features.

The 600-line threshold is a ceiling, not a target.

Generated files, lockfiles, large fixtures, derived schemas, and other configured generated artifacts are exempt.

### Legacy oversized files

An existing file above the ceiling does not make the whole repository permanently red. The autonomous guard compares the working copy to `HEAD`:

- a new ordinary source file above the ceiling fails;
- an existing oversized source file that grows fails;
- an existing oversized source file that shrinks may proceed while remaining a technical-debt item.

## Refactoring policy

Refactors must preserve behavior unless a tracked task explicitly changes behavior.

Required sequence for high-risk extraction:

1. inspect current behavior and callers;
2. identify routes, callbacks, server commands, persistence, security, and tests at risk;
3. add/confirm characterization tests where coverage is weak;
4. extract one coherent responsibility;
5. preserve external interfaces where practical;
6. run focused tests;
7. run autonomous guard;
8. run the complete project verification command;
9. commit only after both pass.

Do not combine a broad refactor and unrelated feature behavior in one autonomous increment.

## Change-budget policy

Default autonomous increment budget is configured in `.autobuild/project.json`.

Current Pipe Buyer defaults:

- no more than 12 changed files;
- no more than 800 total added + deleted lines;
- one primary feature/domain concern;
- no production activation;
- no unrelated cleanup bundled into the increment.

These are safety budgets. If a legitimate mechanical extraction exceeds one, split it into sequential verified commits rather than silently broadening the task.

## Feature-preservation policy

`docs/FEATURE_REGISTRY.md` is a compatibility index.

Before changing a registered capability, identify the relevant:

- UI entry points;
- routes/navigation;
- server commands/Functions;
- persisted collections/documents;
- security/role requirements;
- lifecycle states;
- tests;
- external/provider gates.

Absence of a feature from the registry does not authorize deletion. Existing working behavior remains part of the compatibility surface unless an explicit deprecation decision exists.

## Design-quality policy

For UI work, read `docs/DESIGN_SYSTEM.md` before editing.

Autonomous UI work must:

- reuse existing theme tokens and shared components;
- avoid local one-off palettes and competing component patterns;
- preserve loading/empty/error/offline/denied/retry behavior;
- consider phone, tablet, and desktop/web layouts;
- preserve accessibility semantics and text scaling;
- separate visual refactors from unrelated behavior changes.

## Testing policy

Every behavior-changing increment requires focused verification appropriate to the change. The outer runner then executes the project-wide verification command from `.autobuild/project.json`.

Tests must not be deleted, skipped, muted, or materially weakened merely to obtain a green result.

When a failing test reveals an unrelated pre-existing defect, record the blocker rather than performing an unbounded repair unrelated to the current increment.

## Information-preservation policy

Do not silently erase project intent.

- durable decisions are appended to `docs/DECISION_REGISTER.md`;
- replaced decisions are marked superseded rather than deleted;
- domain trackers remain the task-level evidence source;
- `docs/MASTER_ROADMAP.md` indexes them without copying all details;
- feature completion claims require the evidence named by the source tracker.

## Timeout and recovery policy

A multi-hour autonomous session consists of bounded worker invocations.

Current project defaults:

- worker: 35 minutes;
- repair: 25 minutes;
- full verification: 45 minutes.

A timed-out increment must not create a verified commit. Prior verified commits remain intact. The runner records state/logs so the next run can diagnose or resume without replaying completed work.

## Git policy

Use the configured reusable writer branch (`agent/autobuild`) instead of creating a new timestamp branch for every run.

- commits are checkpoints;
- push only verified commits when remote backup is enabled;
- no autonomous merge to `main`;
- no force-push or history rewrite;
- recovery branches are exceptional, not routine.

## Final autonomous commit gate

A commit is eligible only when:

1. one bounded task is represented;
2. working-tree scope passes autonomous guard budgets;
3. ordinary source-size rules pass;
4. focused tests pass;
5. the complete repository verification command passes;
6. no human/provider/production evidence has been fabricated;
7. the result record accurately names what changed and what remains open.
