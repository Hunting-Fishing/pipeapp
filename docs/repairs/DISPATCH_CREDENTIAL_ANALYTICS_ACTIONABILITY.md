# Dispatch credential analytics actionability repair

## Browser feedback

The Credential analytics & alerts screen exposed useful summary counts, but the cards were passive. A carrier could see values such as Current = 1, Not provided = 7, Evidence files = 0/1, and Insurance limits = 1 without being able to inspect the records behind those numbers. The Records screen also showed duplicate Analytics & alerts shortcut cards even though the permanent top Records / Analytics & alerts tab navigation was already clear and preferred.

## Root cause

The readiness summary used static `_metricTile` containers. They displayed counts only and had no `InkWell`, drill-down list, record action dialog, or evidence-management path. A previous discoverability repair had also added an in-content Analytics shortcut card; an already-present variant caused that shortcut to appear twice.

## Permanent repair

- Keep the permanent top `Records | Analytics & alerts` tabs as the primary navigation.
- Remove all legacy Records-view `Open analytics & alerts` shortcut cards.
- Make Current, Expired, Not provided, Evidence files, and Insurance limits visibly actionable.
- Each metric opens the exact private credential records that produced the displayed count.
- Selecting a record opens quick actions for editing metadata and uploading/replacing/removing private evidence where applicable.
- Evidence-file counts mean credential records with a private supporting image on file; they are not public verification.
- Metric tiles expose `View details`, a chevron, and button semantics so field users can tell the cards are interactive.
- `test/marketplace_dispatch_credential_analytics_actions_test.dart` protects the actionability and no-duplicate-shortcut contracts.
- `tool/run_dispatch_credential_analytics_actions_gate.ps1` is the focused bounded repair/verifier for this UX slice.
- The full Phase 3 acceptance gate now includes the same analytics actionability repair and test so the duplicate/passive state cannot be reintroduced by a later credential migration.

## Scope control

This repair changes credential UI source/template only. It does not change Dispatch completion scoring, Firebase Auth, service-area geography, administrator claims, or public credential visibility.
