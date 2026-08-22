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
- [x] Dispatch Monthly CAD recurring price exists: CA$25/month.
- [x] Dispatch Yearly CAD recurring price exists: CA$300/year.
- [x] Pipe Marketplace Fee product exists with launch-v2 metadata.
- [x] Equipment & Assets Marketplace Fee product exists.
- [x] 1-year free Dispatch coupon exists and is valid.
- [x] 5-year free Dispatch coupon exists and is valid.
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

## Server checkout

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

## Remaining Dispatch subscription work

- [ ] Read current production `platform_configuration/payment_provider_readiness` values.
- [ ] Confirm `stripeSubscriptionsEnabled` intended state.
- [ ] Confirm `stripeMode` intended state.
- [ ] Confirm `stripeWebhookVerified` evidence.
- [ ] Confirm `stripeReconciliationReady` evidence.
- [ ] Confirm tax state is one authorized mode: registered, Canadian small supplier with current audited threshold evidence, or registration-pending with separate billing approval.
- [ ] Verify success/cancel URLs resolve to current Pipe Buyer routes.
- [ ] Verify Flutter monthly button calls current command.
- [ ] Verify Flutter yearly button calls current command.
- [ ] Verify success screen does not grant entitlement from redirect alone.
- [ ] Verify `invoice.paid` is authoritative for paid subscription monetization/entitlement.
- [ ] Verify failed recurring payment behavior.
- [ ] Verify cancellation/end-of-period behavior.
- [ ] Verify renewal behavior.
- [ ] Verify 1-year-free entitlement.
- [ ] Verify 5-year-free entitlement.
- [ ] Verify a 100%-discount invoice creates no false revenue/commission.
- [ ] Add/confirm customer self-service subscription management path.
- [ ] Run colleague acceptance test in controlled environment.
- [ ] Reconcile resulting Stripe invoice/payment to Pipe Buyer ledger/state.

P2 definition of done: a user can choose Monthly or Yearly, complete secure Stripe Checkout, Pipe Buyer records exactly one valid subscription entitlement after provider evidence, renewal/cancellation work, and revenue reconciles.

---

# P3 — External-settlement Marketplace fee — SECOND REVENUE TARGET

- [x] Architecture exists for buyer/seller settling industrial sale outside Stripe.
- [x] Pipe Buyer can bill only its Marketplace fee.
- [x] Fee-only webhook verifies checkout subtotal against immutable fee snapshot.
- [x] No seller-proceeds Transfer is created in fee-only settlement.
- [ ] Verify both-party external settlement confirmation gate end to end in the repository emulator acceptance run.
- [ ] Verify one-party-only confirmation cannot start fee checkout in the repository emulator acceptance run.
- [ ] Verify server-generated fee-only Checkout amount against an actual provider Checkout Session.
- [ ] Verify tax handling for Pipe Buyer fee against the active production tax-readiness state.
- [ ] Verify successful fee collection state from a controlled provider payment.
- [ ] Verify failed fee collection and clean retry from a controlled provider attempt.
- [ ] Verify duplicate Checkout prevention against provider behavior.
- [ ] Verify duplicate webhook prevention against controlled provider events.
- [ ] Verify fee receipt UX against a real paid Stripe Charge.
- [ ] Verify admin unpaid/paid/review/reconciliation states in web/mobile colleague acceptance.
- [ ] Reconcile one controlled provider payment with zero unexplained difference.

## P3 implementation and verification status — 2026-08-23

The items below separate **code evidence**, **focused executable verification**, and **financial acceptance**. A code-complete item is not automatically a financially accepted item.

### Code architecture

