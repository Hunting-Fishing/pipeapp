# P2 Dispatch subscription production cutover

Date prepared: 2026-08-23  
Owner: Pipe Buyer financial/admin operations  
Scope: Dispatch Monthly CAD 25 and Dispatch Yearly CAD 300 recurring subscriptions

This checklist is the release boundary for P2. Do not mark Dispatch subscriptions financially production-ready because a button, Stripe Product, Price, Checkout Session, webhook handler, or `bpc_...` identifier exists. Completion requires repository acceptance, deployed receiver parity, provider lifecycle evidence, Firestore state, reconciliation, and operator review to agree.

## Current deliberate state

- Public Dispatch subscription activation: **OFF**
- Dedicated admin route: **registered at `/admin/dispatch-billing`**
- Main account/admin navigation: **implemented in code; Flutter analyzer/rendered acceptance still pending**
- Dispatch Billing Operations Portal control: **implemented; provider-backed verification required**
- Live Stripe Billing Portal configuration: **not created yet**
- Pipe Buyer Billing Portal readiness: **OFF**
- Subscription recovery verification: **not recorded yet**
- Subscription lifecycle webhook verification: **provider-verifier implemented; live events deliberately incomplete until receiver deployment**
- Controlled Monthly payment: **not run**
- Controlled Yearly payment: **not run**
- Live BALANCED reconciliation: **not proven**
- Legacy direct-write live-billing activation workflows: **retired; audited readiness control is authoritative**

The live Stripe catalog itself is already prepared:

- Monthly: CAD 25/month
- Yearly: CAD 300/year
- both recurring and active
- both use the Dispatch service tax code
- both use exclusive tax behavior
- 1-year-free coupon: 100% for 12 months
- 5-year-free coupon: 100% for 60 months

## Gate 1 — repository and emulator acceptance

Do not continue to provider configuration until the exact final P2 commit passes from a complete checkout.

- [ ] `tool/verify.ps1` passes.
- [ ] Flutter analyzer passes.
- [ ] Flutter tests pass.
- [ ] Functions `npm run check` passes.
- [ ] Firestore rules tests pass.
- [ ] callable/Auth/Firestore/Functions emulator acceptance passes.
- [ ] Dispatch subscription reconciliation tests pass.
- [ ] Dispatch Billing Portal provider-verification tests pass.
- [ ] Dispatch launch-readiness/provider-verification tests pass.
- [ ] dedicated Dispatch Billing Operations page and `/admin/dispatch-billing` route compile.
- [ ] admin-only account-menu/Administration Portal shortcuts compile and navigate to Dispatch Billing Operations without weakening MFA/admin authorization.
- [ ] no client can directly mutate `dispatch_subscriptions`, subscription invoices, provider identities, reconciliation records, or financial readiness state.

Record the accepted commit SHA here:

`P2_ACCEPTED_SHA = ________________________________`

## Gate 2 — merge and deploy the receiving code

The production deploy workflow requires the production commit to be contained in `main`.

- [ ] accepted P2 stack is merged to the intended release history.
- [ ] production deployment runs from the accepted `main` commit.
- [ ] deployed-function parity confirms the expected callable/webhook surface.
- [ ] `stripeMarketplaceWebhook` is deployed with the Dispatch lifecycle receiver.
- [ ] `createDispatchSubscriptionCheckout` is deployed with the provider-Portal runtime gate.
- [ ] `reconcileDispatchSubscriptionInvoice` is deployed.
- [ ] `getDispatchSubscriptionReconciliationQueue` is deployed.
- [ ] `createDispatchBillingPortalSession` is deployed.
- [ ] `getDispatchBillingPortalReadiness` / `setDispatchBillingPortalReadiness` are deployed.
- [ ] `verifyDispatchBillingPortalConfiguration` is deployed.
- [ ] `verifyDispatchSubscriptionLifecycleWebhook` is deployed.
- [ ] the production-readiness audit includes live Portal feature, lifecycle-event, and verifier deployment checks.

Record deployment evidence:

`P2_DEPLOYED_SHA = ________________________________`

## Gate 3 — create and provider-verify Stripe Billing Portal in LIVE mode

Create one reviewed LIVE Billing Portal configuration in Stripe Dashboard.

Required launch behavior:

