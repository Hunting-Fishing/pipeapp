# Pipe Buyer Autonomous-Development Readiness

Status: **PROJECT ADAPTER PREPARED — CENTRAL ENGINE GRADUATION NOT YET EXECUTED**

## Scope

This checklist is for Pipe Buyer as a target of the central 366 Autonomous Builder. Generic engine implementation and engine fault suites live in `Hunting-Fishing/366-AI-Software-Homebrew/autonomous-builder`.

Pipe Buyer is responsible for project truth, compatibility, verification, and domain-specific reviewer fault cases. The central engine is responsible for orchestration, containment, generic guard/recovery behavior, independent-review execution, and graduation evidence.

## A. Project knowledge

- [x] Product Vision exists.
- [x] Master Roadmap exists.
- [x] Active 48–72 hour ship plan exists.
- [x] Architecture and Design System exist.
- [x] Definition of Done, test strategy, and non-functional requirements exist.
- [x] Feature registry and compatibility contract exist.
- [x] Decision, risk, and technical-debt registers exist.
- [x] Data, security/privacy, dependency/provider, cost/billing, release, and incident policies exist.
- [x] Current source-controlled payment architecture is summarized without claiming live provider evidence.

## B. Target adapter

- [x] `.autobuild/project.json` uses central schema version 3.
- [x] Reusable writer branch is `agent/autobuild`.
- [x] Direct autonomous `main` editing is disabled.
- [x] Single-writer operation required.
- [x] `.autobuild/risk_policy.json` classifies Pipe-specific high-risk paths.
- [x] `.autobuild/feature_contract.json` protects critical Pipe Buyer anchors.
- [x] `.autobuild/reviewer_fault_cases.json` contains real Pipe-specific regression/security/billing seeds.
- [x] Pipe project-control paths are fingerprinted for graduation.
- [x] Production activation, live-provider mutation, merge to main, and critical-risk actions remain human-only.

## C. Source/refactoring controls

- [x] Ordinary hand-written source ceiling: 600 lines.
- [x] Refactor warning: 450 lines.
- [x] Engineering-document ceiling: 600 lines.
- [x] Increment budget: 12 files / 800 changed lines.
- [x] Legacy oversized source may shrink but may not grow when touched.
- [x] Broad refactor mixed with unrelated feature behavior is prohibited.
- [x] High-risk refactoring requires behavior/compatibility evidence.

## D. Pipe-specific functionality preservation

- [x] Feature Registry exists.
- [x] Machine feature anchors exist.
- [x] Route compatibility inventory exists.
- [x] Firebase Function export inventory exists across configured codebases/re-export chains.
- [x] Compatibility tests cover additive/removal/codebase-loss behavior.
- [x] PR CI is configured to compare route/Function surfaces against the PR base SHA once GitHub supplies a runner.
- [x] Function parity and release-manifest controls remain part of verification.
- [ ] High-value user-journey regression coverage reviewed before broad autonomous refactoring begins.

## E. Pipe-specific verification

`tool/verify.ps1` remains the complete target-project gate and includes:

- [x] Flutter SDK inspection.
- [x] Pipe release-tool syntax validation.
- [x] route/Function compatibility tests.
- [x] Dart analysis.
- [x] Flutter tests.
- [x] OAuth/release-manifest/Function-parity/acceptance controls.
- [x] both Firebase Function codebases lint/check/audit.
- [x] Firestore/Storage Rules emulator tests.
- [x] authenticated callable integration tests.
- [x] web release build and release-manifest generation.
- [ ] Complete gate executed successfully on the target Windows workstation after separation from the central engine.

## F. Project reviewer graduation cases

The central engine's generic reviewer harness will consume `.autobuild/reviewer_fault_cases.json` in disposable worktrees.

- [x] Listing deep-link loss case defined.
- [x] Administrator MFA bypass case defined.
- [x] Dispatch monthly billing amount corruption case defined.
- [ ] Real local Codex reviewer blocks listing regression.
- [ ] Real local Codex reviewer blocks MFA bypass.
- [ ] Real local Codex reviewer blocks billing corruption.

## G. Billing/provider boundaries

- [x] Payment tracker remains authoritative.
- [x] Source-controlled Dispatch subscription architecture and payment readiness boundaries documented.
- [x] Payment/provider paths auto-escalate risk.
- [x] Live Stripe/provider mutations remain prohibited to unattended workers.
- [x] Redirect success is not entitlement/payment authority by policy.
- [ ] Live provider readiness values, secret bindings, tax registrations, Dashboard objects, and controlled live acceptance verified before production activation.

These external items do not prevent isolated code-only autonomous development.

## H. Central-engine graduation against Pipe Buyer

Run graduation from the separate 366 AI Builder clone. It must prove:

- [ ] central engine self-test passes;
- [ ] generic source/risk guard fault suite passes;
- [ ] interrupted-run recovery fault suite passes;
- [ ] hard-timeout containment passes;
- [ ] no-output watchdog containment passes;
- [ ] exclusive writer-lock contention passes;
- [ ] complete Pipe Buyer `tool/verify.ps1` passes;
- [ ] configured Pipe compatibility fault command passes;
- [ ] all Pipe-specific reviewer fault cases are blocked;
- [ ] target worktree remains clean and HEAD unchanged;
- [ ] engine + project fingerprints and Codex version evidence are issued.

Graduation evidence is stored under ignored `.agent-run/` and expires according to `.autobuild/project.json`. Engine changes, project-control changes, or a Codex version change invalidate it.

## I. Calibration

After graduation:

- [ ] One bounded watched worker completes with a verified commit.
- [ ] Resulting diff independently inspected for functionality loss/unexpected files.
- [ ] Two-task supervised run completes.
- [ ] One-hour unattended run completes as expected.
- [ ] Longer multi-hour run completes without branch proliferation or false completion.

## J. GitHub Actions

- [x] Previous zero-step failures are classified as pre-runner/account/platform execution failures rather than known repository-test failures.
- [ ] GitHub account/platform restriction resolved.
- [ ] Quality and iOS jobs receive runners and pass real steps.

The local central-engine graduation can authorize isolated development while this infrastructure issue remains unresolved. It does not authorize merge/release without the required remote evidence.

## Approval boundary

Successful graduation approves only **bounded isolated development on the writer branch**. Human review/merge, production activation, live provider/money operations, legal/tax declarations, and critical-risk actions remain human-controlled.
