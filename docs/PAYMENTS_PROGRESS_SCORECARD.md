# Pipe Buyer — Payments Progress Scorecard

Status: active  
Started: 2026-08-21  
Last updated: 2026-08-22  
Detailed engineering/evidence log: `docs/PAYMENTS_EXECUTION_TRACKER.md`  
Provider acceptance matrix: `docs/DISPATCH_STRIPE_ACCEPTANCE_MATRIX.md`  
Current implementation PR: #88 `fix/dispatch-checkout-hardening`

## Purpose

This is the operational percentage/checkoff dashboard for payment readiness. The detailed tracker remains the root-cause, repair and evidence log.

## Percentage rules

1. **Verified %** counts only acceptance items complete with evidence.
2. Code in the Draft PR is not automatically production-verified.
3. **Implemented coverage** may count repaired code awaiting live/local acceptance, but does not mean launch-ready.
4. A launch blocker can stop release regardless of percentage.
5. When a real missing requirement is found, scope expands. We do not preserve a higher percentage by hiding work.
6. Every completed repair must leave a durable record of root cause, exact fix and verification path.

---

# Current verified progress

| Phase | Verified | Scope | Verified % | Current status |
| --- | ---: | ---: | ---: | --- |
| P0 — Financial / legal truth | 20 | 28 | **71%** | Branch truth repaired; updated Terms/Privacy still need live deployment + publication |
| P1 — Stripe/webhook integrity | 10 | 15 | **67%** | Live baseline good; expanded event catalog awaits deployed-handler acceptance |
| P2 — Dispatch subscriptions | 13 | 63 | **21%** | **~68% verified + implemented**; local no-GitHub release path now exists |
| P3 — External-settlement Marketplace fee | 4 | 15 | **27%** | Second revenue target; not active |
| P4 — Full Marketplace Checkout / Connect | 7 | 19 | **37%** | Gated; do not activate |
| P5 — Tax readiness | 0 | 12 | **0%** | Commercial/tax launch gate |
| P6 — Refunds/disputes/seller recovery | 2 | 11 | **18%** | Foundation exists; acceptance pending |
| P7 — Reconciliation/accounting | 0 | 17 | **0%** | Operational completion required |
| **TOTAL** | **56** | **180** | **31%** | Overall verified payments checklist |

> **Important:** the decrease from 32% to 31% is intentional. We discovered missing live legal/payment-consent and no-Actions release controls and added them to scope instead of hiding them.

## P2 engineering implementation view

Current P2 scope: **63 acceptance items**.

- Verified complete: **13 / 63 = 21%**
- Additional items implemented in Draft PR #88 but awaiting deployment/provider acceptance: **30**
- Verified + implemented coverage: **43 / 63 = 68%**
- Not yet implemented/accepted: **20 / 63 = 32%**

---

# GitHub Actions billing decision

Owner decision: GitHub Actions billing remains **OFF** while Pipe Buyer is completed.

Hosted GitHub Actions is no longer a mandatory Stripe activation dependency because PR #88 now contains equivalent local release tooling:

- `scripts/payments/dispatch_revenue_local_release.sh`
  - Functions install/audit/lint/check/unit tests
  - Flutter analyze/tests
  - legal-document hashes
  - direct controlled Firebase Functions deployment
  - read-only live Stripe account/price/webhook/Portal probe
- `scripts/payments/deploy_dispatch_web_legal_local.sh`
  - Flutter validation/build
  - verifies built Terms contain CA$25/month + CA$300/year
  - rejects obsolete `$25/year`, `$10/job`, and `No fee is currently charged` language
  - deploys Firebase Hosting directly
- `scripts/payments/sync_dispatch_stripe_webhook_local.sh`
  - verifies live Stripe account
  - requires a signed round-trip against the newly deployed handler
  - only then synchronizes the live webhook event catalog
- `scripts/payments/create_dispatch_portal_config_local.sh`
  - creates/reuses only a narrow live Customer Portal configuration
  - payment-method update ON
  - cancel at period end ON
  - plan switching OFF
  - does **not** enable Portal readiness or subscriptions

GitHub Actions Issue #91 remains useful as optional secondary CI assurance and future automation-cost work. It is not a reason to change payment code and is not required to begin Stripe earnings if equivalent local validation and controlled provider acceptance pass.

---

# P0 — Financial / legal truth

## Verified

