# Dispatch Phase 3 Acceptance Tracker Decoupling

**Branch:** `design/formal-beautification-foundation`

**Date:** 2026-08-18

## Symptom

The credential-intelligence migration successfully installed its Dart source and Functions wiring, then stopped while trying to change the Dispatch master-plan score from the earlier 50% / 13-of-15 service-area baseline.

The failure was:

```text
Expected exactly one source target for 'overall verified completion after service-area acceptance', found 0.
```

The Towns/Regions regression immediately before this step was green.

## Root cause

Browser acceptance state and credential source migration were coupled inside one exact-text migration. The user's local master plan could already contain part or all of the accepted service-area tracker update, while the credential source and Functions wiring were still being applied. Exact replacement of one historic tracker string therefore became an unnecessary blocker for otherwise idempotent source work.

This is a workflow/control defect, not a credential model defect.

## Permanent control

`tool/record_dispatch_phase3_service_area_acceptance.ps1` is now the explicit acceptance recorder for the service-area point.

It:

- requires the formal branch;
- reads the tracker semantically rather than depending on one historic literal;
- accepts only the known 50/13 pre-acceptance state, 51/14 accepted state, or a mixed partial state containing only those values;
- refuses values beyond 51% / 14-of-15 so it cannot downgrade or skip ahead;
- backs up the master plan before changing it;
- normalizes all service-area tracker locations to 51% overall and 14/15 Phase 3;
- checks the service-area checklist;
- records browser acceptance evidence once;
- does not award the credential point;
- does not unlock Phase 4.

After this recorder succeeds, the existing credential-intelligence migration can be rerun safely. Its source, Functions index, and notification-policy changes are idempotent and recognize already-applied markers.

## Repair rule going forward

Browser acceptance points are recorded by dedicated acceptance recorders/finalizers. Feature source migrations should not be responsible for deciding whether a browser acceptance point has been earned.