- [ ] customer payment-method update is ON.
- [ ] invoice/billing history is ON.
- [ ] subscription cancellation is ON.
- [ ] cancellation mode is **at the end of the current billing period**.
- [ ] cancellation proration behavior is **none**.
- [ ] Monthly ↔ Yearly subscription plan/price switching is OFF.
- [ ] arbitrary subscription/product/price updates are OFF.
- [ ] branding/support information is reviewed.

**Why plan switching is OFF:** current Dispatch lifecycle state reads the Pipe Buyer plan from Dispatch subscription metadata. It does not yet derive and validate Monthly/Yearly from the live Stripe Price ID on every subscription update. Enabling Portal price changes before a separate provider-price-to-plan synchronization and proration policy exists could create Stripe/Pipe Buyer plan drift.

Capture the exact Stripe configuration ID:

`STRIPE_DISPATCH_PORTAL_CONFIGURATION = bpc________________________`

Then open `/admin/dispatch-billing` and use **Verify & enable Billing Portal**.

Enter:

- the exact LIVE `bpc_...` ID;
- the reviewed Pipe Buyer HTTPS return URL.

The server must re-read `/v1/billing_portal/configurations/{bpc}` using the production Stripe secret. Pipe Buyer must not enable Portal readiness merely because the ID has the correct prefix.

Provider verification must prove:

- [ ] returned Stripe configuration ID exactly equals the requested `bpc_...`.
- [ ] configuration is LIVE mode.
- [ ] configuration is active.
- [ ] payment-method update is enabled.
- [ ] invoice history is enabled.
- [ ] cancellation is enabled.
- [ ] cancellation mode is `at_period_end`.
- [ ] cancellation proration is `none`.
- [ ] subscription update is disabled.
- [ ] Pipe Buyer records the current Portal provider-policy revision.
- [ ] provider proof is bound to the exact stored `bpc_...` ID.
- [ ] Portal readiness audit records administrator, reason, exact configuration, sanitized provider features, and timestamps.

`setDispatchBillingPortalReadiness` is **not** an enable path. It is retained only for emergency disable/revocation. Only `verifyDispatchBillingPortalConfiguration` may establish Portal readiness.

- [ ] emergency disable has been verified to clear the stored Portal provider proof.
- [ ] confirm that disabling Portal readiness blocks new Dispatch Checkout while preserving existing provider/ledger evidence.

Live Dispatch subscription activation cannot pass the server readiness validator, exported Checkout runtime gate, or customer Portal session path without current provider proof.

## Gate 4 — verify Stripe Billing recovery settings

These are live Stripe Dashboard settings and must be reviewed there; do not infer them from application code. The currently available Stripe API surface does not expose these Dashboard controls as provider-readable evidence.

- [ ] Smart Retries / automatic retry policy is enabled with a reviewed retry window.
- [ ] failed-payment customer emails are enabled.
- [ ] upcoming renewal / invoice emails are reviewed if used.
- [ ] card/payment-method update path points customers to the reviewed Billing Portal.
- [ ] final subscription state after exhausted retries is reviewed against Pipe Buyer's entitlement policy.
- [ ] from `/admin/dispatch-billing`, choose **Record recovery verification** only after completing the Dashboard review.
- [ ] `stripeSubscriptionRecoveryVerified == true` is visible in the audited payment-readiness state.

Capture screenshots or operational notes in the release evidence. Do not put Stripe secrets in GitHub. This flag is an audited operator assertion, not provider-authored evidence, and must be revoked if the Dashboard recovery policy changes before re-review.

## Gate 5 — add and provider-verify subscription lifecycle webhook events only after receiver deployment

Current production endpoint already receives `invoice.paid`. Only after Gate 2 is verified, add:

- [ ] `invoice.payment_failed`
- [ ] `customer.subscription.updated`
- [ ] `customer.subscription.deleted`

After changing the endpoint:

- [ ] confirm endpoint remains enabled and live.
- [ ] confirm signing secret is unchanged/valid in Google Cloud Secret Manager.
- [ ] from `/admin/dispatch-billing`, run **Verify live lifecycle webhook**.
- [ ] `verifyDispatchSubscriptionLifecycleWebhook` re-reads the exact live Stripe endpoint.
- [ ] provider verification reports no missing required lifecycle events.
- [ ] `stripeSubscriptionLifecycleWebhookVerified == true` is written by the server/provider verifier; do not manually assert it.
- [ ] send or observe a controlled event and prove the deployed receiver claims/processes it.
- [ ] verify a receiver failure returns retryable failure rather than silently marking the Stripe event processed.

