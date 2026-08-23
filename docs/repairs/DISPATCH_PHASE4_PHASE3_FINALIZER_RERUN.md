# Dispatch Phase 4 - Phase 3 finalizer rerun safety

## Symptom

The Phase 4 Directory widget suite passed, but rerunning `tool/verify_dispatch_phase4_directory_foundation.ps1` stopped immediately in the Phase 3 browser-acceptance finalizer.

The error reported that the tracker marker:

```text
**Current verified completion:** **50%**
```

was missing.

That marker was missing because the first Phase 4 gate attempt had already successfully changed the local Dispatch tracker from 50% / Phase 3 13/15 to 52% / Phase 3 15/15 before a later Directory widget test failed.

## Root cause

The product state was valid. The gate was not rerunnable.

A previous local copy of `finalize_dispatch_phase3_browser_acceptance.mjs` assumed it would only ever see the 50% pre-finalization tracker. After it performed the one-time 50% -> 52% transition, a later gate retry invoked the same old finalizer again and treated the already-finalized tracker as an error.

This was not a Directory, Firebase, Firestore, authentication, service taxonomy, Company Profile, credential, or map defect.

## Permanent repair

1. `tool/finalize_dispatch_phase3_browser_acceptance.mjs` now recognizes two valid input states:
   - the accepted 50% / Phase 3 13/15 baseline, which it transitions to 52%;
   - the fully-finalized 52% / Phase 3 15/15 state, which is a no-op.
2. A mixed or partial tracker state still stops the process and reports which baseline/finalized markers are missing. The tool never guesses how to repair an inconsistent tracker.
3. The finalizer accepts `--plan <path>` so its transition can be tested against an isolated temporary tracker without modifying the real project plan.
4. `tool/finalize_dispatch_phase3_browser_acceptance_test.mjs` runs the finalizer twice against a temporary 50% fixture and proves:
   - the first run produces the 52% Phase 4 entry state;
   - the second run makes no file changes.
5. `tool/verify_dispatch_phase4_directory_foundation.ps1` now checks tracker state before invoking the finalizer. If the tracker is already at the complete 52% state, it skips tracker mutation entirely.
6. The Phase 4 gate runs the idempotency regression before continuing with Directory integration, analyzer, and widget/regression tests.

## Rule going forward

Any build gate that performs an accepted one-time tracker/state transition before later tests must be safe to rerun after a downstream failure.

A rerun must distinguish:

```text
pre-transition valid state -> perform transition
already-transitioned valid state -> no-op
mixed/partial state -> safety stop and inspect
```

Do not roll a tracker backward simply to satisfy a non-idempotent script, and do not re-award progress points on retries.
