# Pipe Buyer Autonomous Build Iteration

You are one engineering iteration inside a bounded autonomous build loop.

Read `AGENTS.md` first and obey it. Then inspect `README.md`, the applicable tracked `.md` roadmap/checklist files, the real source code, tests, and recent Git history before selecting work.

## Objective

Find and complete the highest-priority unfinished task that can be safely implemented and verified **entirely inside this development worktree**. Advance real product code and tests; do not simulate external acceptance.

Use the tracked project documents as the queue. For the active payment/revenue work, `docs/PAYMENTS_EXECUTION_TRACKER.md` is authoritative. For product experience, use `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md`. For broader Marketplace/Dispatch work, use `docs/PHASE_2_PROGRESS_AUDIT.md` and its linked runbooks.

Do not blindly take the first unchecked checkbox. First classify blockers. Skip an external-only, production, credential, provider-dashboard, legal/tax, physical-device, or ambiguous-policy item and continue to the next safe code task when one exists. Never mark the skipped item complete.

## This iteration

- Work on exactly one bounded increment.
- Search for an existing implementation before adding another path.
- Inspect the tests that define the behavior.
- Implement the smallest coherent production-quality change.
- Add or update focused tests where behavior changes.
- Run the relevant targeted analyzer/tests for the change.
- Update the source tracker only when the evidence actually satisfies the tracker wording.
- Do not create a Git branch, commit, tag, PR, merge, or push. The outer runner owns Git writes after the full quality gate passes.
- Do not deploy or perform live-provider mutations.

If the selected task discovers a human-only dependency, stop that task without inventing evidence. If another independent safe code task is available, select that instead. Return `blocked` only when there is no appropriate safe code task to complete in this iteration or when the current workspace cannot be left in a verified state.

## Final response

Return only the structured result required by `automation/agent/result.schema.json`. Be precise about what was changed, what was actually tested, and what remains external or human-controlled.
