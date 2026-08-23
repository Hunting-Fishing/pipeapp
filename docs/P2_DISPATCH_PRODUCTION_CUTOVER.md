# P2 Dispatch subscription production cutover

Date prepared: 2026-08-23  
Owner: Pipe Buyer financial/admin operations  
Scope: Pipe Buyer Dispatch — CAD 25/month and CAD 300/year recurring subscriptions

This checklist is the release boundary for P2. Do not mark Dispatch subscriptions financially production-ready because code, a Stripe Product/Price, a Checkout Session, webhook handler, build flag, or `bpc_...` identifier exists. Completion requires repository acceptance, an accepted deployed artifact, provider lifecycle evidence, Firestore state, reconciliation, and operator review to agree.

## Current deliberate state

- Public Dispatch subscription activation: **OFF**
- Dedicated admin route: **registered at `/admin/dispatch-billing`**
- Dispatch Billing Operations controls: **implemented on branch; exact artifact acceptance/deploy still pending**
- Unified eight-prerequisite launch-readiness snapshot: **implemented**
- Production client build approvals: **Dispatch and Paid Features default OFF until explicitly approved**
- LIVE Stripe Billing Portal config: **exists** — `bpc_1U7aEmDkO07WMXyRjjSqn4SF`
- LIVE Portal payment methods/customer info/invoices/cancel-at-period-end: **configured**
- LIVE Portal Monthly ↔ Yearly switching: **still OFF until the final Dashboard change below**
- Pipe Buyer Portal provider proof under v2 switching policy: **not yet recorded**
- Subscription recovery verification: **not recorded yet**
- Subscription lifecycle webhook verification: **must be provider-verified after receiver deployment/event expansion**
- Controlled Monthly payment: **not run**
- Controlled Yearly payment: **not run**
- Live BALANCED reconciliation: **not proven**
- Legacy direct-write live-billing activation workflows: **retired**

## Canonical LIVE Stripe catalog

One Product owns both Dispatch billing intervals:

- Product: `prod_V2WkE5D16GhGaD` — **Pipe Buyer Dispatch**
- Monthly: `price_1U2SYGDkO07WMXyRm6xbprUn` — CAD 25/month
- Yearly: `price_1U7bTCDkO07WMXyRvLkWVHHu` — CAD 300/year

Legacy yearly Product `prod_V2WsPl25y7Qe6A` is inactive and retained only for historical/audit evidence. Its old default Price `price_1U2XDVDkO07WMXyRS0eCYKCh` must not be used for new Checkout.

Provider reads before consolidation confirmed zero subscriptions on both original Dispatch prices, so no subscriber migration was required.

## Financial policy revisions for this cutover

- Billing Portal provider policy: `2026-08-23-p2-v2-dispatch-plan-switching`
- Subscription catalog/Price→plan policy: `2026-08-23-p2-v1-provider-price-plan`
- Invoice reconciliation: `2026-08-23-p2-v3-provider-price-plan`

Current subscription plan authority is the current provider Subscription Price. Invoice financial plan authority is the Price actually billed on the provider Invoice. `metadata.dispatchPlan` is Checkout-time audit context only and must never be treated as current plan authority after a Portal switch.

## Gate 1 — repository and emulator acceptance

Do not continue to production activation until the exact final P2 commit passes from a complete checkout.

- [ ] `tool/verify.ps1` passes.
- [ ] Flutter analyzer passes.
- [ ] Flutter tests pass.
- [ ] Functions `npm run check` passes.
- [ ] Firestore rules tests pass.
- [ ] callable/Auth/Firestore/Functions emulator acceptance passes.
- [ ] Dispatch subscription catalog/Price→plan tests pass.
- [ ] Dispatch subscription lifecycle tests pass.
- [ ] Dispatch reconciliation tests pass.
- [ ] Billing Portal provider-verification/runtime-drift tests pass.
- [ ] customer-reuse/duplicate-Checkout tests pass.
- [ ] centralized eight-gate readiness tests pass.
- [ ] production feature-build approval/release-manifest tests pass.
- [ ] no client can directly mutate authoritative Dispatch subscription/payment/reconciliation/readiness records.

