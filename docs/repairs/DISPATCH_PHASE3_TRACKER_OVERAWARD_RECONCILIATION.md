# Dispatch Phase 3 Tracker Over-Award Reconciliation

**Branch:** `design/formal-beautification-foundation`

## Symptom

During Phase 3 credential-intelligence work, the local Dispatch master plan reported 52% / Phase 3 15-of-15 before the expanded Credentials & Insurance browser workflow had been accepted. The service-area browser acceptance had passed, but the credential browser point had not.

The service-area acceptance recorder correctly refused to move a 52% tracker backward. The credential-intelligence migration then failed because it still contained an old exact 50% -> 51% tracker mutation.

## Root cause

Feature migration, verification, and browser-acceptance accounting were coupled together. Interrupted or partially applied tooling could leave application source successfully migrated while tracker text moved independently.

## Correct accepted state before credential browser acceptance

```text
Overall: 51/100 = 51%
Phase 3: 14/15 - IN PROGRESS
Service area/home base: accepted
Credential/insurance browser acceptance: not yet accepted
Phase 4: blocked
```

## Permanent controls

1. `tool/apply_dispatch_credential_intelligence.ps1` modifies only credential/Functions implementation. It no longer edits `DISPATCH_NETWORK_MASTER_PLAN.md` or awards acceptance points.
2. `tool/verify_dispatch_credential_intelligence.ps1` is read-only with respect to production source and tracker state. It verifies implementation, tests, privacy boundaries, notification wiring, and the expected pre-credential-acceptance tracker state.
3. `tool/reconcile_dispatch_phase3_precredential_acceptance.ps1` is the one-time bounded reconciler for the known 50/51/52 and 13/14/15 interrupted states. It backs up the plan and normalizes to 51% / 14-of-15 only while Phase 4 remains untouched and blocked.
4. `tool/sync_dispatch_phase3_closeout_bundle.ps1` includes these controls so future sessions do not manually maintain dependency lists.

## Safety rule

Do not award the credential point from an engineering migration or verifier. Only a dedicated acceptance/finalization action may advance Phase 3 to 15/15 after the browser workflow is explicitly accepted.