Do **not** add the events before the receiver is deployed. An administrator may revoke lifecycle readiness to false immediately, but cannot manually set it true.

## Gate 6 — verify the complete Dispatch launch-readiness set

From the dedicated MFA-admin Dispatch Billing Operations page, verify every prerequisite independently:

- [ ] exact reviewed Billing Portal `bpc_...` is provider-verified under the current Portal policy revision.
- [ ] core signed webhook is verified.
- [ ] subscription lifecycle events are provider-verified.
- [ ] Smart Retry/failed-payment email recovery review is recorded.
- [ ] provider reconciliation readiness is true.
- [ ] authorized GST/HST billing state is current.
- [ ] public `stripeSubscriptionsEnabled` remains OFF until the controlled acceptance window begins.

The launch-readiness panel and Portal verifier are prerequisite controls. They intentionally have no public subscription-activation button.

## Gate 7 — controlled live Monthly acceptance

Run this while Pipe Buyer is still in the controlled pre-public/soft-launch window.

Temporarily enable the audited Dispatch subscription readiness gate only for the controlled acceptance window, run the test immediately, and disable it again if the broader public launch is not yet approved. The readiness command must fail closed unless Gates 3–6 remain satisfied.

Test account must not have an existing unresolved Dispatch subscription.

- [ ] start Monthly Checkout from the Pipe Buyer UI.
- [ ] confirm displayed amount is CAD 25/month before tax, subject to the approved GST/HST readiness state.
- [ ] repeated tap/retry returns/reuses one logical Checkout attempt.
- [ ] complete the live payment with the approved controlled payment method.
- [ ] browser return alone does not grant entitlement.
- [ ] signed webhook writes provider-authoritative state.
- [ ] current Stripe Subscription is re-read before entitlement activation.
- [ ] Firestore `dispatch_subscriptions/{uid}` becomes the expected active/trialing state.
- [ ] `dispatch_subscription_invoices/{invoiceId}` records the paid invoice.
- [ ] no duplicate subscription exists for the same user.

Record:

`MONTHLY_SUBSCRIPTION_ID = ________________________________`

`MONTHLY_INVOICE_ID = in_______________________________`

## Gate 8 — Monthly provider-backed reconciliation

From Dispatch Billing Operations, run:

`Reconcile Stripe ↔ Firestore`

The server must re-read:

**Invoice → paid InvoicePayment → PaymentIntent → Charge → Balance Transaction**

Required:

- [ ] exactly one paid InvoicePayment for the normal automatic subscription invoice.
- [ ] PaymentIntent is succeeded.
- [ ] latest Charge matches the paid invoice amount/currency.
- [ ] Charge is linked to a Balance Transaction.
- [ ] provider gross matches the paid amount.
- [ ] Stripe fee is captured from the Balance Transaction.
- [ ] provider net satisfies `gross - Stripe fee = net`.
- [ ] Firestore amount/tax/commission-base arithmetic matches the provider Invoice.
- [ ] reconciliation status is **BALANCED**.
- [ ] `invoiceDifferenceMinor == 0`.
- [ ] `providerDifferenceMinor == 0`.
- [ ] no failed checks.

Record:

`MONTHLY_INVOICE_PAYMENT_ID = inpay________________________`

`MONTHLY_PAYMENT_INTENT_ID = pi____________________________`

`MONTHLY_CHARGE_ID = ch____________________________________`

`MONTHLY_BALANCE_TRANSACTION_ID = txn_____________________`

## Gate 9 — payment failure and recovery lifecycle

Use Stripe-supported controlled testing or the safest available provider method after the initial live acceptance.

Prove:

- [ ] `invoice.payment_failed` sets payment-issue state.
- [ ] `past_due` preserves current entitlement while Stripe is still retrying, per approved policy.
- [ ] successful recovery clears payment issue and returns to active state.
- [ ] exhausted/terminal `unpaid` removes entitlement.
- [ ] stale/out-of-order subscription update cannot roll a newer state backward.

## Gate 10 — Billing Portal cancellation and replacement

