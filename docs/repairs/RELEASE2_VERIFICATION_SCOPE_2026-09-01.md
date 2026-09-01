# Release 2 verification-scope repair — 2026-09-01

## Symptom

The guarded Marketplace journey-status build stopped twice at `Verify integration mutation scope` before analyzer/test execution. The exact integration patch succeeded, but the guard reported the new journey helper and its test as unexpected working-tree changes.

## Root cause

The workflow intentionally runs `dart format` on the two newly added bounded Dart files after checkout. Those formatter-normalization edits therefore appear in `git diff` alongside the two large Marketplace integration files patched by exact anchors. The scope guard incorrectly assumed that only the two integration files could be modified at that point.

This was a verification-scope defect, not a transaction-state, payment, Marketplace, Timed Buying, or Dispatch defect.

## Repair

Keep the guard strict, but use an explicit four-file allowlist for the only files this verification may modify:

- `lib/marketplace/marketplace_journey_status.dart`
- `test/marketplace_journey_status_test.dart`
- `lib/marketplace/marketplace_messages_page.dart`
- `lib/marketplace/marketplace_auction_settlement.dart`

Reject every changed path outside that allowlist. Continue to require both integration files to be present because the exact-anchor patch must change them. Persist formatter output for the two new bounded files when the verification commits the proven slice.

## Do not repeat

A changed-file guard that runs after a formatter must distinguish expected formatter output from unrelated mutation. Do not weaken the guard to an unrestricted file count, and do not broadly format the large Marketplace source files to make the guard easier to satisfy. Preserve the Release 1 formatter boundary: large established source receives exact bounded edits only; newly created small files may be canonically formatted and explicitly allowlisted.
