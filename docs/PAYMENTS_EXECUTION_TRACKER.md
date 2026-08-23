# Pipe Buyer — Payments Execution Tracker

Status: active workstream  
Started: 2026-08-21  
Owner: Pipe Buyer engineering  
Purpose: permanent checklist for checkout, payments, revenue collection, tax gates, refunds/disputes, and reconciliation.

## Operating rule

Do not mark a financial item complete because a screen or Stripe object exists. Completion requires the UI, server-authoritative calculation, provider object, webhook result, Firestore ledger/state, error handling, reconciliation, and acceptance test to agree.

When repairing a payment defect, record the root cause, exact repair, verification test, and commit/PR. Do not repeat prior speculative repairs after root cause is known.

---

# Current verified baseline — 2026-08-21

## P0 — Financial truth

- [x] Server fee policy is versioned as `2026-08-10-launch-v2`.
- [x] Pipe/tubing/casing seller fee is server-authoritative: CAD/USD $1 per stick/joint, $25 minimum, $5,000 maximum.
- [x] Equipment/assets seller fee is server-authoritative: $25 minimum; 5% under $10k, 3% $10k–$49,999.99, 2% $50k–$249,999.99, 1% $250k+.
- [x] Accepted transaction fee snapshots are designed to be immutable.
- [x] Current main server policy still specifies `affiliateShareBps: 2000` (20%).
- [ ] Reconcile older monetization documentation with current launch-v2 server policy.
- [ ] Resolve open affiliate economics proposal before enabling affiliate payouts.
- [ ] Confirm every checkout/admin/user-facing fee display matches server policy.

## Live Stripe products/prices

- [x] Live Pipe Buyer Stripe account identified.
- [x] Stripe account can accept charges.
- [x] Stripe account payouts are enabled.
- [x] Stripe `transfers` capability is active.
- [x] Stripe currently reports no outstanding account requirements.
- [x] Dispatch Monthly CAD recurring price exists: CA$25/month.
- [x] Dispatch Yearly CAD recurring price exists: CA$300/year.
- [x] Pipe Marketplace Fee product exists with launch-v2 metadata.
- [x] Equipment & Assets Marketplace Fee product exists.
- [x] 1-year free Dispatch coupon exists and is valid.
- [x] 5-year free Dispatch coupon exists and is valid.
- [x] Live Stripe account currently has no Checkout Sessions or subscriptions, providing a clean pre-revenue audit baseline.
- [x] Live Stripe balance was zero at the audit checkpoint.
- [x] Stripe Tax currently has no active registrations at the audit checkpoint.
- [ ] Review/deactivate only after dependency audit: legacy CA$25 one-time Dispatch price.
- [ ] Review/deactivate only after dependency audit: legacy CA$300 one-time Dispatch price.
- [ ] Review/deactivate only after dependency audit: separate active US$25/month Dispatch product/price.

Important: do not delete/deactivate legacy Stripe objects until Firebase, old releases, links, and historical records are checked for dependencies.

## P1 — Stripe/webhook integrity

- [x] Production webhook endpoint exists in live mode.
- [x] Endpoint is enabled.
- [x] Endpoint URL targets deployed `stripeMarketplaceWebhook` Cloud Function.
- [x] Enabled event list matches current checkout/subscription/refund/dispute handler coverage.
- [x] Firebase handler verifies Stripe signature against raw request body.
- [x] Signature timestamp tolerance is enforced.
- [x] Webhook event IDs are recorded in `stripe_webhook_events`.
- [x] Already-processed events return safely without running money movement again.
- [x] Failed webhook processing is recorded and returns non-2xx so Stripe can retry.
- [x] Seller Transfers use a stable transaction idempotency key.
- [ ] Verify production `STRIPE_WEBHOOK_SECRET` deployment without exposing secret value.
- [ ] Verify production `STRIPE_SECRET_KEY` deployment without exposing secret value.
- [ ] Run controlled duplicate-event acceptance test.
- [ ] Run out-of-order event acceptance test.
- [ ] Verify failed-event operational alert/review path.

---

# P2 — Dispatch subscriptions — FIRST REVENUE TARGET

## Server checkout — verified baseline on `main`