Record:

`P2_ACCEPTED_SHA = ________________________________`

Known infrastructure note: GitHub-hosted Actions has an independently tracked startup failure where jobs can be created without steps/logs. Do not change payment code to chase that runner failure. Use exact-commit local/complete repository acceptance before merge.

## Gate 2 — merge and deploy the exact accepted receiver/client artifact

- [ ] accepted P2 stack is merged to intended release history.
- [ ] deploy exact accepted `main` commit.
- [ ] explicitly build with Dispatch + Paid Features approvals ON for the controlled artifact.
- [ ] release manifest records exact commit, artifact hash, and both build approvals.
- [ ] remote runtime `dispatch` and `paidFeatures` remain controlled separately.
- [ ] `stripeMarketplaceWebhook` includes Dispatch lifecycle receiver.
- [ ] `createDispatchSubscriptionCheckout` includes stable idempotency and Stripe Customer reuse.
- [ ] `createDispatchBillingPortalSession` includes exact provider-Portal runtime re-verification.
- [ ] `verifyDispatchBillingPortalConfiguration` is deployed with v2 switching policy.
- [ ] `verifyDispatchSubscriptionLifecycleWebhook` is deployed.
- [ ] Dispatch reconciliation callables are deployed with v3 provider Price evidence.
- [ ] production-readiness audit includes exact Portal customer fields/product/prices and lifecycle-event checks.

Production workflow inputs for the accepted client artifact:

```text
enable_dispatch = true
enable_paid_features = true
```

These build approvals do not activate public billing.

Record:

`P2_DEPLOYED_SHA = ________________________________`

`P2_WEB_ARTIFACT_SHA256 = ________________________________`

## Gate 3 — finalize and provider-verify the LIVE Billing Portal

Current LIVE config:

`STRIPE_DISPATCH_PORTAL_CONFIGURATION = bpc_1U7aEmDkO07WMXyRjjSqn4SF`

Required exact behavior:

- [x] payment-method updates ON.
- [x] customer information updates ON.
- [x] customer fields limited to Name, Email, Billing address, Phone, Tax ID.
- [x] Shipping address editing OFF.
- [x] invoice history ON.
- [x] cancellation ON.
- [x] cancellation mode `at_period_end`.
- [x] cancellation proration `none`.
- [ ] **Customers can switch plans ON.**
- [ ] allowed subscription update field is **Price only**.
- [ ] **Customers can change quantity OFF.**
- [ ] exactly one eligible Product: `prod_V2WkE5D16GhGaD`.
- [ ] exactly two eligible Prices: Monthly `price_1U2SYGDkO07WMXyRm6xbprUn` and Yearly `price_1U7bTCDkO07WMXyRvLkWVHHu`.
- [ ] plan-change proration `none`.
- [x] Portal header/return/legal-policy/customer-facing business information reviewed.

Why switching is now allowed: Pipe Buyer no longer trusts stale `metadata.dispatchPlan`. `customer.subscription.updated` re-reads the current Subscription and maps the exact provider Price to Monthly/Yearly. Unknown Price, quantity change, extra item, or conflicting product fails closed and removes entitlement pending review. Invoice accounting independently derives the plan from the provider Invoice Price.

After the Dashboard save, use `/admin/dispatch-billing` → **Verify & enable Billing Portal**. The server must re-read the exact live `bpc_...` and prove all of the above. `setDispatchBillingPortalReadiness` is revoke/disable-only; it is not an enable bypass.

- [ ] stored proof records provider policy `2026-08-23-p2-v2-dispatch-plan-switching`.
- [ ] stored proof is bound to exact `bpc_...`, Product, Prices, customer fields, price-only update field, and proration policy.
- [ ] live runtime re-read passes immediately before Checkout/Manage Billing.

## Gate 4 — verify Stripe Billing recovery settings

Review in LIVE Stripe Dashboard; do not infer from code.

