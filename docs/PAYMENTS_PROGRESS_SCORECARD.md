# Pipe Buyer — Payments Progress Scorecard

Status: active  
Started: 2026-08-21  
Last updated: 2026-08-21  
Detailed engineering/evidence log: `docs/PAYMENTS_EXECUTION_TRACKER.md`  
Provider acceptance matrix: `docs/DISPATCH_STRIPE_ACCEPTANCE_MATRIX.md`  
Current implementation PR: #88 `fix/dispatch-checkout-hardening`

## Purpose

This is the short operational scorecard we use to answer **where are we, what is actually complete, and what is blocking launch?**

The detailed tracker remains the evidence and repair log. This scorecard is the percentage/checkoff view.

## Percentage rules

1. **Verified %** counts only acceptance items that are actually complete and supported by evidence.
2. Code that exists in a Draft PR but has not passed CI/provider acceptance remains unchecked.
3. **Implemented %** may be shown for a phase when code exists but acceptance is still pending. Implemented does not mean production-ready.
4. A blocker can prevent launch even when the numerical percentage is high.
5. When scope expands because a real defect is found, the denominator expands. We do not hide new work to preserve a higher percentage.
6. When an item is checked off, record the evidence in `PAYMENTS_EXECUTION_TRACKER.md` and the PR/commit/run/provider object where applicable.

---

# Current verified progress

| Phase | Verified | Scope | Verified % | Current status |
| --- | ---: | ---: | ---: | --- |
| P0 — Financial truth | 19 | 25 | **76%** | Pricing/policy cleanup still open |
| P1 — Stripe/webhook integrity | 10 | 15 | **67%** | Live baseline good; controlled verification pending |
| P2 — Dispatch subscriptions | 13 | 58 | **22%** | **~66% verified + implemented**, hosted CI deliberately deferred |
| P3 — External-settlement Marketplace fee | 4 | 15 | **27%** | Second revenue target; not active |
| P4 — Full Marketplace Checkout / Connect | 7 | 19 | **37%** | Gated; do not activate |
| P5 — Tax readiness | 0 | 12 | **0%** | Launch gate |
| P6 — Refunds/disputes/seller recovery | 2 | 11 | **18%** | Foundation exists; acceptance pending |
| P7 — Reconciliation/accounting | 0 | 17 | **0%** | Operational completion required |
| **TOTAL** | **55** | **172** | **32%** | Overall verified payments checklist |

> **Important:** 32% is checklist completion, not commercial launch readiness. Dispatch P2 is the current revenue target and its critical path is much further along in code than its 22% verified acceptance score.

## P2 engineering implementation view

Current P2 scope: **58 acceptance items**.

- Verified complete: **13 / 58 = 22%**
- Additional items implemented in Draft PR #88 but awaiting CI/provider acceptance: **25**
- Verified + implemented coverage: **38 / 58 = 66%**
- Not yet implemented/accepted: **20 / 58 = 34%**

Do not convert the 25 implemented items to `[x]` until their required acceptance evidence exists.

---

# Deferred final release gate — GitHub Actions

Issue: **#91 — Restore GitHub Actions execution and reduce hosted-runner spend**

Owner decision on 2026-08-21: GitHub Actions billing remains intentionally off while engineering work continues. The recurring zero-job `BuildFailed` / `startup_failure` is therefore **not a reason to stop code completion** and must not trigger speculative payment-code changes.

Before merge/deploy/production activation, all of the following still become mandatory:

- [ ] GitHub Actions billing/runner admission intentionally restored.
- [ ] Synthetic `BuildFailed` is gone.
- [ ] PR run has a real workflow name.
- [ ] At least one GitHub Actions job is created.
- [ ] `Quality` runs on PR #88.
- [ ] `Financial Safety` runs on PR #88.
- [ ] `Callable Safety` runs on PR #88.
- [ ] Functions syntax/lint/unit tests pass.
- [ ] Flutter analyze/tests pass.
- [ ] Successful run IDs are recorded in the detailed payments tracker.

When billing is restored, verify payment method, Actions budget/quota and any hard stop before troubleshooting workflow YAML.

---

# P2 — Dispatch subscriptions acceptance checklist

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
- [x] Current Apple/Google external-purchase rules reviewed; initial hosted Stripe purchase/Portal surface is restricted to web, while native builds keep existing membership access but do not expose Stripe purchase or management controls.

## Implemented in PR #88 — acceptance still required

- [ ] Firestore checkout reservation/lease prevents concurrent duplicate creation.
- [ ] Stable attempt-number Stripe idempotency key.
- [ ] Same-plan open Checkout Session reuse.
- [ ] Different-plan overlapping checkout fails closed.
- [ ] Current paid membership blocks another checkout.
- [ ] Existing nonterminal Stripe subscription blocks another checkout even before entitlement exists.
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
- [ ] `/payments/dispatch` route exists.
- [ ] `/payments/success` route exists.
- [ ] `/payments/cancel` route exists.
- [ ] Browser success redirect does not grant entitlement.
- [ ] VIP billing remains disabled while unapproved.
- [ ] Stale `$25/year + $10/job + NOT BILLING YET` onboarding block is removed and replaced by server-backed recurring pricing.
- [ ] Fail-closed Stripe Customer Portal callable/UI exists; it remains unavailable until an approved live Portal configuration is explicitly enabled.
- [ ] Native iOS/Android builds fail closed for hosted Stripe purchase and Portal controls; existing active membership remains usable.

