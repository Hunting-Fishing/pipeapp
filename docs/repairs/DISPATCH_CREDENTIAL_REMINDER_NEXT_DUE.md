# Dispatch credential reminder next-due scheduling repair

Date: 2026-08-18
Branch: `design/formal-beautification-foundation`

## Symptom

The focused reminder regression failed after a 30-day threshold had already been sent. For a credential expiring on 2026-09-07 with the 30-day reminder already recorded on 2026-08-18, the scheduler returned 2026-08-18 again instead of the next future 14-day threshold on 2026-08-24.

## Root cause

`computeCredentialReminderState` iterated every unsent reminder threshold and converted any threshold whose nominal due date was already in the past into `nowMs`. That made older 60/90-day thresholds re-queue immediately even after the more-specific 30-day threshold had already been delivered.

## Proven correction

The scheduler now:

- sends only the closest threshold currently due;
- does not replay older, less-specific overdue thresholds after that threshold is recorded as sent;
- schedules only unsent threshold dates that are still in the future;
- schedules one post-expiry checkpoint for the single expired reminder after threshold reminders are exhausted.

The regression suite explicitly protects both the 30-day -> 14-day transition and the final-threshold -> expired transition.

## Permanent process control

Engineering verification is separated from Dispatch progress bookkeeping.

`tool/verify_dispatch_credential_intelligence.ps1` is source-read-only and treats `docs/DISPATCH_NETWORK_MASTER_PLAN.md` as informational only. It hashes protected production files before and after verification and fails if the verifier mutates them.

`tool/sync_dispatch_phase3_closeout_bundle.ps1` synchronizes only support/control/test files. It does not blindly overwrite production Dart/Functions source or the Dispatch tracker.

`tool/update_dispatch_credential_reminder_engine.ps1` can replace only the one recognized broken reminder-engine revision. Unknown local revisions are preserved and cause a safety stop.

`tool/run_dispatch_phase3_credential_gate.ps1` is the single entry point for Doctor -> known revision normalization -> source-read-only verification.
