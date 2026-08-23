# Pipe Buyer Autonomous Repository Builder

Status: development scaffold  
Scope: developer-side repository automation only  
Production activation: human controlled

## Purpose

This runner allows the Pipe Buyer repository to continue making bounded, verified code progress for a few hours without requiring an operator to approve every individual edit.

It is intentionally **not** the Firebase Cloud Function named `agent`. The existing Cloud Function is an application-side administrative resource with fail-closed runtime controls. Repository development runs separately on a developer machine through Codex CLI, a Git worktree/branch, the project `.md` trackers, and the real local test toolchain.

## Architecture

```text
Tracked .md roadmap/checklists
          |
          v
     Codex worker
          |
          v
Inspect source + implement one bounded increment
          |
          v
Targeted analyzer/tests inside Codex turn
          |
          v
Outer runner executes .\tool\verify.ps1
       /                  \
    pass                  fail
     |                     |
     v                     v
verified Git commit   bounded repair attempt
     |                     |
     +------ next task <---+

External / production / legal / provider-only gates
          |
          v
record blocker; never fabricate completion
```

The loop is deliberately commit-oriented. Each successful iteration must survive the repository's complete quality gate before the runner creates a local commit. Failed work is left uncommitted with logs and a patch for review.

## What the autonomous worker may do

Examples of work suitable for unattended execution:

- Flutter UI and responsive-layout improvements;
- code refactors with preserved behavior;
- unit/widget/Functions test additions and repairs;
- server/client contract parity fixes that do not activate production;
- error/loading/empty-state improvements;
- local Firebase emulator tests when the emulator toolchain is installed;
- static financial-display parity fixes where the server policy is already established;
- documentation/checklist updates backed by verified repository evidence;
- preparation of safe migration, audit, reconciliation, or release-evidence tooling that remains non-live.

## What remains human-controlled

The runner must not turn a red/live gate green merely because code can be written. The following remain explicit approval boundaries:

- merge to `main`;
- Firebase/Cloud Functions/Hosting production deployment;
- public production activation;
- live Stripe Portal/provider verification that needs authenticated dashboard evidence;
- live customer/subscription/payment/refund/transfer creation;
- live webhook expansion or legacy Stripe object deactivation;
- GST/HST/PST registration or tax/legal declarations;
- secrets or production credential changes;
- physical-device/store acceptance;
- provider contracts, licensing, accounting ownership, or other business/legal approvals.

This matches the existing payment execution tracker: code can advance autonomously, while provider, tax, reconciliation evidence, and production launch remain gated.

## Files

- `AGENTS.md` — repository-wide coding-agent policy and safety boundaries.
- `automation/agent/task_prompt.md` — one-iteration task-selection contract.
- `automation/agent/result.schema.json` — machine-readable result returned by Codex.
- `tool/autonomous_build.ps1` — time/task-bounded orchestration loop.
- `.agent-run/` — local logs/results created at runtime and excluded through `.git/info/exclude`.

## Prerequisites

The workstation must have:

1. Git available on `PATH`.
2. Codex CLI installed and authenticated (`codex` must run successfully).
3. The repository's supported Flutter/Node/Firebase development toolchain required by `tool/verify.ps1`.
4. A clean Git working tree before the autonomous run begins.

The runner uses the Codex CLI's existing authentication. It does not require an API key to be written into this repository.

## First recommended run

From the Pipe Buyer repository in PowerShell:

```powershell
.\tool\autonomous_build.ps1 -Hours 1 -MaxTasks 3
```

This is a calibration run. Review the resulting commits and `.agent-run` logs. If task selection and verification are behaving correctly, use the intended walk-away run:

```powershell
.\tool\autonomous_build.ps1 -Hours 3 -MaxTasks 8
```

If you want each verified commit backed up to the remote agent branch while you are away:

```powershell
.\tool\autonomous_build.ps1 -Hours 3 -MaxTasks 8 -Push
```

### Branch behavior

- If started on `main` or `master`, the runner automatically creates a timestamped branch such as `agent/autobuild-20260823-153000`.
- If started on another branch, it stays on that branch unless `-Branch` is supplied.
- The runner refuses to edit directly on `main`/`master`.
- The runner never merges the branch.

For stronger isolation, start the runner from a dedicated Git worktree and let it create/use an agent branch there.

## Loop behavior

For each iteration the runner:

1. gives Codex the repository agent policy and autonomous task-selection instructions;
2. has Codex inspect the `.md` trackers, implementation, tests, and Git history;
3. selects the highest-priority safe code task rather than blindly taking the first unchecked item;
4. performs one bounded increment and targeted verification;
5. executes the complete repository `tool/verify.ps1` gate;
6. allows a limited number of Codex repair attempts if the full gate fails;
7. commits only after the full gate passes;
8. optionally pushes the verified branch;
9. repeats until the time budget, task limit, completion state, or a genuine human blocker is reached.

## Failure handling

If Codex exits unexpectedly, the runner stops rather than guessing.

If the complete quality gate fails, the runner supplies the failure log to a bounded repair pass. When the configured repair limit is exhausted, it:

- does not create a commit;
- leaves the workspace changes available for inspection;
- writes a binary-capable patch under `.agent-run/`;
- records the quality-gate logs;
- stops the autonomous loop.

This is intentional. A walk-away build should fail closed instead of accumulating broken commits.

## Payment-work interpretation

`docs/PAYMENTS_EXECUTION_TRACKER.md` remains the payment queue. The autonomous worker may implement safe code/test items but must preserve the tracker's completion standard: UI, server authority, provider contract, event/webhook state, Firestore state, error behavior, reconciliation, and acceptance must agree where applicable.

For example, the worker can improve customer subscription UX or admin billing UX and test them. It cannot claim that a CA$25 monthly or CA$300 yearly live acceptance gate is complete unless the required provider and reconciliation evidence actually exists, and it cannot create the live transaction merely to obtain that evidence.

## Review after a walk-away run

When returning, inspect:

```powershell
git status
git log --oneline --decorate -20
git diff main...HEAD --stat
```

Then review `.agent-run/` for the structured task results and full verification logs. Open a pull request only after the branch is coherent and the expected gates are still respected.

Production deployment remains a separate exact-SHA operation after review and all required human/external gates are satisfied.
