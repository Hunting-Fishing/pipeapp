# Pipe Buyer — Payments Progress Scorecard

Status: active  
Started: 2026-08-21  
Last updated: 2026-08-21  
Detailed engineering/evidence log: `docs/PAYMENTS_EXECUTION_TRACKER.md`  
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
| P2 — Dispatch subscriptions | 12 | 56 | **21%** | **~63% implemented**, acceptance blocked by CI |
| P3 — External-settlement Marketplace fee | 4 | 15 | **27%** | Second revenue target; not active |
| P4 — Full Marketplace Checkout / Connect | 7 | 19 | **37%** | Gated; do not activate |
| P5 — Tax readiness | 0 | 12 | **0%** | Launch gate |
| P6 — Refunds/disputes/seller recovery | 2 | 11 | **18%** | Foundation exists; acceptance pending |
| P7 — Reconciliation/accounting | 0 | 17 | **0%** | Operational completion required |
| **TOTAL** | **54** | **170** | **32%** | Overall verified payments checklist |

> **Important:** 32% is checklist completion, not commercial launch readiness. Dispatch P2 is the current revenue target and its critical path is much further along in code than its 21% verified acceptance score.

## P2 engineering implementation view

Current P2 scope: **56 acceptance items**.

- Verified complete: **12 / 56 = 21%**
- Additional items implemented in Draft PR #88 but awaiting CI/provider acceptance: **23**
- Verified + implemented coverage: **35 / 56 = 63%**
- Not yet implemented/accepted: **21 / 56 = 38%**

Do not convert the 23 implemented items to `[x]` until their required acceptance evidence exists.

---

# P0 release blocker — GitHub Actions

Issue: **#91 — Restore GitHub Actions execution and reduce hosted-runner spend**

Current symptom:

- [ ] Synthetic `BuildFailed` is gone.
- [ ] PR run has a real workflow name.
- [ ] At least one GitHub Actions job is created.
- [ ] `Quality` runs on PR #88.
- [ ] `Financial Safety` runs on PR #88.
- [ ] `Callable Safety` runs on PR #88.
- [ ] Functions syntax/lint/unit tests pass.
- [ ] Flutter analyze/tests pass.
- [ ] Successful run IDs are recorded in the detailed payments tracker.

Current diagnosis: GitHub-hosted Actions admission/billing/quota restriction is the primary suspected root cause. Do **not** modify payment code to chase a zero-job `startup_failure`.

Account-owner verification required in GitHub billing settings:

- [ ] Valid GitHub payment method confirmed.
- [ ] Actions metered usage/included quota reviewed.
- [ ] Actions budget is not zero/exhausted.
- [ ] Hard `Stop usage when budget limit is reached` restriction is not blocking runs.
- [ ] Failed-payment/account billing warning is cleared if present.

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
- [ ] Subscription created/updated/deleted lifecycle is modeled.
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
- [ ] Expand live webhook to `invoice.payment_failed` only after code deploy/test.
- [ ] Expand live webhook to required subscription lifecycle events only after code deploy/test.
- [ ] Decide/implement Customer Portal or equivalent subscription self-service.
- [ ] 1-year free entitlement acceptance passes.
- [ ] 5-year free entitlement acceptance passes.
- [ ] 100%-discount invoice creates no false revenue/affiliate commission.
- [ ] Controlled colleague acceptance passes.
- [ ] Stripe invoice/payment reconciles to Pipe Buyer state/ledger.
- [ ] Current Apple App Store/Google Play policy review completed before public native-store external Stripe exposure.

P2 definition of done: a carrier can choose the approved Monthly or Yearly plan, complete secure provider checkout, receive exactly one provider-confirmed paid entitlement, renew/cancel safely, lose bidding access after paid-through expires, and the resulting money/state reconciles.

---

# Current next actions

Execute in this order unless new evidence changes the dependency chain:

1. [ ] **Restore GitHub Actions execution — Issue #91.**
2. [ ] Run PR #88 `Quality`, `Financial Safety`, and `Callable Safety`.
3. [ ] Fix only evidence-backed failures from those runs.
4. [ ] Verify live Firebase payment readiness values and return URLs.
5. [ ] Controlled Stripe duplicate-checkout test.
6. [ ] Controlled Monthly/Yearly paid entitlement tests.
7. [ ] Renewal/failure/cancellation acceptance.
8. [ ] Expand live Stripe webhook event subscriptions only after deployed handler acceptance.
9. [ ] Decide Customer Portal behavior and cancellation policy.
10. [ ] Free-coupon/zero-dollar revenue tests.
11. [ ] Reconciliation and colleague acceptance.
12. [ ] Only after P2 gates pass, decide whether Dispatch subscription checkout may be enabled for the controlled launch surface.

---

# Change log

## 2026-08-21

- [x] Created percentage-based scorecard.
- [x] Established verified-completion formula.
- [x] Established separate implemented-vs-accepted accounting.
- [x] Recorded GitHub Actions Issue #91 as P0 release blocker.
- [x] Recorded current overall verified checklist at **32%**.
- [x] Recorded Dispatch P2 verified acceptance at **21%**.
- [x] Recorded Dispatch P2 engineering implementation coverage at approximately **63%**.
- [x] Replaced stale Dispatch pilot pricing block in PR #88 with server-backed subscription pricing component at code level; acceptance remains unchecked above.