- [x] Authenticated Firebase command exists.
- [x] Paid-feature and Dispatch feature gates are enforced.
- [x] Checkout uses server-configured Stripe Price IDs.
- [x] Client cannot supply authoritative subscription amount.
- [x] Monthly maps to intended recurring CAD price.
- [x] Yearly maps to intended recurring CAD price.
- [x] Checkout uses Stripe `mode=subscription`.
- [x] Billing address collection is required.
- [x] Promotion coupons are chosen from server-owned entitlement records.
- [x] Affiliate relationship metadata is server-read.
- [x] Checkout session is persisted in Firestore.
- [x] Checkout is fail-closed unless subscription, mode, webhook, reconciliation, and tax readiness gates pass.

## Draft PR #88 — implemented, not yet accepted/merged

The following items exist on `fix/dispatch-checkout-hardening`, but remain unchecked until automated and controlled acceptance evidence is available:

- [ ] Duplicate-safe checkout creation: Firestore reservation/lease plus stable server attempt idempotency key.
- [ ] Same-plan open Checkout Session reuse.
- [ ] Active paid membership prevents creation of another Dispatch subscription Checkout Session.
- [ ] Verified `invoice.paid` creates/extends server-owned `dispatch_memberships/{uid}` entitlement.
- [ ] Membership extension never shortens an existing paid-through date.
- [ ] Private authenticated `getDispatchSubscriptionStatus` callable.
- [ ] Dedicated Dispatch Monthly/Yearly payment screen.
- [ ] UI shows CA$25/month and CA$300/year.
- [ ] Existing memberships dialog links Dispatch plans into the secure payment flow.
- [ ] VIP billing remains disabled while VIP pricing/economics are unapproved.
- [ ] `/payments/dispatch` route registered.
- [ ] `/payments/success` route registered.
- [ ] `/payments/cancel` route registered.
- [ ] Success return explicitly does not grant membership from browser redirect.
- [ ] Cancel return explicitly does not mark membership paid.
- [ ] Node unit coverage added for checkout idempotency/membership period/status helpers.
- [ ] Flutter coverage added for payment-return messaging and membership formatting helpers.

## Remaining Dispatch subscription work

- [ ] Read current production `platform_configuration/payment_provider_readiness` values.
- [ ] Confirm `stripeSubscriptionsEnabled` intended state.
- [ ] Confirm `stripeMode` intended state.
- [ ] Confirm `stripeWebhookVerified` evidence.
- [ ] Confirm `stripeReconciliationReady` evidence.
- [ ] Confirm tax state is either valid ready or explicitly approved registration-pending mode.
- [ ] Verify configured success/cancel URLs resolve to the PR #88 Pipe Buyer routes after deployment.
- [ ] Run Functions syntax/lint/unit suite against PR #88.
- [ ] Run Flutter analyze/test suite against PR #88.
- [ ] Run duplicate-click/retry acceptance and prove only one active provider Checkout attempt is created.
- [ ] Run controlled `invoice.paid` acceptance and prove one correct paid-through entitlement.
- [ ] Verify renewal extends membership once and never shortens the prior period.
- [ ] Add/verify `invoice.payment_failed` operational behavior.
- [ ] Add/verify subscription cancellation/end-of-period lifecycle behavior.
- [ ] Decide and implement Stripe Customer Portal or equivalent self-service subscription management.
- [ ] Verify 1-year-free entitlement.
- [ ] Verify 5-year-free entitlement.
- [ ] Verify a 100%-discount invoice creates no false revenue/commission.
- [ ] Run colleague acceptance test in controlled environment.
- [ ] Reconcile resulting Stripe invoice/payment to Pipe Buyer ledger/state.
- [ ] Review Apple App Store / Google Play billing rules before exposing external Stripe purchase of digital Dispatch access in public native-store builds.

P2 definition of done: a user can choose Monthly or Yearly, complete secure Stripe Checkout, Pipe Buyer records exactly one valid subscription entitlement after provider evidence, renewal/cancellation work, and revenue reconciles.

---

# P3 — External-settlement Marketplace fee — SECOND REVENUE TARGET

- [x] Architecture exists for buyer/seller settling industrial sale outside Stripe.
- [x] Pipe Buyer can bill only its Marketplace fee.
- [x] Fee-only webhook verifies checkout subtotal against immutable fee snapshot.
- [x] No seller-proceeds Transfer is created in fee-only settlement.
- [ ] Verify both-party external settlement confirmation gate end to end.
- [ ] Verify one-party-only confirmation cannot start fee checkout.
- [ ] Verify server-generated fee-only Checkout amount.
- [ ] Verify tax handling for Pipe Buyer fee.
- [ ] Verify successful fee collection state.
- [ ] Verify failed fee collection state.
- [ ] Verify duplicate Checkout prevention.
- [ ] Verify duplicate webhook prevention.
- [ ] Verify fee receipt/invoice UX.
- [ ] Verify admin unpaid/paid/review states.
- [ ] Reconcile controlled test payment.