- [x] CODE — Full Stripe marketplace checkout and external settlement share a fail-closed payment-path exclusivity guard.
- [x] CODE — One-party external-settlement confirmation cannot satisfy the server fee-checkout gate.
- [x] CODE — Fee amount is read only from the immutable server marketplace-fee snapshot; the client cannot submit the authoritative amount.
- [x] CODE — External fee Checkout uses attempt-scoped Stripe idempotency rather than removing idempotency on retries.
- [x] CODE — Open fee Checkout Sessions are reused; processing/completed payments cannot create a second live fee payment.
- [x] CODE — Failed/expired fee Checkout can advance to a clean server-owned payment attempt.
- [x] CODE — Post-Stripe Firestore persistence preserves newer webhook-authoritative `processing`, `payment_failed`, or `collected` state instead of downgrading it to `checkout_created`.
- [x] CODE — Each created external fee Checkout attempt has a Firestore audit record for reconciliation support.
- [x] CODE — Authenticated user settlement workspace exists at `/account/settlements`.
- [x] CODE — User workspace shows buyer/seller settlement confirmation plus fee due, checkout open, processing, failed, and paid states from Firestore.
- [x] CODE — Seller fee action launches only a validated HTTPS `checkout.stripe.com` URL returned by the server.
- [x] CODE — Seller-only receipt callable re-reads the paid Stripe Charge and verifies stored amount/currency before returning receipt evidence.
- [x] CODE — Paid seller UX can open a validated HTTPS Stripe receipt or retain the verified Stripe Charge reference if no hosted receipt URL is available.
- [x] CODE — MFA-backed admin queue exists at `/admin/settlement-fees` and does not grant client-side payment-state overrides.
- [x] CODE — Admin queue surfaces confirmation pending, fee due, checkout open, processing, failed, paid, tax-review, payment-path-conflict, and reconciliation evidence.
- [x] CODE — Canadian small supplier is a distinct tax-readiness state; it is not faked as `stripeTaxReady` or registration pending.
- [x] CODE — MFA-admin GST/HST threshold assessment requires quarter totals, rolling-four-quarter totals, bookkeeping source note, and worldwide/associated-business attestation.
- [x] CODE — GST/HST threshold monitor uses CAD $30,000 with 75% warning, 90% high warning, and >$30,000 exceeded states.
- [x] CODE — Full Marketplace buyer-to-seller Checkout still requires actual `stripeTaxReady=true`; small-supplier mode authorizes only Pipe Buyer own-revenue flows such as fee billing/Dispatch where otherwise ready.
- [x] CODE — Provider-backed fee reconciliation re-reads Stripe Checkout Session → PaymentIntent → Charge → Balance Transaction.
- [x] CODE — Reconciliation validates immutable fee subtotal, tax, buyer total, currency, provider identity chain, paid/succeeded states, and provider gross/fee/net arithmetic.
- [x] CODE — Provider mismatch is stored as `mismatch`; Flutter cannot declare `balanced`.
- [x] CODE — Admin paid-fee card exposes server-controlled `Reconcile Stripe ↔ Firestore` and displays Balance Transaction, provider fee/net, and BALANCED/MISMATCH state.

### Focused executable verification

- [x] VERIFIED-FOCUSED — Exact branch P3 source was retrieved through the connected GitHub API and mounted under `/mnt/data/pipeapp` because the execution sandbox blocks outbound GitHub DNS even while the repository is public.
- [x] VERIFIED-FOCUSED — Node 22 syntax checks passed for the mounted payment-path, retry, receipt, tax/readiness, threshold, and reconciliation modules.
- [x] VERIFIED-FOCUSED — Consolidated mounted P3 Node suite executed **48 tests: 48 passed, 0 failed**.
- [x] VERIFIED-FOCUSED — Executed reconciliation-command tests prove the server re-reads Session/PaymentIntent/Charge/Balance Transaction through an injected provider chain, records `balanced` only when every check agrees, persists `mismatch` when provider evidence disagrees, and refuses unpaid fee state before provider calls.
- [x] VERIFIED-FOCUSED — Live Stripe read-only check identified the intended Pipe Buyer live account, confirmed the production webhook is enabled, and observed zero live Checkout Sessions at the time checked.