- [x] Approved Dispatch catalog is CA$25/month and CA$300/year.
- [x] Obsolete pilot pricing removed from customer subscription UI source.
- [x] Dedicated membership page uses server catalog; no local price fallback.
- [x] Unsafe legacy GitHub live-billing activation workflows removed from PR #88 so they cannot overwrite current readiness fields or restore old query-string payment URLs.

## Implemented, live acceptance pending

- [ ] `web/terms.html` updated for recurring CA$25/month / CA$300/year Dispatch membership, renewal, cancel-at-period-end, failed-renewal and Stripe-provider behavior.
- [ ] `web/privacy.html` updated to accurately disclose Stripe/payment/subscription data processing while preserving the no-escrow distinction.
- [ ] Deploy reviewed Terms/Privacy to Firebase Hosting.
- [ ] Independently verify public `/terms` and `/privacy` content/hash after deployment.
- [ ] Publish new Terms and Privacy versions through the audited `publishPolicyDocument` callable.
- [ ] Enable/verify exact-version policy enforcement before paid Dispatch Checkout is activated.

Current live-site problem discovered 2026-08-22: the public Terms still describe the old `$25/year + $10/job` proposed pilot and say billing is inactive. **Do not activate customer charging until the updated legal pages are live and published.**

---

# P2 — Dispatch subscriptions

## Already verified on current baseline

- [x] Authenticated Firebase subscription command exists.
- [x] Paid-feature and Dispatch feature gates exist.
- [x] Server chooses Stripe Price IDs.
- [x] Client cannot supply authoritative subscription amount.
- [x] Monthly maps to intended recurring CAD price.
- [x] Yearly maps to intended recurring CAD price.
- [x] Stripe Checkout uses subscription mode.
- [x] Billing address collection is required.
- [x] Promotion coupon selection is server-owned.
- [x] Affiliate relationship metadata is server-read.
- [x] Checkout session is persisted.
- [x] Checkout readiness is fail-closed.
- [x] Initial hosted Stripe purchase/Portal surface is web-only; native builds keep existing membership access but do not expose hosted Stripe purchase/management controls.

## Implemented in PR #88 — acceptance still required

- [ ] Firestore checkout reservation/lease prevents concurrent duplicate creation.
- [ ] Stable attempt-number Stripe idempotency key.
- [ ] Same-plan open Checkout Session reuse.
- [ ] Different-plan overlapping checkout fails closed.
- [ ] Missing plan fails closed instead of defaulting to a product.
- [ ] Current paid membership blocks another checkout.
- [ ] Existing nonterminal Stripe subscription blocks another checkout even before entitlement exists.
- [ ] Current policy acceptance is checked before the provider-state guard can allow a paid Checkout when policy enforcement is enabled.
- [ ] `checkout.session.completed` records provider subscription existence without granting access.
- [ ] `invoice.paid` creates/extends `dispatch_memberships/{uid}`.
- [ ] Paid entitlement never shortens an existing paid-through date.
- [ ] `invoice.payment_failed` records payment trouble without prematurely revoking paid time.
- [ ] Subscription created/updated/deleted/paused/resumed lifecycle is modeled.
- [ ] Cancellation at period end preserves access only through paid-through.
- [ ] Expired membership is rejected by server-side carrier bidding.
- [ ] Private authenticated `getDispatchSubscriptionStatus` callable exists.
- [ ] Server-authoritative `getDispatchSubscriptionCatalog` callable exists.
- [ ] Dedicated Dispatch membership page exists.
- [ ] Existing memberships dialog links to secure Dispatch membership flow.
- [ ] `/payments/dispatch`, `/payments/success`, `/payments/cancel` routes exist.
- [ ] Browser success redirect does not grant entitlement.
- [ ] VIP billing remains disabled while unapproved.
- [ ] Fail-closed Customer Portal callable/UI exists.
- [ ] Portal configuration is re-read from Stripe and rejected unless active, payment-method update ON, cancel-at-period-end ON, and plan switching OFF.
- [ ] Native iOS/Android hosted Stripe controls fail closed.
- [ ] Local no-GitHub validation/direct Firebase Functions deployment path exists.
- [ ] Local guarded live Stripe webhook synchronization path exists.
- [ ] Local guarded web/legal Hosting deployment path exists.
- [ ] Local guarded narrow Stripe Customer Portal configuration creation path exists.

## Still required / not accepted