- [ ] Smart Retries / automatic retry policy reviewed and enabled as intended.
- [ ] failed-payment customer emails enabled.
- [ ] renewal/invoice emails reviewed.
- [ ] payment-method recovery directs customers to reviewed Portal.
- [ ] terminal state after retries agrees with Pipe Buyer entitlement policy.
- [ ] record `stripeSubscriptionRecoveryVerified == true` only after review.

## Gate 5 — deploy, add, and provider-verify subscription lifecycle events

Only after the receiver from Gate 2 is deployed, ensure the live endpoint receives:

- [ ] `invoice.paid`
- [ ] `invoice.payment_failed`
- [ ] `customer.subscription.updated`
- [ ] `customer.subscription.deleted`

Then:

- [ ] endpoint remains live/enabled.
- [ ] signing secret remains valid.
- [ ] `verifyDispatchSubscriptionLifecycleWebhook` reports no missing events.
- [ ] `stripeSubscriptionLifecycleWebhookVerified == true` is provider-authored by the verifier.
- [ ] controlled receiver failure is retryable and not silently marked processed.

## Gate 6 — verify all eight stored launch prerequisites while activation remains OFF

For the controlled acceptance artifact, enable runtime flags:

```text
dispatch = true
paidFeatures = true
```

Verify:

- [ ] Dispatch + paidFeatures runtime flags ready.
- [ ] Stripe mode production.
- [ ] exact v2 Billing Portal provider proof ready.
- [ ] core signed webhook verified.
- [ ] subscription lifecycle webhook verified.
- [ ] recovery policy reviewed/recorded.
- [ ] reconciliation readiness true.
- [ ] current authorized GST/HST billing evidence ready.

Expected before activation:

```text
readyCount = 8
prerequisiteCount = 8
prerequisitesReady = true
subscriptionsEnabled = false
publicBillingAvailable = false
```

## Gate 7 — controlled live Monthly acceptance

Open a narrow audited activation window only after Gate 6 is 8/8.

- [ ] enable `stripeSubscriptionsEnabled` through audited readiness control.
- [ ] eligible account reports `billingAvailable = true` and `canStartCheckout = true`.
- [ ] start Monthly Checkout from Pipe Buyer UI.
- [ ] amount is CAD 25/month before applicable tax.
- [ ] first subscription creates one Stripe Customer.
- [ ] repeat tap/retry reuses one logical Checkout attempt.
- [ ] complete approved controlled payment.
- [ ] browser return alone does not grant entitlement.
- [ ] signed webhook/provider state grants entitlement.
- [ ] Firestore current plan resolves from Monthly Price.
- [ ] no duplicate subscription/customer is created.

Record:

`MONTHLY_SUBSCRIPTION_ID = ________________________________`

`MONTHLY_INVOICE_ID = in_______________________________`

## Gate 8 — Monthly provider-backed reconciliation

Reconcile:

**Invoice → paid InvoicePayment → PaymentIntent → Charge → Balance Transaction**

Require:

- [ ] provider Invoice identifies Monthly Price `price_1U2SYGDkO07WMXyRm6xbprUn`.
- [ ] stored plan/Price match provider Invoice Price.
- [ ] amount/currency/tax/commission-base match.
- [ ] exactly one paid InvoicePayment for positive automatic invoice.
- [ ] PaymentIntent succeeded.
- [ ] Charge and Balance Transaction link exactly.
- [ ] `gross - Stripe fee = net`.
- [ ] reconciliation **BALANCED**.
- [ ] invoice difference `0`.
- [ ] provider difference `0`.

## Gate 9 — failure and recovery lifecycle

- [ ] `invoice.payment_failed` sets payment-issue state.
- [ ] `past_due` follows approved temporary-entitlement policy.
- [ ] successful recovery clears issue.
- [ ] terminal `unpaid` removes entitlement.
- [ ] stale/out-of-order updates cannot roll state backward.

## Gate 10 — Billing Portal switching, cancellation, and replacement