Focused verification is real execution evidence but **does not equal the repository-wide local quality gate, Firebase emulator acceptance, Flutter analyzer/tests/builds, or a live financial acceptance transaction**.

### Acceptance still required

- [ ] ACCEPTANCE — Run `tool/verify.ps1` successfully from the final P3 commit. This must include the repository Flutter/Functions/rules/build gates and the P3 emulator integration. GitHub-hosted Actions currently return repository-level `startup_failure` before jobs are created; do not treat that synthetic zero-job condition as a P3 code failure or alter payment code to chase it.
- [ ] ACCEPTANCE — Firebase emulator/provider-stub acceptance proves one-party rejection, both-party success, active-session reuse, failed-attempt retry, and webhook/callable race preservation.
- [ ] ACCEPTANCE — Controlled real Stripe fee payment proves successful collection, failure/retry behavior, duplicate handling, and provider-backed seller receipt.
- [ ] ACCEPTANCE — The controlled paid fee is reconciled by `reconcileExternalSettlementFee` to its Stripe Balance Transaction and produces `marketplaceFeeReconciliationStatus=balanced`, zero Firestore arithmetic difference, and zero provider gross-fee-net difference.
- [ ] ACCEPTANCE — Before enabling `canadaGstHstSmallSupplier=true` in production readiness, save a current audited threshold assessment that includes worldwide taxable supplies and associated businesses. Provincial tax obligations remain separate.
- [ ] ACCEPTANCE — User/admin settlement and threshold/reconciliation surfaces receive web/mobile colleague visual acceptance before production activation.

P3 code repair records:

- `docs/repairs/2026-08-22-p3-payment-path-exclusivity.md`
- `docs/repairs/2026-08-22-p3-fee-checkout-retry-and-race.md`
- `docs/repairs/2026-08-23-canada-small-supplier-gst-hst-mode.md`
- `docs/repairs/2026-08-23-p3-provider-backed-fee-reconciliation.md`

P3 release boundary: **do not merge or activate merely because code/focused tests are green.** Final repository-wide, emulator, provider-payment, exact reconciliation, and visual acceptance evidence must still agree.

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
- [ ] Record/maintain Canadian small-supplier threshold evidence while that status is being used.
- [ ] Confirm GST/HST registrations/effective dates when registration becomes required/available.
- [ ] Confirm BC PST treatment.
- [ ] Confirm seller registered/non-registered treatment.
- [ ] Confirm tax liability for Dispatch subscription flow.
- [ ] Confirm tax liability for fee-only Marketplace flow.
- [ ] Confirm tax liability for full on-platform Marketplace flow.
- [ ] Confirm Stripe Tax registrations match actual government registrations before setting `stripeTaxReady=true`.
- [ ] Confirm physical listing tax-code strategy.
- [ ] Confirm exemption workflow.
- [ ] Confirm refund/tax reversal process.
- [ ] Confirm accounting/remittance owner.

Never set `stripeTaxReady=true` solely because Stripe Tax is enabled in the Dashboard. Canadian small-supplier status is a separate readiness state and must be supported by current audited threshold evidence.

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

- [ ] Verify stored Checkout Session ID against a controlled provider payment.
- [ ] Verify stored PaymentIntent ID against a controlled provider payment.
- [ ] Verify stored Charge ID against a controlled provider payment.
- [ ] Verify stored Balance Transaction ID against a controlled provider payment. P3 code capture/re-read is implemented, but live acceptance is still required.
- [ ] Verify gross amount.
- [ ] Verify tax.
- [ ] Verify Pipe Buyer revenue.
- [ ] Verify Stripe provider fee and net amount.
- [ ] Verify seller proceeds where seller money movement applies.
- [ ] Verify Transfer ID where seller money movement applies.
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
4. [ ] Complete P3 external-settlement fee checkout acceptance.
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