---

# P4 — Full Marketplace Checkout / Stripe Connect — GATED

Do not activate this merely because code exists.

- [x] Separate Charges and Transfers foundation exists.
- [x] Seller payout account is checked before Transfer.
- [x] Seller payout holds are respected.
- [x] PaymentIntent must be `succeeded` before Transfer.
- [x] Seller transfer uses `source_transaction`.
- [x] Seller transfer is idempotent by Pipe Buyer transaction ID.
- [x] Checkout subtotal is checked against immutable sale snapshot.
- [ ] Confirm Connect platform profile and accepted loss-liability responsibilities.
- [ ] Confirm Radar for Platforms/risk strategy.
- [ ] Confirm current connected-account onboarding model matches current Stripe guidance.
- [ ] Test Canadian individual seller.
- [ ] Test Canadian business seller.
- [ ] Test supported US seller configuration.
- [ ] Test missing/restricted transfer capability.
- [ ] Test card success/decline.
- [ ] Test delayed bank success/failure.
- [ ] Prove no seller Transfer occurs before final provider success.
- [ ] Prove seller Transfer occurs exactly once.
- [ ] Prove every cent reconciles.

---

# P5 — Tax readiness — LAUNCH GATE

- [ ] Confirm legal billing entity.
- [ ] Confirm GST/HST registrations/effective dates.
- [ ] Confirm BC PST treatment.
- [ ] Confirm seller registered/non-registered treatment.
- [ ] Confirm tax liability for Dispatch subscription flow.
- [ ] Confirm tax liability for fee-only Marketplace flow.
- [ ] Confirm tax liability for full on-platform Marketplace flow.
- [ ] Confirm Stripe Tax registrations match actual government registrations.
- [ ] Confirm physical listing tax-code strategy.
- [ ] Confirm exemption workflow.
- [ ] Confirm refund/tax reversal process.
- [ ] Confirm accounting/remittance owner.

Never set `stripeTaxReady=true` solely because Stripe Tax is enabled in the Dashboard.

---

# P6 — Refunds / disputes / seller recovery

- [x] Refund/dispute/seller-recovery foundation exists.
- [x] Webhook subscribes to refund and dispute lifecycle events.
- [ ] Full refund acceptance test.
- [ ] Partial refund acceptance test.
- [ ] Duplicate refund idempotency test.
- [ ] Failed refund recovery test.
- [ ] Dashboard/manual refund reconciliation test.
- [ ] Dispute created/updated/closed tests.
- [ ] Funds-withdrawn/reinstated tests.
- [ ] Seller recovery accounting test.
- [ ] Admin evidence/operations drill.

---

# P7 — Reconciliation / accounting

- [ ] Verify stored Checkout Session ID.
- [ ] Verify stored PaymentIntent ID.
- [ ] Verify stored Charge ID.
- [ ] Add/verify Balance Transaction ID capture where required for actual Stripe fee reconciliation.
- [ ] Verify gross amount.
- [ ] Verify tax.
- [ ] Verify Pipe Buyer revenue.
- [ ] Verify seller proceeds.
- [ ] Verify Transfer ID.
- [ ] Verify refund IDs.
- [ ] Verify dispute IDs.
- [ ] Verify currency.
- [ ] Verify fee-policy revision.
- [ ] Verify webhook event IDs.
- [ ] Build/verify daily reconciliation procedure.
- [ ] Build/verify exception queue.
- [ ] Provide accountant/bookkeeping export.

P7 definition of done: every Pipe Buyer dollar can be traced from business transaction -> Stripe object(s) -> Firestore ledger/state -> accounting/reconciliation with zero unexplained difference.

---

# Current execution order

1. [ ] Finish P0 documentation/UI/config reconciliation.
2. [ ] Finish P1 live readiness verification and controlled webhook tests.
3. [ ] Complete P2 Dispatch subscriptions and reconciliation.
4. [ ] Complete P3 external-settlement fee checkout.
5. [ ] Complete P5 tax gates for each flow before activating it.
6. [ ] Complete P6/P7 operational acceptance.
7. [ ] Only then activate P4 full Marketplace money movement.

---

# Findings / repair log

## 2026-08-21 — Live Stripe object audit

Observed: multiple active Dispatch prices/products exist, including intended recurring CAD monthly/yearly objects plus older one-time CAD prices and an active US$25/month legacy/international product.