- [ ] active subscriber opens only `https://billing.stripe.com/...` from Pipe Buyer.
- [ ] Portal session uses the exact provider-verified `bpc_...` configuration.
- [ ] Portal does not offer Monthly ↔ Yearly plan switching.
- [ ] cancel at period end is reflected by Stripe lifecycle events.
- [ ] entitlement remains correct through the paid-through period according to approved policy.
- [ ] terminal cancellation removes entitlement.
- [ ] a legitimate replacement Checkout can start after the terminal/restartable state.
- [ ] retired Stripe subscription ID is preserved in the bounded retired ledger.
- [ ] very late retired Checkout/invoice/update/delete events are ignored for singleton mutation.

## Gate 11 — controlled live Yearly acceptance

Repeat the controlled acceptance using the Yearly plan.

- [ ] displayed amount is CAD 300/year before tax, subject to approved GST/HST state.
- [ ] only one logical Checkout/subscription is produced.
- [ ] paid invoice and entitlement are webhook-authoritative.
- [ ] provider-backed reconciliation is **BALANCED**.
- [ ] invoice difference = 0.
- [ ] provider difference = 0.

Record:

`YEARLY_SUBSCRIPTION_ID = ________________________________`

`YEARLY_INVOICE_ID = in__________________________________`

`YEARLY_BALANCE_TRANSACTION_ID = txn_____________________`

## Gate 12 — 100% promotional invoice acceptance

Use only an approved test entitlement; do not grant a promotion solely to manufacture evidence.

For a legitimate free promotion:

- [ ] provider Invoice amount paid = 0.
- [ ] no paid InvoicePayment exists.
- [ ] no PaymentIntent/Charge/Balance Transaction is invented.
- [ ] provider gross = 0.
- [ ] Stripe fee = 0.
- [ ] provider net = 0.
- [ ] affiliate commission = 0.
- [ ] reconciliation is BALANCED only if the zero-dollar evidence is exact.

## Gate 13 — operator and visual acceptance

- [ ] Monthly purchase UX is understandable on mobile.
- [ ] Yearly purchase UX is understandable on mobile.
- [ ] open Checkout is clearly shown instead of creating another payment.
- [ ] processing state tells user not to restart payment.
- [ ] payment issue language is understandable.
- [ ] Manage billing/cancel opens Stripe Portal only when provider verification is current.
- [ ] Dispatch Billing Operations shows prerequisite readiness separately from activation.
- [ ] Portal control clearly shows provider verification and emergency disable.
- [ ] administrator can see BALANCED/MISMATCH and Stripe fee/net without seeing unnecessary customer provider IDs.
- [ ] colleague soft-launch review is signed off.

## Gate 14 — final production activation

Only after all prior gates are recorded:

- [ ] approved GST/HST readiness evidence is current.
- [ ] `stripeSubscriptionLifecycleWebhookVerified == true` from live provider verification.
- [ ] Billing Portal readiness references the exact live `bpc_...` and its provider proof is current under the current Portal policy revision.
- [ ] `stripeSubscriptionRecoveryVerified == true` after current Dashboard recovery review.
- [ ] Smart Retry/email recovery settings have not changed since the recorded review.
- [ ] Monthly and Yearly each have controlled real provider evidence.
- [ ] Monthly and Yearly each reconcile BALANCED with zero differences.
- [ ] no unresolved duplicate/review state exists.
- [ ] Portal Monthly ↔ Yearly plan switching remains disabled unless a separate approved synchronization/proration release has been completed.
- [ ] `stripeSubscriptionsEnabled` is deliberately enabled for public production through the audited readiness control.
- [ ] release activation reason and administrator identity are recorded in the payment readiness audit.

## Emergency rollback

If any financial acceptance fails:

1. disable `stripeSubscriptionsEnabled` through the audited readiness control;
2. if required, disable Dispatch Billing Portal readiness separately; this revokes Portal provider proof and blocks new Dispatch Checkout;
3. revoke `stripeSubscriptionRecoveryVerified` or lifecycle readiness when the corresponding provider configuration is no longer trusted;
4. do not delete provider/ledger evidence;
5. preserve webhook/reconciliation/audit records;
6. identify the root cause before changing code;
7. record the exact repair and verification in `docs/repairs/`;
8. rerun the failed gate and the adjacent financial gates before reactivation.

Do not fix a reconciliation mismatch by editing Firestore to make the numbers agree. Provider evidence and application records must be reconciled through the server-authoritative repair path.