## 2026-08-22 — P3 payment-path exclusivity

Observed: full Stripe marketplace checkout and external settlement did not share one authoritative path lock. A transaction could potentially cross into the other payment path after the first path had already begun.

Root cause: the two payment callables evaluated their own local conditions instead of a shared payment-path invariant.

Repair/action: added shared payment-path guard and applied it to both full Stripe marketplace Checkout and external-settlement confirmation/fee billing. The first active path now blocks the other path.

Verification: regression tests added in PR #95 and included in the 2026-08-23 mounted focused execution. Repository-wide/emulator/provider acceptance remains open.

Repair record: `docs/repairs/2026-08-22-p3-payment-path-exclusivity.md`.

## 2026-08-22 — P3 fee Checkout retry and webhook/write race

Observed: a failed external fee payment could reuse a stale Stripe Checkout Session because the original idempotency key did not distinguish logical payment attempts. Also, a fast Stripe webhook could advance Firestore to `processing`, `payment_failed`, or `collected` before the fee-checkout callable performed its final `checkout_created` write, allowing the callable to downgrade newer provider evidence.

Root cause: the first implementation modeled fee Checkout as one lifetime operation per marketplace transaction and persisted its post-provider state with a blind merge.

Repair/action: introduced server-owned payment-attempt numbering and attempt-scoped Stripe idempotency; open sessions are reused, processing payments are locked, failed/expired attempts can advance, and post-Stripe persistence uses a Firestore transaction that preserves newer webhook-authoritative state. Added provider-backed seller receipt verification and dedicated user/admin settlement surfaces.

Verification: Node/Flutter contract coverage exists; retry/idempotency policy was included in the 2026-08-23 mounted focused Node run. Live/emulator financial acceptance remains pending.

Repair record: `docs/repairs/2026-08-22-p3-fee-checkout-retry-and-race.md`.

## 2026-08-23 — Canadian small-supplier readiness and threshold monitor

Observed: treating pre-registration billing as `registration_pending` would misstate the user's current intended Canadian small-supplier status, and Stripe revenue alone cannot prove the CRA threshold because worldwide taxable supplies and associated businesses matter.

Root cause: payment readiness previously had no explicit small-supplier identity state and no audited threshold assessment record.

Repair/action: added distinct `canadaGstHstSmallSupplier` readiness, kept Stripe automatic tax off in that mode, kept full Marketplace Checkout gated behind real tax readiness, and added an MFA-admin threshold assessment/monitor with quarterly and rolling-four-quarter amounts, source note, attestation, warnings, revisioning, and audit trail.

Verification: small-supplier policy/readiness/threshold tests are included in the 2026-08-23 mounted focused Node run. Production readiness still requires a current saved business assessment; provincial taxes remain separate.

Repair record: `docs/repairs/2026-08-23-canada-small-supplier-gst-hst-mode.md`.

## 2026-08-23 — P3 provider-backed exact fee reconciliation

Observed: a paid Stripe Charge proved collection but did not expose the provider fee/net accounting required for exact reconciliation.

Root cause: P3 reconciliation stopped at Checkout Session / PaymentIntent / Charge evidence and did not require Stripe's linked Balance Transaction.

Repair/action: added server reconciliation that re-reads Checkout Session -> PaymentIntent -> Charge -> Balance Transaction, validates the immutable Firestore fee/tax/total and provider identity/arithmetic, persists BALANCED/MISMATCH plus provider gross/fee/net evidence, and exposes only an MFA-admin server-controlled reconciliation action in Flutter.

Verification: reconciliation policy and command tests were executed in the 2026-08-23 mounted focused Node run, including a full injected provider chain, mismatch persistence, and unpaid-state refusal. A controlled real Stripe fee payment is still required before exact reconciliation is financially accepted.

Repair record: `docs/repairs/2026-08-23-p3-provider-backed-fee-reconciliation.md`.