Root cause: not yet classified; likely prior setup iterations. Do not assume these are safe to delete.

Repair/action: dependency audit first. Current Firebase `stripe_marketplace_config.js` explicitly uses the intended recurring CAD monthly/yearly Price IDs, so new Dispatch checkout is not selecting the one-time prices.

Verification: live Stripe products/prices compared against current `main` Firebase configuration.

Status: partially resolved; cleanup remains pending dependency confirmation.

## 2026-08-21 — Webhook baseline

Observed: production Stripe webhook is already live and enabled.

Verification: live Stripe endpoint event list matches Firebase webhook handler coverage for Checkout, subscription invoice paid, refunds, and disputes.

Status: architecture verified; secret deployment and controlled retry/duplicate acceptance still pending.

## 2026-08-21 — Dispatch Checkout duplicate-session defect

Observed: `createDispatchSubscriptionCheckout` used `Date.now()` inside the Stripe idempotency key. A retry or double-click therefore generated a new provider key and could create another Checkout Session.

Root cause: provider idempotency was tied to wall-clock time rather than a stable server-owned business attempt.

Repair: draft PR #88 adds `dispatch_subscription_checkout_state/{uid}`, a short creation lease, stable server attempt numbers, same-plan session reuse, and Stripe keys in the form `pipebuyer-dispatch-{uid}-attempt-{n}`. Interrupted requests can retry the same attempt instead of creating a new provider operation.

Verification added: unit tests for stable attempt keys, same-plan open-session reuse, and current-membership detection. Controlled Stripe acceptance remains required because repository CI currently cannot start jobs.

Status: repaired in draft; not marked complete until automated and provider acceptance pass.

## 2026-08-21 — Paid invoice did not activate Dispatch entitlement

Observed: current `main` `invoice.paid` processing persisted subscription invoice/revenue and affiliate ledger state, but did not create/extend a server-owned paid Dispatch membership.

Root cause: monetization accounting and Dispatch access entitlement were implemented on separate development paths; the entitlement primitive existed in older PR #76 but was not present in current `main` payment processing.

Repair: draft PR #88 selectively ports the `dispatch_memberships/{uid}` payment entitlement model without copying older Dispatch pages. A verified Dispatch `invoice.paid` now extends the provider-confirmed paid period and refuses to shorten an existing paid-through date.

Verification added: unit coverage for provider period extraction, current-membership rules, and expired status normalization. Controlled paid-invoice acceptance remains required.

Status: repaired in draft; not marked complete until acceptance passes.

## 2026-08-21 — Dispatch membership cards were placeholders

Observed: the existing Pipe Buyer memberships dialog displayed Dispatch Monthly/Yearly cards but its action only showed a snackbar and never called Stripe Checkout.

Root cause: design/UI was introduced before the gated provider checkout was ready to be exposed.

Repair: draft PR #88 adds a dedicated authenticated Dispatch payment page, uses the existing authenticated Firebase command, shows CA$25/month and CA$300/year, opens only an HTTPS Stripe-hosted Checkout URL returned by the server, and wires the existing Dispatch cards into that page. VIP billing remains disabled because VIP pricing is not approved.

Verification added: Flutter tests for payment-return semantics and status formatting. Full Flutter analyze/test and rendered acceptance remain required.

Status: repaired in draft; not marked complete until tests and controlled checkout pass.

## 2026-08-21 — Payment return routes missing

Observed: payment readiness configuration expects Pipe Buyer success/cancel destinations, but the app router did not register `/payments/success` or `/payments/cancel`.

Root cause: backend readiness URLs preceded explicit Flutter routes.

Repair: draft PR #88 registers `/payments/dispatch`, `/payments/success`, and `/payments/cancel`. The success page explicitly states that the redirect is not proof of payment and only signed provider webhook evidence grants paid membership.

Verification added: widget tests assert success/cancel pages do not falsely claim payment entitlement.

Status: repaired in draft; production configured URLs still need to be read and tested after deploy.

## 2026-08-21 — PR #88 CI startup failure

Observed: GitHub Actions run `32493207031` ended as `startup_failure` with path `BuildFailed` before any jobs were created. The run has no job records or job logs.

Root cause: not established. Evidence points to repository/Actions startup infrastructure rather than a failing application test because no runner job started.

Repair/action: do not change payment logic to chase this failure. Track the Actions startup issue independently and obtain a real Functions + Flutter test execution before PR #88 can move out of draft.

Verification: GitHub run metadata plus empty job list.

Status: open infrastructure blocker for automated PR acceptance.
