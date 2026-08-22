# Pipe Buyer Dispatch + Stripe Test Launch Execution Plan

**Status:** ACTIVE  
**Branch:** `feature/dispatch-stripe-green`  
**GREEN base:** `7a42f8d01e43a5c0ec3e6994098e7af1b88ce2eb`  
**Stripe feature checkpoint before this plan:** `dcd6b4ca845ccef9dbdb3e7bcb87ee9ac398b0f7`  
**Target:** complete the testing-launch path in the current work session, ideally within a few hours. This is a time-boxed goal, not permission to bypass safety gates.

## 1. Objective

Get Pipe Buyer into a safe tester-launch state while finishing as much of the Dispatch subscription stack as can be proven locally and against Stripe without opening uncontrolled live billing.

Testing launch and live billing activation are separate gates.

### Testing launch can proceed when

- the GREEN-based Stripe branch passes Functions and Flutter validation;
- Dispatch membership UI/routes work in browser acceptance;
- Directory, Request Service, startup/auth, and quote flows remain intact;
- Firebase Functions required by the tester build are deployed from the validated GREEN-based commit;
- Hosting is deployed only from the validated current app build;
- Stripe billing remains fail-closed if production readiness is incomplete.

### Live subscription charging cannot proceed until

- signed production webhook handling is verified;
- required subscription lifecycle events are configured;
- Customer Portal configuration is reviewed and approved;
- exact current policy acceptance is enforced for paid Checkout;
- tax launch evidence is satisfied (`stripeTaxReady=true`) or the separately audited pending-registration billing approval is intentionally enabled;
- Monthly and Yearly controlled acceptance tests reconcile Stripe invoices/payments to Pipe Buyer membership records with no unexplained difference.

## 2. Non-negotiable payment invariants

1. `invoice.paid` is the sole canonical Stripe event that grants or extends Dispatch paid entitlement.
2. Browser redirects, Checkout completion, provider status, or client state never grant paid access.
3. Dispatch bidding requires the membership owner to match the caller, `active=true`, and `currentPeriodEnd` to be in the future.
4. Failed renewal does not revoke time already paid for.
5. Cancel-at-period-end preserves access through the paid-through date.
6. New Checkout is blocked while an active membership or nonterminal Stripe subscription already exists.
7. Customer Portal plan switching remains disabled at launch.
8. Marketplace Checkout remains OFF.
9. Affiliate payouts remain OFF and require their separate economics gate.
10. VIP billing remains OFF.
11. No secret keys, raw Stripe secrets, or service-account credentials are committed.

## 3. Repository operating model

### Frozen safety baseline

- GitHub branch: `recovery/2026-08-22-automated-green`
- Commit: `7a42f8d01e43a5c0ec3e6994098e7af1b88ce2eb`
- Treat as immutable backup.

### GREEN reference clone

- `D:\Game Development\pipeapp-green-20260822`
- Do not use this clone for new Stripe development.
- Do not reset/clean/restore its current staged Stripe delta as part of this launch path.

### Dedicated Stripe development clone

- `D:\Game Development\pipeapp-stripe-green-20260822`
- Branch: `feature/dispatch-stripe-green`
- This becomes the only working clone for Stripe + immediate Dispatch launch integration.

## 4. Anti-loop repair rule

No more validator-version loop.

For every failure:

1. identify the first failing layer;
2. classify it as wrapper/tooling, source, test-contract, environment, Firebase, or Stripe-provider state;
3. repair only that layer;
4. record symptom, root cause, exact repair, verification, and commit;
5. rerun only the smallest gate needed to prove the repair;
6. run the full regression only after a meaningful source batch is complete.

Do not repeatedly rerun full Flutter/Functions suites for shell-wrapper failures.

## 5. Current implemented Stripe/Dispatch scope

The GREEN-based Stripe branch already contains:

- Dispatch Monthly `CA$25/month` server-owned price configuration;
- Dispatch Yearly `CA$300/year` server-owned price configuration;
- Checkout reservation/lease and stable server attempt idempotency keys;
- duplicate/open Checkout protection;
- active-membership and provider-subscription duplicate protection;
- `invoice.paid` entitlement extension;
- failed-renewal preservation of paid-through access;
- subscription create/update/delete/pause/resume lifecycle handling;
- private membership status and server-owned pricing catalog;
- paid-through server guard before Dispatch quote/bid submission;
- Customer Portal backend with payment-method update + period-end cancel + no plan switching;
- explicit tax/readiness gating;
- separate affiliate-payout economics gate;
- authoritative webhook lifecycle catalog;
- Dispatch membership page;
- server-priced Monthly/Yearly billing UI;
- success/cancel return surfaces that explicitly do not grant entitlement;
- payment-focused Functions and Flutter regression coverage.

## 6. Time-boxed execution sequence

### Phase A — Dedicated Stripe clone + validation
**Target time:** 20–40 minutes

- Create `D:\Game Development\pipeapp-stripe-green-20260822` directly from `feature/dispatch-stripe-green`.
- Verify exact branch/SHA and clean worktree.
- Add only the three payment routes to recovered navigation:
  - `/payments/dispatch`
  - `/payments/success`
  - `/payments/cancel`
