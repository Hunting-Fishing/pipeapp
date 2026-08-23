# Autonomous Builder Readiness / Graduation Audit

Status: NOT YET GRADUATED FOR UNATTENDED PRODUCTION DEVELOPMENT

## Important standard

No software-development agent can be guaranteed to make zero mistakes. The release standard for this system is therefore **fail-closed, independently reviewed, test-backed, recoverable development with human-controlled merge and production activation**.

Do not run multi-hour unattended development merely because the architecture looks correct. Graduate only after the evidence gates below pass.

## A. Architecture and knowledge gates

- [x] Central-engine + per-project adapter architecture defined.
- [x] Project knowledge hierarchy/index exists.
- [x] Product vision exists.
- [x] Master roadmap exists.
- [x] Architecture contract exists.
- [x] Design-system contract exists.
- [x] Feature registry exists.
- [x] Contracts/compatibility policy exists.
- [x] Decision register exists.
- [x] Risk register exists.
- [x] Definition of Done exists.
- [x] Test strategy exists.
- [x] Non-functional requirements exist.
- [x] Data-change policy exists.
- [x] Security/privacy engineering policy exists.
- [x] Dependency/provider policy exists.
- [x] Cost/billing governance exists.
- [x] Release governance exists.
- [x] Observability/incident policy exists.
- [x] Technical-debt register exists.

## B. Scope and code-structure gates

- [x] Ordinary source ceiling configured at 600 lines.
- [x] Refactor warning configured at 450 lines.
- [x] New knowledge-document ceiling configured at 600 lines.
- [x] Legacy oversized source may shrink but may not grow.
- [x] Change budget configured (12 files / 800 changed lines for Pipe Buyer).
- [x] Broad refactor + unrelated feature work prohibited.
- [x] Characterization-first high-risk refactor rule documented.

## C. Git/worktree safety gates

- [x] Direct `main` autonomous editing disabled.
- [x] Reusable writer branch configured (`agent/autobuild`).
- [x] Timestamp branch proliferation removed from normal V2 flow.
- [x] Force-push/history rewrite prohibited.
- [x] Autonomous merge to main prohibited.
- [x] Clean worktree required before start.
- [x] Exclusive single-writer worktree lock implemented.
- [x] Static self-test verifies exclusive lock semantics.
- [ ] Two real supervisor processes tested simultaneously; second confirmed to fail immediately without changing worktree.

## D. Worker containment gates

- [x] Worker timeout configured.
- [x] No-output/stall watchdog configured.
- [x] Repair attempts bounded.
- [x] Full verification timeout configured.
- [x] Persistent run state/logs implemented.
- [x] Worker cannot branch/commit/push/merge/deploy.
- [ ] Real Codex timeout injection tested and previous verified commit confirmed intact.
- [ ] Real no-output/stall injection tested and process tree confirmed terminated.
- [ ] Interrupted supervisor/restart recovery rehearsed.

## E. Risk/secret/integrity guard gates

- [x] Machine-readable path-risk policy added.
- [x] Risk under-classification blocks commit.
- [x] Critical-risk autonomous commit prohibited.
- [x] Forbidden credential paths checked.
- [x] Secret-like content checked.
- [x] Merge-conflict markers checked.
- [x] `git diff --check` required.
- [x] Feature anchors checked.
- [x] Change-type declarations required for dependency/data/security/billing/provider paths.
- [x] Guard fault-injection test suite added.
- [ ] Fault-injection suite executed successfully on target Windows workstation.

## F. Independent review gates

- [x] Separate review prompt exists.
- [x] Separate review output schema exists.
- [x] Reviewer runs read-only.
- [x] Reviewer runs after machine guard and before full verification.
- [x] Error/critical review verdict blocks commit.
- [x] Reviewer raising risk above worker declaration blocks commit.
- [x] Review output retained in `.agent-run`.
- [ ] Seeded functionality-loss defect verified to be blocked by real reviewer.
- [ ] Seeded auth/security defect verified to be blocked by real reviewer.
- [ ] Seeded billing/data-contract defect verified to be blocked by real reviewer.