## Still required / not accepted

- [ ] Read actual production `platform_configuration/payment_provider_readiness` values.
- [ ] Confirm `stripeSubscriptionsEnabled` intended production state.
- [ ] Confirm `stripeMode` intended production state.
- [ ] Confirm `stripeWebhookVerified` evidence.
- [ ] Confirm `stripeReconciliationReady` evidence.
- [ ] Confirm valid tax-ready or explicitly approved registration-pending state.
- [ ] Verify production success/cancel URLs resolve correctly after deploy.
- [ ] Functions full validation passes.
- [ ] Flutter full validation passes.
- [ ] Controlled duplicate-click/retry creates exactly one active Stripe attempt.
- [ ] Controlled paid monthly invoice creates exactly one correct membership.
- [ ] Controlled paid yearly invoice creates exactly one correct membership.
- [ ] Renewal extends membership exactly once.
- [ ] Failed-renewal acceptance preserves access only through paid-through.
- [ ] Cancellation/end-of-period signed-event acceptance passes.
- [ ] Deploy new webhook handler, then synchronize live endpoint to the authoritative event catalog including `invoice.payment_failed` and subscription create/update/delete/pause/resume.
- [ ] Create/approve the live Stripe Customer Portal configuration and enable its `bpc_…` ID/return URL only after Portal behavior is reviewed.
- [ ] 1-year free entitlement acceptance passes.
- [ ] 5-year free entitlement acceptance passes.
- [ ] 100%-discount invoice creates no false revenue/affiliate commission.
- [ ] Controlled colleague acceptance passes.
- [ ] Stripe invoice/payment reconciles to Pipe Buyer state/ledger.

P2 definition of done: a carrier can choose the approved Monthly or Yearly plan on the approved purchase surface, complete secure provider checkout, receive exactly one provider-confirmed paid entitlement, renew/cancel safely, lose bidding access after paid-through expires, and the resulting money/state reconciles.

---

# Current next actions

Execute in this order unless new evidence changes the dependency chain:

1. [ ] Continue PR #88 code completion and targeted static review while hosted Actions billing remains off.
2. [x] Define the authoritative Stripe webhook event catalog, including failed invoice and subscription create/update/delete/pause/resume events.
3. [x] Repair webhook bootstrap so an existing endpoint synchronizes the authoritative event catalog while disabled before deployment.
4. [x] Define Customer Portal policy: payment-method update ON, cancel at period end ON, plan switching OFF; keep live Portal disabled until reviewed/configured.
5. [x] Review current Apple/Google external-purchase rules and define the initial hosted Stripe launch surface as web-only.
6. [x] Create controlled provider acceptance matrix in `docs/DISPATCH_STRIPE_ACCEPTANCE_MATRIX.md`.
7. [ ] Resolve remaining affiliate-economics fail-closed behavior before any future payout activation.
8. [ ] Read/verify live Firebase payment-readiness values and return URLs before any activation.
9. [ ] Restore GitHub Actions billing only when the branch is otherwise ready for final validation.
10. [ ] Run PR #88 `Quality`, `Financial Safety`, and `Callable Safety`; fix only evidence-backed failures.
11. [ ] Deploy to the controlled acceptance environment and run Stripe provider tests.
12. [ ] Synchronize live Stripe webhook event subscriptions only after deployed handler acceptance.
13. [ ] Reconcile test invoice/payment state and complete colleague acceptance.
14. [ ] Only after all P2 gates pass, decide whether Dispatch subscription checkout may be enabled for the approved web launch surface.

---

# Change log

## 2026-08-21

- [x] Created percentage-based scorecard and acceptance formula.
- [x] Reclassified GitHub Actions as an intentionally deferred final release gate while billing is off.
- [x] Replaced stale Dispatch pilot pricing with server-backed subscription pricing.
- [x] Removed hard-coded price duplication from the dedicated Dispatch membership page.
- [x] Added fail-closed Stripe Customer Portal code path and provider-configuration verification; live Portal remains disabled because no active configuration exists.
- [x] Added explicit subscription pause/resume lifecycle handling.
- [x] Added authoritative Stripe webhook event catalog and invariant tests.
- [x] Repaired production webhook bootstrap so existing endpoints synchronize the repo-owned event catalog while disabled before handler deployment and are re-verified after enable.
- [x] Added `docs/DISPATCH_STRIPE_ACCEPTANCE_MATRIX.md` with provider/Firestore/reconciliation pass criteria.
- [x] Reviewed current Apple/Google purchase rules and restricted hosted Stripe Checkout/Portal controls to web builds for the initial North American release.
- [x] Current score: overall verified payments checklist **32%**; Dispatch P2 verified **22%**; Dispatch P2 verified + implemented coverage **66%**.
