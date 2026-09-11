# Staging trigger drift repair — 2026-09-10

## Scope

This record is limited to Firebase staging project `pipebuyer-5c77f`. Production project `flutter-flow-pipe` is explicitly out of scope and must not be modified by the repair workflow.

## Evidence

Verified release workflow run `34507485819` attempted commit `4b260771937bf247851d6eb24d1715d866eff9fe` twice. Both retained deployment logs stopped at the same Firebase CLI error for `marketplace:protectAuctionReserve(us-central1)`: the deployed staging resource is HTTPS while the reviewed source defines a Firestore background trigger. The deployment never reached deployed Function parity or visual acceptance.

The same R3 production evidence records `protectAuctionReserve` as an active Gen2 Firestore `google.cloud.firestore.document.v1.written` trigger in `flutter-flow-pipe`. This demonstrates that the source definition is valid and that the conflicting HTTPS identity is staging-only environmental drift.

`acceptMarketplaceDispute` remains a Gen2 callable and is not modified by this repair. The retained R4 staging deployment evidence does not reach an `acceptMarketplaceDispute` startup failure, so changing its business logic would not be evidence-based.

Repair workflow run `34610925599` then inventoried staging before deletion. Firebase reported exactly one `marketplace:protectAuctionReserve` in project `pipebuyer-5c77f`, region `us-central1`, platform `gcfv2`, with an `httpsTrigger`, but lifecycle state `FAILED`. The original guard rejected every non-`ACTIVE` state, so it failed closed and skipped deletion. This run therefore supplied additional live evidence without mutating staging.

Repair workflow run `34611284088` used the corrected guard against reviewed SHA `ca22a57d46ea0bf0ecf764e439acc992302d40c6`. It deleted only the proven stale `protectAuctionReserve` HTTPS identity and then proved that function identity was absent from staging.

The subsequent normal staging release run `34611419936` passed all pre-deploy application, Functions, rules, callable-integration, and release-build gates. Firebase then stopped on `marketplace:onTagRequestCreated(us-central1)` with the same immutable trigger-type conflict: staging still has it as HTTPS while the reviewed source exports `onTagRequestCreated` with `onDocumentCreated("tag_requests/{requestId}", ...)`. The retained pre-repair staging inventory contains only three marketplace HTTPS functions: `stripeMarketplaceWebhook`, the already-repaired `protectAuctionReserve`, and `onTagRequestCreated`. `stripeMarketplaceWebhook` is intentionally HTTPS, so the second proven stale HTTPS identity is bounded to `onTagRequestCreated`.

## Repair contract

`tool/staging_trigger_repair.mjs` contains an explicit allowlist for only the proven stale staging HTTPS identities. It requires exact project `pipebuyer-5c77f`, exact function id, region `us-central1`, codebase `marketplace`, and an HTTPS trigger before deletion is permitted. The only permitted lifecycle states are `ACTIVE` and `FAILED`. A background, callable, unknown, missing, duplicated, unexpected-state, wrong-project, wrong-region, wrong-codebase, or non-allowlisted function fails closed.

The original `protectAuctionReserve` workflow remains backward compatible. The second repair selects only `onTagRequestCreated`; `stripeMarketplaceWebhook` and `acceptMarketplaceDispute` are explicitly outside the repair allowlist. After deletion, the workflow must require the selected stale function identity to be absent and preserve before/after inventories as evidence. No repair workflow may deploy or mutate production.

## Release continuation

After the second staging repair succeeds, run the normal `Deploy verified Firebase release` workflow against the exact reviewed merge commit in `staging` with App Check disabled. That normal workflow must complete Firebase deployment, deployed Function parity, and visual acceptance. Only that same staging-proven SHA may then be considered for a production run, with App Check set to `enforce` and all production verification gates passing.