- [ ] Run local Functions full validation successfully.
- [ ] Run local Flutter full validation successfully.
- [ ] Deploy and verify updated web/legal build.
- [ ] Publish updated Terms/Privacy and prove stale-version reacceptance.
- [ ] Read actual production `platform_configuration/payment_provider_readiness` values and revision.
- [ ] Confirm intended `stripeMode`, `stripeSubscriptionsEnabled`, `stripeWebhookVerified`, `stripeReconciliationReady`, tax state and URLs.
- [ ] Verify `https://www.pipebuyer.com/payments/success`, `/payments/cancel`, and `/payments/dispatch` after hosting deployment.
- [ ] Deploy current Dispatch Functions from the validated commit.
- [ ] Signed deployed-webhook probe passes.
- [ ] Synchronize live Stripe endpoint to `STRIPE_WEBHOOK_EVENTS` only after handler probe passes.
- [ ] Create/approve narrow live Customer Portal `bpc_…` configuration and save it through audited readiness control.
- [ ] Controlled duplicate-click/retry creates exactly one active Stripe attempt.
- [ ] Controlled paid Monthly invoice creates exactly one correct membership.
- [ ] Controlled paid Yearly invoice creates exactly one correct membership.
- [ ] Renewal extends membership exactly once.
- [ ] Failed renewal preserves access only through paid-through.
- [ ] Cancellation/end-of-period signed-event acceptance passes.
- [ ] Pause/resume provider-state acceptance passes.
- [ ] 1-year free entitlement acceptance passes.
- [ ] 5-year free entitlement acceptance passes.
- [ ] 100%-discount invoice creates no false revenue/affiliate commission.
- [ ] Stripe invoice/payment reconciles to Pipe Buyer state/ledger with zero unexplained difference.
- [ ] Controlled colleague acceptance passes.

P2 definition of done: a carrier on the approved web purchase surface can review/accept current policies, choose Monthly or Yearly, complete secure Stripe Checkout, receive exactly one provider-confirmed paid entitlement, renew/cancel safely, lose bidding access after paid-through expires, and the money/state reconciles.

---

# Revenue activation sequence — no GitHub billing required

1. [ ] Run `scripts/payments/dispatch_revenue_local_release.sh validate`.
2. [ ] Review the August 22 Terms/Privacy changes.
3. [ ] Run guarded local web/legal deployment and verify the public documents/hashes.
4. [ ] Publish new Terms/Privacy versions through `publishPolicyDocument`; verify all five required policies are current.
5. [ ] Enable exact-version policy enforcement through `setPolicyEnforcement` with an approval record.
6. [ ] Run controlled local Functions deployment from the validated commit.
7. [ ] Read and record live payment-readiness values before changing them.
8. [ ] Create/review the narrow Stripe Customer Portal configuration; keep Pipe Buyer Portal flag OFF until reviewed.
9. [ ] Run signed webhook probe, then synchronize the expanded live event catalog.
10. [ ] Run controlled Monthly/Yearly/free-promotion/renewal/failure/cancellation tests.
11. [ ] Reconcile provider invoice/payment to Firestore membership/invoice/ledger state.
12. [ ] Only then enable the narrow web Dispatch subscription readiness profile. Keep full Marketplace Checkout and affiliate cash payouts OFF.

---

# Change log

## 2026-08-22

- [x] Confirmed GitHub Actions billing can remain off; added local validation/deployment replacement path.
- [x] Discovered public Terms still contained obsolete pilot pricing and billing-inactive statement; recorded as launch blocker.
- [x] Updated branch Terms and Privacy for current Stripe Dispatch billing model; live deployment/publication still pending.
- [x] Added current-policy acceptance check to Dispatch paid Checkout provider guard.
- [x] Added guarded local Functions release/probe script.
- [x] Added guarded local Firebase Hosting/legal release script.
- [x] Added guarded local live Stripe webhook synchronization script.
- [x] Added guarded local Stripe Customer Portal configuration creation script.
- [x] Removed three stale GitHub billing activation workflows that could write obsolete URLs/readiness state.
- [x] Reclassified GitHub-hosted Actions as optional secondary assurance rather than a mandatory Stripe activation dependency.
- [x] Scope expanded honestly; overall verified score is now **31%**, Dispatch verified **21%**, Dispatch verified + implemented **~68%**.

## 2026-08-21

- [x] Created percentage-based scorecard and acceptance formula.
- [x] Replaced stale Dispatch pilot pricing with server-backed subscription pricing.
- [x] Added fail-closed Stripe Customer Portal architecture.
- [x] Added subscription lifecycle and failed-payment handling.
- [x] Added authoritative Stripe webhook event catalog and acceptance matrix.
- [x] Restricted hosted Stripe purchase/Portal controls to web for the initial North American release.
