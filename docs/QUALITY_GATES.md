# Pipe Buyer Autonomous Quality Gates

Status: active engineering contract

## Intent

Autonomous development is allowed to move quickly only when each increment is bounded, reviewable, behavior-preserving unless intentionally changed, correctly risk-classified, and verified against the real repository.

## Source-size policy

For ordinary hand-written source files:

- under 350 lines: healthy;
- 350–450 lines: acceptable;
- 450–550 lines: refactoring candidate;
- 550–600 lines: do not add substantial new responsibility;
- over 600 lines: oversized; do not increase it and prefer behavior-preserving extraction before adding features.

The 600-line threshold is a ceiling, not a target.

Generated files, lockfiles, large fixtures, derived schemas, and configured generated artifacts are exempt.

### Legacy oversized source

- new ordinary source over the ceiling fails;
- existing oversized source that grows or fails to shrink when modified fails;
- existing oversized source that shrinks may proceed while remaining technical debt.

## Documentation-size policy

New tracked knowledge/planning Markdown files must remain at or below the configured documentation ceiling (600 lines for Pipe Buyer).

Legacy oversized documentation may be updated only without increasing its line count; split it in a dedicated documentation refactor instead of continuously growing one giant tracker.

The master roadmap and knowledge index should link domain detail rather than copy it.

## Refactoring policy

Refactors must preserve behavior unless a tracked task explicitly changes behavior.

Required sequence for high-risk extraction:

1. inspect current behavior and callers;
2. identify routes, callbacks, commands, persistence, security, and tests at risk;
3. add/confirm characterization tests where coverage is weak;
4. extract one coherent responsibility;
5. preserve external interfaces where practical;
6. run focused tests;
7. run autonomous guard;
8. pass independent read-only review;
9. run complete project verification;
10. commit only after all gates pass.

Do not combine a broad refactor and unrelated feature behavior in one autonomous increment.

## Change-budget policy

Current Pipe Buyer defaults:

- no more than 12 changed files;
- no more than 800 total added + deleted lines;
- one primary feature/domain concern;
- no production activation;
- no unrelated cleanup bundled into the increment.

These are safety budgets. Split legitimate larger work into sequential verified commits.

## Risk-classification gate

Every worker result declares `low`, `medium`, `high`, or `critical` risk plus reasons.

`.autobuild/risk_policy.json` independently escalates risk based on changed paths. The worker may classify higher than the path policy but never lower.

Typical `HIGH` areas include:

- Functions/server authority;
- Firestore/Storage Rules and schema/migrations;
- authentication/admin/App Check/private data;
- payments/billing/tax/reconciliation;
- dependencies/providers;
- CI/release/deployment;
- broad compatibility changes.

`CRITICAL` live/irreversible actions are human-only and cannot become autonomous commits merely because code/tests are present.

## Secret and repository-integrity gate

The autonomous guard rejects:

- configured forbidden credential/secret paths;
- secret-like key/token content patterns;
- unresolved merge-conflict markers;
- `git diff --check` failures;
- missing machine feature anchors;
- risk metadata inconsistent with changed paths.

Secret scanning is defense-in-depth, not permission to put credentials into files that happen not to match a pattern.

## Feature-preservation policy

`docs/FEATURE_REGISTRY.md` and `docs/CONTRACTS_AND_COMPATIBILITY.md` are compatibility references.

Before changing a capability, identify relevant UI entry points, routes, server commands/Functions, persisted records, security/roles, lifecycle states, tests, and provider gates.

Absence from the registry does not authorize deletion. Existing working behavior remains part of the compatibility surface unless an explicit deprecation decision exists.

## Design-quality policy

For UI work, read `docs/DESIGN_SYSTEM.md` before editing.

Autonomous UI work must reuse existing theme tokens/components; avoid one-off palettes/patterns; preserve loading/empty/error/offline/denied/retry states; consider phone/tablet/desktop; preserve accessibility semantics/text scaling; and separate visual refactors from unrelated behavior changes.

## Testing policy

`docs/TEST_STRATEGY.md` is authoritative for testing layers.

Every behavior-changing increment requires focused verification appropriate to the change. High-risk changes require negative-path coverage. The outer supervisor then executes the complete repository verification command.

Tests must not be deleted, skipped, muted, or materially weakened merely to obtain green output.

A repeated retry of a flaky/failing test without root-cause classification is not acceptance evidence.

## Independent review gate

After the machine guard and before full verification, a separate read-only reviewer inspects the uncommitted diff.

The reviewer did not author the change and specifically looks for:

- functionality loss/regression;
- security/privacy weakening;
- data-integrity/migration gaps;
- billing/financial/provider mismatch;
- compatibility breakage;
- design/accessibility drift;
- performance/cost amplification;
- missing high-risk tests;
- architecture duplication/drift;
- documentation claims unsupported by evidence;
- risk under-classification.

Any error/critical finding, likely functionality loss, material knowledge conflict, or reviewer-raised risk above the worker declaration blocks the commit until repaired/reviewed again.

## Change-type declaration gate

Worker results explicitly declare whether the increment changes:

- data/schema/migration behavior;
- dependencies;
- providers;
- security/privacy boundaries;
- billing/payment behavior.

Path-based guard rules verify these declarations for known high-risk areas. High-risk results also record rollback/recovery implications and at least one passed focused verification.

## Information-preservation policy

Do not silently erase project intent.

- durable decisions are appended/superseded in `docs/DECISION_REGISTER.md`;
- domain trackers remain task-level evidence;
- `docs/MASTER_ROADMAP.md` indexes rather than duplicates detail;
- `docs/PROJECT_KNOWLEDGE_INDEX.md` defines authority and retrieval;
- risk/debt registers retain known unresolved issues;
- feature completion claims require evidence named by the source tracker and Definition of Done.

## Timeout and recovery policy

A multi-hour autonomous session consists of bounded worker invocations.

Current defaults:

- worker: 35 minutes;
- no-output watchdog: 10 minutes;
- independent review: 20 minutes;
- repair: 25 minutes;
- full verification: 45 minutes.

A timed-out/stalled worker or reviewer cannot create a verified commit. Prior verified commits remain intact. State/logs remain under `.agent-run/`.

## Single-writer/Git policy

Use the configured reusable writer branch (`agent/autobuild`) rather than timestamp branches for normal work.

- one supervisor holds an exclusive worktree lock;
- commits are checkpoints;
- push only verified commits when remote backup is enabled;
- no autonomous merge to `main`;
- no force-push/history rewrite;
- recovery branches are exceptional.

## Final autonomous commit gate

A commit is eligible only when:

1. one bounded task is represented;
2. working-tree scope passes change budgets;
3. source/document-size rules pass;
4. no forbidden secret/path/integrity issue is detected;
5. risk/change metadata matches the diff;
6. compatibility checks are recorded;
7. focused tests pass;
8. independent read-only review passes;
9. complete repository verification passes;
10. no human/provider/production evidence is fabricated;
11. critical live/irreversible actions remain unperformed;
12. the structured result accurately states what changed, risks, rollback implications, and remaining gates.