- [ ] active subscriber opens only Stripe-hosted Portal from Pipe Buyer.
- [ ] session uses exact provider-verified `bpc_...`.
- [ ] runtime re-read passes immediately before opening Portal.
- [ ] Monthly → Yearly switch is offered.
- [ ] Yearly → Monthly switch is offered.
- [ ] quantity edit is not offered.
- [ ] no other Product/Price is offered.
- [ ] after a switch, `customer.subscription.updated` re-reads provider Subscription.
- [ ] Pipe Buyer `plan` follows current Stripe Price even if metadata still contains original plan.
- [ ] unauthorized Price/quantity drift fails closed to review.
- [ ] cancel-at-period-end lifecycle remains correct.
- [ ] terminal cancellation removes entitlement.
- [ ] later replacement Checkout reuses the same stored Stripe Customer ID.
- [ ] retired subscription IDs remain protected from late event overwrite.

## Gate 11 — controlled live Yearly acceptance

- [ ] Yearly Checkout uses `price_1U7bTCDkO07WMXyRvLkWVHHu` under canonical Product.
- [ ] displayed amount is CAD 300/year before applicable tax.
- [ ] existing Stripe Customer is reused when applicable.
- [ ] only one logical Checkout/subscription is produced.
- [ ] provider Invoice ledger records Yearly from invoice Price, not stale metadata.
- [ ] provider-backed reconciliation is BALANCED with zero differences.

Record:

`YEARLY_SUBSCRIPTION_ID = ________________________________`

`YEARLY_INVOICE_ID = in__________________________________`

## Gate 12 — 100% promotional invoice acceptance

For a legitimate approved free promotion:

- [ ] provider invoice Price still maps to reviewed Dispatch interval.
- [ ] amount paid = 0.
- [ ] no paid InvoicePayment exists.
- [ ] no PaymentIntent/Charge/Balance Transaction is invented.
- [ ] provider gross/fee/net = 0.
- [ ] affiliate commission = 0.
- [ ] reconciliation is BALANCED only when zero-dollar provider evidence is exact.

## Gate 13 — operator and visual acceptance

- [ ] Monthly purchase UX clear on mobile/web.
- [ ] Yearly purchase UX clear on mobile/web.
- [ ] billing OFF state does not present false purchase action.
- [ ] open Checkout/processing states do not create duplicates.
- [ ] payment issue language is understandable.
- [ ] Manage Billing is simple for non-technical customers.
- [ ] Portal switching clearly shows Monthly/Yearly and no quantity control.
- [ ] admin can see all eight gates, provider Portal proof, and BALANCED/MISMATCH evidence.
- [ ] colleague soft-launch review signed off.

## Gate 14 — final public activation

Only after every prior gate is recorded:

- [ ] exact deployed release manifest matches accepted SHA/artifact.
- [ ] runtime feature flags remain intended.
- [ ] launch-readiness remains 8/8.
- [ ] exact v2 Portal proof current.
- [ ] lifecycle webhook proof current.
- [ ] recovery review current.
- [ ] Monthly and Yearly controlled provider evidence exists.
- [ ] Monthly and Yearly reconciliation BALANCED with zero differences.
- [ ] Monthly ↔ Yearly provider Price synchronization proven.
- [ ] no unresolved duplicate/catalog/review state exists.
- [ ] deliberately enable `stripeSubscriptionsEnabled` for public production through audited readiness control.
- [ ] activation reason/admin identity recorded.

## Emergency rollback

If any financial acceptance fails:

1. disable `stripeSubscriptionsEnabled` through audited readiness control;
2. set runtime `paidFeatures` and/or `dispatch` false if new customer access must stop immediately;
3. disable Portal readiness if its provider configuration is no longer trusted;
4. revoke recovery/lifecycle readiness when their provider evidence is no longer trusted;
5. preserve Stripe/Firestore/webhook/reconciliation evidence;
6. identify root cause before changing code;
7. record the exact repair in `docs/repairs/`;
8. rerun the failed and adjacent financial gates before reactivation.

Never fix reconciliation by editing Firestore merely to make numbers agree. Provider evidence and application records must reconcile through the server-authoritative repair path.
