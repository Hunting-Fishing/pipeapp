# Staging trigger drift repair — 2026-09-10

## Scope

This record is limited to Firebase staging project `pipebuyer-5c77f`. Production project `flutter-flow-pipe` is explicitly out of scope and must not be modified by the repair workflow.

## Evidence

Verified release workflow run `34507485819` attempted commit `4b260771937bf247851d6eb24d1715d866eff9fe` twice. Both retained deployment logs stopped at the same Firebase CLI error for `marketplace:protectAuctionReserve(us-central1)`: the deployed staging resource is HTTPS while the reviewed source defines a Firestore background trigger. The deployment never reached deployed Function parity or visual acceptance.

The same R3 production evidence records `protectAuctionReserve` as an active Gen2 Firestore `google.cloud.firestore.document.v1.written` trigger in `flutter-flow-pipe`. This demonstrates that the source definition is valid and that the conflicting HTTPS identity is staging-only environmental drift.

`acceptMarketplaceDispute` remains a Gen2 callable and is not modified by this repair. The retained R4 staging deployment evidence does not reach an `acceptMarketplaceDispute` startup failure, so changing its business logic would not be evidence-based.

## Repair contract

`.github/workflows/repair-staging-protect-auction-reserve.yml` is intentionally narrow. It requires the protected `staging` environment, exact project `pipebuyer-5c77f`, exact function `marketplace:protectAuctionReserve`, exact region `us-central1`, and a deployed HTTPS trigger before deletion is permitted. A background, callable, unknown, missing, duplicated, inactive, wrong-project, wrong-region, or wrong-codebase target fails closed.

After deletion, the workflow requires the stale function identity to be absent and preserves the before/after inventories as an Actions artifact. It does not deploy production and it does not promote a release.

## Release continuation

After the repair succeeds, run the normal `Deploy verified Firebase release` workflow against the exact reviewed commit in `staging` with App Check disabled. That normal workflow must complete Firebase deployment, deployed Function parity, and visual acceptance. Only that same staging-proven SHA may then be considered for a production run, with App Check set to `enforce` and all production verification gates passing.
