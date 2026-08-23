# Autonomous Builder Readiness / Graduation Audit

Status: READY TO EXECUTE GRADUATION — NOT YET APPROVED FOR UNATTENDED MULTI-HOUR DEVELOPMENT

## Standard

No software-development agent can be guaranteed to make zero mistakes. Pipe Buyer therefore requires fail-closed, independently reviewed, test-backed, recoverable development with human-controlled merge and production activation.

The infrastructure required to test that standard is now implemented. `tool/autonomous_build.ps1` refuses to start a worker unless current control files have valid, recent graduation evidence from `tool/autonomous_graduation.ps1`.

## A. Architecture and project knowledge

- [x] Central-engine + per-project adapter architecture defined.
- [x] Product vision, master roadmap, 48–72 hour ship plan, architecture and design system exist.
- [x] Definition of Done, test strategy and non-functional requirements exist.
- [x] Feature registry and compatibility contract exist.
- [x] Decision/risk/technical-debt registers exist.
- [x] Data, security/privacy, dependency/provider, cost/billing, release and incident policies exist.
- [x] Current source-controlled payment architecture is reconciled in `PAYMENTS_CURRENT_CONFIGURATION.md` without claiming live provider evidence.

## B. Scope and code structure

- [x] Ordinary source ceiling: 600 lines.
- [x] Refactor warning: 450 lines.
- [x] Knowledge-document ceiling: 600 lines.
- [x] Legacy oversized source may not grow; refactoring is expected before adding substantial responsibility.
- [x] Increment budget: maximum 12 files / 800 changed lines for Pipe Buyer.
- [x] Broad refactor + unrelated feature behavior is prohibited.
- [x] Characterization-first high-risk refactoring is required.

## C. Git/worktree and crash safety

- [x] Direct autonomous `main` writes disabled.
- [x] Reusable writer branch configured as `agent/autobuild`.
- [x] Timestamp branch proliferation removed from normal flow.
- [x] Force-push/history rewrite and autonomous merge prohibited.
- [x] Clean worktree required.
- [x] Remote freshness/divergence checks implemented.
- [x] Exclusive single-writer lock implemented.
- [x] Interrupted autonomous work has stash-preserving recovery; ambiguous/operator-owned changes fail closed and are not touched.
- [x] Recovery refusal/success fault suite implemented.
- [ ] Real cross-process contention test executed on target Windows workstation.
- [ ] Interrupted supervisor recovery executed on target workstation and evidence inspected.

## D. Worker containment

- [x] Worker hard timeout configured.
- [x] No-output watchdog configured.
- [x] Repair attempts bounded.
- [x] Reviewer and full-verification timeouts configured.
- [x] Persistent run state/logs implemented.
- [x] Worker cannot branch/commit/push/merge/deploy.
- [x] Real-process timeout/stall/lock fault harness implemented in `autonomous_runtime_fault_test.ps1`.
- [ ] Runtime fault harness executed successfully on target workstation.

## E. Integrity / self-modification protection

- [x] Machine path-risk policy implemented.
- [x] Risk under-classification blocks commit.
- [x] Critical-risk autonomous commit prohibited.
- [x] Forbidden credential paths and secret-like content checked.
- [x] Merge-conflict markers and `git diff --check` enforced.
- [x] Project/agent governance, verification, graduation, sprint-plan and payment-reconciliation files protected from worker edits.
- [x] All `.github/workflows/` changes prohibited from ordinary autonomous workers.
- [x] Worker cannot edit the readiness checklist and self-approve graduation.
- [x] Guard fault-injection suite implemented.
- [ ] Guard fault suite executed successfully on target workstation.

## F. Functionality preservation

- [x] Feature registry and machine anchors exist.
- [x] Automatic compatibility checker inventories active `FFRoute` name/path signatures.
- [x] Automatic compatibility checker inventories Firebase Function exports across configured codebases and re-export chains.
- [x] Autonomous uncommitted increments are compared against `HEAD`; removal of an existing route or Function export fails.
- [x] Pull-request CI is configured to compare route/Function surfaces against the PR base SHA.
- [x] Compatibility checker has additive/removal/codebase-removal fault tests.
- [x] Existing Function parity and release-manifest controls retained.
- [ ] High-value user-journey regression coverage audited before broad autonomous refactoring.

