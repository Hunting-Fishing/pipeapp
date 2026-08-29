# VIP production activation — 2026-08-29

## Scope

Enable only the verified Pipe Buyer VIP monthly subscription in production after the exact VIP runtime source was deployed and accepted. Do not enable split/deposit payments, affiliate payouts, automated financial resolution, dispute automation, dispute evidence automation, or platform-funded refund overrides. Keep Stripe automatic tax disabled while Canadian tax registration is pending.

## Verified runtime source

- Runtime source SHA: `a2ab6ca51eb1eb56e1f167cfd9ca702658a999d0`
- Verified production release run: `33248095951`
- Deploy job: `99088951996` — success
- Production visual acceptance job: `99090164192` — success
- Release manifest, Firebase deploy, deployed Function parity, release identity, and visual acceptance all passed.

## Release-manifest blocker and repair

The first VIP production release run `33245480074` stopped at `Record exact release manifest` before Firebase deployment.

Root cause: `.github/workflows/release-vip-monthly-live-20260829.yml` dispatched production with `app_check_mode=observe`, while `tool/release_manifest.mjs` intentionally requires `app_check_mode=enforce` for production.

Repair: keep the manifest security rule unchanged and change only the VIP launcher to dispatch `app_check_mode=enforce`. The corrected launcher run `33248088778` succeeded and dispatched the verified production release above.

Detailed repair record: `docs/repairs/VIP_RELEASE_APP_CHECK_MODE_2026-08-29.md`.

## Activation guard repair

The first guarded VIP activation workflow used the wrong exact visual job label. It expected `Production visual acceptance`; the real verified release job is `Visual acceptance production`.

This failed closed before any production readiness write. The guard was corrected to the exact job name.

## Temporary activator deployment blocker and repair

Activation run `33248626942`, job `99090319997`, passed:

- exact runtime/source guard
- verified production deployment/parity/release/visual guard
- live Stripe account verification
- live VIP product and price verification
- live webhook verification
- one-time token preparation
- temporary activator syntax validation

It then failed before any readiness write at `Deploy one-time VIP activator`.

Exact Firebase error:

> Couldn't find firebase-functions package in your source code. Have you run 'npm install'?

Root cause: the activation workflow installed the Firebase CLI globally but did not restore the local `firebase/functions` dependency tree. Firebase CLI therefore could not load `firebase-functions` while analyzing the temporary function source.

Repair: do not change the activator or Firebase version. Restore the Functions dependencies first with `npm ci --prefix firebase/functions`, run the existing Functions audit/lint/check suite, then deploy the temporary activator.

## Successful activation

- Retry workflow commit: `e4fddf2fbcef03b05caa164620bacf5fdce1714d`
- Successful activation run: `33248736478`
- Successful activation job: `99090605161`
- Functions dependency restore: success
- Functions audit/lint/check: success
- Functions tests: **322 passed, 0 failed**
- Live Stripe account/product/price/webhook verification: success
- VIP product: `prod_VA12LaMiaCMRqZ`
- VIP price: `price_1U9h0tDkO07WMXyRgdzAmm43`
- Verified price: **CAD $100/month**, live and active
- Temporary activator deployment: success
- Missing-token probe: correctly rejected with HTTP 403
- Audited VIP readiness write: success
- Temporary activation function deletion: success

## Production readiness result

The successful transaction changed only the VIP billing readiness switch plus normal readiness revision/audit metadata:

- `stripeVipSubscriptionsEnabled: true`

The activator required and re-verified the following production safety profile during the same transaction/result:

- `stripeMode: "production"`
- `stripeSubscriptionsEnabled: true`
- `stripeWebhookVerified: true`
- `stripeReconciliationReady: true`
- `stripeTaxReady: false`
- `stripeTaxRegistrationPending: true`
- `marketplaceTaxCollectionDeferredApproved: true`
- `affiliatePayoutsEnabled: false`
- `marketplaceFinancialResolutionEnabled: false`
- `marketplaceDisputeAutomationEnabled: false`
- `marketplaceDisputeEvidenceEnabled: false`
- `platformFundedRefundOverrideEnabled: false`

Stripe automatic tax remains disabled because `stripeTaxReady` remains false. Canadian tax registration remains pending and no registration number was invented or asserted.

## Do not repeat

1. Production release launchers must use App Check `enforce`.
2. Guard exact GitHub job names against the real verified release jobs.
3. Any Firebase temporary-function deployment must restore the local Functions dependency tree before Firebase source analysis.
4. A one-time activation endpoint must be token-guarded, fail closed on readiness drift, write an audit record, verify the post-write safety profile, and be deleted immediately afterward.
5. Do not reuse VIP activation as authority to enable deposits/splits, affiliate payouts, automated disputes/refunds, or Stripe automatic tax.