- Run Functions install/lint/check/tests.
- Run Flutter analyzer.
- Run focused Stripe + Dispatch + Directory regression.
- Run complete Flutter regression once.
- Commit/push route integration only if all gates pass.

**Exit gate:** validated clean feature commit on GitHub.

### Phase B — Local browser acceptance
**Target time:** 20–30 minutes

Verify at the local formal acceptance URL:

- one branded startup surface;
- signed-out Marketplace auth gate;
- signed-in Marketplace shell;
- Dispatch Directory loads providers;
- Hotshot/service filter remains stable;
- Directory -> Get Quote supports provider-allowed multi-service selection;
- Request Service taxonomy + existing trucking controls remain intact;
- Dispatch membership page loads server catalog;
- Monthly and Yearly display `CA$25/month` and `CA$300/year`;
- when readiness is held, Checkout button/message remains fail-closed;
- success/cancel routes never grant membership;
- native app build continues to hold hosted Stripe purchasing.

**Exit gate:** browser acceptance recorded once.

### Phase C — Stripe provider readiness completion
**Target time:** 30–60 minutes

Read current Stripe/provider state before each write.

- Create/review one narrow Customer Portal configuration:
  - payment method update ON;
  - cancel at period end ON;
  - subscription plan switching OFF.
- Record approved `bpc_...` configuration ID through the audited readiness control.
- Verify production webhook endpoint.
- Add/verify required Dispatch lifecycle events:
  - `checkout.session.completed`
  - `checkout.session.async_payment_succeeded`
  - `checkout.session.async_payment_failed`
  - `invoice.paid`
  - `invoice.payment_failed`
  - `customer.subscription.created`
  - `customer.subscription.updated`
  - `customer.subscription.deleted`
  - `customer.subscription.paused`
  - `customer.subscription.resumed`
- Run a signed deployed-webhook probe.

**Exit gate:** Portal and webhook provider configuration match the app's authoritative contracts.

### Phase D — Tester deployment
**Target time:** 30–45 minutes

- Deploy validated Firebase Functions from the dedicated Stripe clone.
- Build the current validated Flutter web app.
- Deploy Hosting from that same validated app commit only.
- Do not use the retired legal script that rebuilds/deploys the whole site from a stale branch.
- Verify public app startup/auth/Dispatch/Directory/membership routes after deployment.
- Keep live subscription Checkout held if tax/policy/reconciliation gates are incomplete.

**Exit gate:** app is available for testers with Stripe UI/backend integrated and billing fail-closed where required.

### Phase E — Controlled billing acceptance (only if readiness evidence is complete)
**Target time:** 30–60 minutes

Run one controlled account at a time.

Monthly:
- create Checkout;
- verify duplicate/retry behavior;
- verify signed provider event processing;
- verify `invoice.paid` creates/extends membership;
- verify quote/bid access;
- verify Portal access;
- verify period-end cancel behavior.

Yearly:
- repeat the same acceptance path.

Then verify:
- failed renewal preserves paid-through;
- pause/resume lifecycle remains separate from paid entitlement;
- Stripe invoice/payment, Pipe Buyer invoice, membership and ledger reconcile with zero unexplained difference.

**Exit gate:** only then consider `stripeSubscriptionsEnabled=true` for normal live Dispatch billing.

## 7. Immediate post-launch Dispatch build

Once tester launch is stable, continue product work in this order:

1. Directory geography model;
2. radius search;
3. OpenStreetMap provider pins;
4. synchronized list <-> map selection;
5. provider detail surface;
6. Directory -> multi-service quote refinement;
7. Request Service refinement;
8. in-app messaging for job/quote context;
9. award workflow;
10. carrier workflow/status progression.

Keep the UI simple for non-technical field users: obvious actions, limited choices per screen, strong status feedback, and no GIS-style complexity in the normal user flow.

## 8. Stop conditions

Stop immediately rather than improvising if any of these occur:

- unexpected change outside the bounded file set;
- GREEN regression appears in Directory, Request Service, startup/auth, or quoting;
- Stripe account state differs from the expected price/product/account configuration;
- webhook signature verification fails;
- a redirect/client event appears capable of granting entitlement;
- Portal permits plan switching;
- policy or tax readiness is ambiguous;
- deployment source commit differs from the validated commit;
- Hosting build comes from any stale/recovery/payment branch other than the validated current launch branch.

## 9. Definition of done for this work session

Minimum successful outcome:

- dedicated Stripe clone validated;
- browser acceptance passed;
- validated Stripe/Dispatch branch pushed;
- tester build deployed from the validated commit;
- Dispatch subscription surfaces visible to testers;
- live charging still safely held if provider/legal/tax gates are incomplete;
- next Dispatch geography/map slice ready to begin.

Stretch outcome, only if all readiness evidence is green:

- Portal configured;
- webhook lifecycle verified;
- Monthly and Yearly controlled billing acceptance completed;
- Dispatch live subscription activation decision made from recorded evidence.

## 10. Status update rule

Update this document only when a gate is actually proven. Do not raise completion percentages from inference. Record the exact commit, command/result, and acceptance evidence once per completed gate.