## G. Verification gates

- [x] Builder PowerShell syntax is part of normal project verification.
- [x] Builder static governance self-test is part of normal project verification.
- [x] Guard fault-injection tests are part of normal project verification.
- [x] Existing Flutter analyzer/tests remain required.
- [x] Functions lint/check/audit remain required.
- [x] Rules/emulator tests remain required when not explicitly skipped.
- [x] Web release build remains required when not explicitly skipped.
- [x] Existing release/function parity tests remain required.
- [ ] Full `tool/verify.ps1` passes locally from the current V2 branch.
- [ ] GitHub Quality workflow restored/classified and required remote checks pass.

## H. Functionality-preservation gates

- [x] Feature registry exists.
- [x] Compatibility contract exists.
- [x] Machine feature anchors exist.
- [x] Existing Function parity/release controls preserved.
- [x] Refactor completion requires characterization/compatibility evidence.
- [ ] Compatibility inventory audited against all currently active Pipe Buyer routes/Functions/roles/major workflows.
- [ ] High-value user journeys have sufficient regression coverage before broad autonomous refactoring is enabled.

## I. Billing/payment protection gates

- [x] Payment tracker remains authoritative.
- [x] Product payment completion requires provider/webhook/ledger/reconciliation agreement.
- [x] Live money/provider mutations prohibited autonomously.
- [x] Cloud/provider spend governance documented.
- [x] Billing/payment path changes auto-escalate risk.
- [x] High-risk results require focused verification and rollback notes.
- [ ] Current payment configuration/workflow inventory independently reconciled before autonomous payment refactors are enabled beyond code-only preparation.

## J. Data/security/release protection gates

- [x] Data-change policy requires dry-run/canary/checkpoint/rollback.
- [x] Destructive production data action prohibited.
- [x] Security/privacy contract added.
- [x] Auth/Rules/App Check/admin changes auto-escalate risk.
- [x] Release governance keeps exact-SHA staging/production separate.
- [x] Production activation human-only.
- [ ] Backup/restore rehearsal evidence completed for affected production data classes.
- [ ] Remote branch/environment protections required for production release are verified.

## K. Calibration gates

- [ ] Static builder self-test executed locally and green.
- [ ] Guard fault-injection tests executed locally and green.
- [ ] Full Pipe Buyer verification green before agent edits.
- [ ] One bounded worker run completed while watched.
- [ ] Diff independently inspected; no lost functionality or unexpected files.
- [ ] Reviewer blocking test completed.
- [ ] Two-task supervised run completed.
- [ ] One-hour unattended calibration completed with expected stop/recovery behavior.
- [ ] Three-hour unattended calibration completed without branch proliferation, runaway scope, or false completion.

## L. Multi-project portability gates

- [x] Engine accepts `-ProjectPath`.
- [x] Portable project schema/template exists.
- [x] Portable risk-policy template exists.
- [x] Target-project knowledge remains outside engine logic.
- [ ] Reusable engine extracted to dedicated repository after Pipe Buyer calibration.
- [ ] Second project onboarded using templates without copying Pipe Buyer-specific rules into engine.
- [ ] Same safety/timeout/reviewer/guard tests pass against second project.

## Graduation decision

The builder is **not** approved for unattended multi-hour development until all required calibration gates above are evidenced. Even after graduation:

- autonomous commits remain isolated on the writer branch;
- independent review + full verification remain mandatory;
- human review/merge remains mandatory;
- production activation remains human-controlled;
- critical-risk actions remain prohibited.

## Re-open graduation

Return the builder to calibration mode after:

- a missed material regression;
- accidental functionality loss;
- secret/data exposure;
- unsafe billing/provider behavior;
- repeated reviewer misses;
- runner corruption/race;
- significant engine architecture change;
- major tool/model change that alters behavior;
- onboarding a project with materially different risk/toolchain characteristics.