## G. Independent review

- [x] Separate read-only reviewer prompt/schema implemented.
- [x] Reviewer runs after deterministic guard and before full project verification.
- [x] Error/critical finding or increased risk blocks commit.
- [x] Seeded reviewer graduation harness implemented for:
  - functionality/deep-link loss;
  - administrator MFA/security bypass;
  - Dispatch monthly billing-price corruption.
- [ ] All three seeded reviewer cases executed and blocked by the real local Codex reviewer.

## H. Verification

- [x] Builder PowerShell syntax is part of local and remote verification.
- [x] Builder static governance self-test is required.
- [x] Guard, stash-recovery and compatibility fault tests are required.
- [x] Flutter analyzer/tests required.
- [x] Both Firebase Function codebases lint/check/audit required.
- [x] Firestore/Storage emulator and callable integration tests required.
- [x] Web release build, Function parity and release-manifest tests required.
- [x] GitHub Quality workflow now includes autonomous governance and PR-base compatibility controls once a runner executes.
- [ ] Complete `tool/verify.ps1` passes on the target Windows workstation from the current control branch.
- [ ] GitHub Quality/iOS checks execute real steps and pass.

## I. GitHub Actions blocker

- [x] Zero-step Actions failures classified as pre-runner/account/platform execution failures rather than repository test-step failures. See `GITHUB_ACTIONS_DIAGNOSIS.md`.
- [ ] Exact GitHub account/platform restriction resolved.
- [ ] New Quality run receives a runner, emits step logs and passes.

Local graduation may authorize isolated autonomous development while this remote infrastructure issue is unresolved. It does not authorize merge to `main` or production release without required remote evidence.

## J. Billing/payment boundaries

- [x] Payment tracker remains authoritative for completion.
- [x] Source-controlled Dispatch CA$25 monthly / CA$300 yearly architecture, webhook authority, external-fee flow and readiness gates reconciled.
- [x] Live provider/money mutations prohibited.
- [x] Payment changes auto-escalate to HIGH risk and require focused tests, rollback notes, independent review and full verification.
- [x] Redirect success cannot be treated as entitlement authority by policy; provider/webhook evidence remains authoritative.
- [ ] Live Stripe readiness values, secret bindings, active Dashboard objects, tax registrations and live acceptance independently verified before activation.

These external items do not prevent code-only autonomous payment work.

## K. One-command infrastructure graduation

`tool/autonomous_graduation.ps1` is implemented and must pass all of the following before the normal autonomous entry point will run:

1. complete clean-baseline `tool/verify.ps1`;
2. deterministic guard/recovery/compatibility suites;
3. real hard-timeout containment;
4. real no-output watchdog containment;
5. real cross-process writer-lock contention;
6. seeded independent-reviewer functionality/security/billing defects;
7. clean worktree and unchanged HEAD after tests;
8. control fingerprint and Codex CLI version evidence.

Graduation evidence expires after 168 hours and is invalidated immediately if any fingerprinted control file or Codex CLI version changes.

- [ ] Infrastructure graduation command executed and evidence issued.
- [ ] One bounded worker run completed while watched.
- [ ] Its diff independently inspected; no unexpected functionality/file loss.
- [ ] Two-task supervised run completed.
- [ ] One-hour unattended calibration completed.
- [ ] Three-hour unattended calibration completed.

## L. Multi-project portability

- [x] Engine accepts `-ProjectPath` and target-specific knowledge remains in the target repo.
- [x] Portable project/risk/onboarding templates exist.
- [ ] Reusable engine extracted to dedicated repository after Pipe Buyer is stable.
- [ ] Second materially different project onboarded and safety tests repeated.

These portability tasks must not delay the 48–72 hour Pipe Buyer operational sprint.

## Approval boundary

After graduation, the system is approved only for **bounded isolated development**. Human review/merge, production activation, live provider money movement, legal/tax declarations and critical-risk actions remain human controlled.

Re-run graduation after any control fingerprint change, Codex CLI version change, material missed regression, unsafe billing/provider behavior, secret/data incident, repeated reviewer miss, runner corruption/race, or significant engine architecture change.
