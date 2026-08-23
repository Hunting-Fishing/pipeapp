# Repair record — P2 Dispatch InvoicePayment reconciliation and Portal configuration identity

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

## Why this repair was needed

Two concrete production-readiness problems remained after the initial Dispatch subscription hardening.

### 1. Subscription reconciliation still depended on an older Stripe Invoice payment shape

The first reconciliation implementation could derive a Charge from legacy/embedded Invoice fields. Stripe's current 2026 Billing API makes `InvoicePayment` the authoritative payment relationship for an Invoice and exposes the full list through `/v1/invoice_payments`.

Relying on `invoice.charge` or only an optionally included `invoice.payments` subset could therefore produce incomplete accounting evidence or silently miss multiple provider payments.

### 2. Billing Portal readiness did not identify the Stripe configuration being used

Pipe Buyer stored `enabled + returnUrl` and created Billing Portal sessions without a `configuration` parameter. That meant Stripe's current default Portal configuration controlled cancellation/payment-method behavior without Pipe Buyer recording which configuration was reviewed.

For a financial control plane, “use whatever Stripe currently considers default” is not auditable enough.

### 3. Large Flutter admin files had become an editing risk

`marketplace_payment_readiness.dart` has grown into a broad billing/admin composition file. Replacing that entire file merely to add one reconciliation widget would create unnecessary regression risk, especially in an environment without Flutter analyzer execution.

The repair therefore uses small responsibility-specific modules and a dedicated Dispatch Billing Operations page instead of expanding the large readiness file further.

## Exact repair

### Stripe InvoicePayment reconciliation policy

Added:

`firebase/functions/dispatch_subscription_invoice_payment_policy.js`

It owns current Stripe InvoicePayment parsing only:

- builds the authoritative paid-payment query:
  `/v1/invoice_payments?invoice=<invoice>&status=paid&limit=100`;
- accepts Stripe string or expanded-object identities;
- filters paid InvoicePayments to the requested Invoice;
- accepts only PaymentIntent-backed InvoicePayments for automatic Dispatch reconciliation.

The reconciliation command no longer depends on the older `subscription_monetization.sourceChargeFromInvoice()` helper.

### Provider chain for positive paid subscriptions

`reconcileDispatchSubscriptionInvoice` now re-reads:

1. Stripe Invoice;
2. full paid InvoicePayment list;
3. exactly one paid InvoicePayment for the normal automatic-subscription path;
4. the InvoicePayment's PaymentIntent;
5. the PaymentIntent's latest Charge;
6. the Charge's Balance Transaction.

The server then verifies Stripe evidence against Firestore amount, currency, plan, user, subscription, tax, commission base, Charge amount, Balance Transaction gross/fee/net arithmetic, and provider identities.

The reconciliation record persists the discovered:

- Stripe InvoicePayment ID;
- PaymentIntent ID;
- Charge ID;
- Balance Transaction ID;
- provider gross;
- Stripe fee;
- provider net;
- failed checks;
- `balanced` / `mismatch` status.

Reconciliation revision:

`2026-08-23-p2-v2-invoice-payment`

### Fail-closed provider cases

Automatic reconciliation refuses to guess when:

- the InvoicePayment list is paginated (`has_more == true`);
- more than one paid InvoicePayment exists;
- a positive paid Invoice has no single paid InvoicePayment yet;
- the paid InvoicePayment is not PaymentIntent-backed;
- the PaymentIntent has no Charge yet;
- the Charge has no Balance Transaction yet.

Those states require provider completion or manual financial review.

### 100% promotional subscriptions

A legitimate zero-dollar Dispatch Invoice must prove:

- stored amount paid = 0;
- provider Invoice amount paid = 0;
- no paid InvoicePayment;
- no PaymentIntent/Charge/Balance Transaction evidence.

It reconciles provider gross/fee/net as zero. Unexpected provider payment evidence on a zero-dollar Invoice is a mismatch.

### Smaller admin composition

Added:

`lib/marketplace/marketplace_dispatch_subscription_admin_page.dart`

The page:

- requires the approved administrator role plus MFA;
- composes the existing reconciliation panel;
- explains the current provider chain;
- does not read/write authoritative financial Firestore records directly.

The existing `marketplace_dispatch_subscription_admin_panel.dart` remains callable-only:

- `getDispatchSubscriptionReconciliationQueue` for the sanitized queue;
- `reconcileDispatchSubscriptionInvoice` for server-authoritative reconciliation.

Route/navigation wiring remains a separate small integration seam. The large Billing Readiness file was intentionally not reconstructed/replaced without Flutter analyzer protection.

### Exact Stripe Billing Portal configuration identity

The audited Dispatch Billing Portal control now stores:

`stripePortalConfigurationId` (`bpc_...`)

Portal availability requires:

- explicit Pipe Buyer portal readiness;
- valid reviewed `bpc_...` configuration ID;
- valid Stripe customer identity;
- valid Stripe subscription identity;
- no operational review conflict.

Every Portal session now sends:

- `customer`;
- exact `configuration`;
- reviewed Pipe Buyer HTTPS `return_url`.

Enabling the Portal requires explicit production confirmation and a valid configuration ID. Emergency disable still works with an empty configuration and return URL.

## Stripe live audit during this repair

The Pipe Buyer live account currently has **zero Billing Portal configurations**. The connected Stripe API surface can list/retrieve Portal configurations but does not expose a create/update Portal configuration operation in this session.

Therefore:

- no live Portal configuration was fabricated;
- Pipe Buyer Portal readiness remains OFF;
- a reviewed `bpc_...` ID must be entered only after the configuration is actually created in Stripe Dashboard.

The live production webhook currently receives `invoice.paid` but does not receive:

- `invoice.payment_failed`;
- `customer.subscription.updated`;
- `customer.subscription.deleted`.

Those events remain deliberately disabled until the receiving lifecycle code is fully verified and deployed.

## Focused verification executed

### InvoicePayment reconciliation

Focused Node 22 source-logic harness:

- **6 passed**
- **0 failed**

Covered current InvoicePayment identity, positive provider chain, zero-dollar path, mismatches, and multiple-payment fail-closed behavior.

### Billing Portal configuration pinning

Focused Node 22 source-logic harness:

- **4 passed**
- **0 failed**

Covered:

- `bpc_...` identity validation;
- Portal availability requires exact configuration identity;
- Portal session sends the exact audited configuration;
- missing configuration prevents any Stripe session request.

Repository tests were also added/updated for the policy, admin readiness, and session command. Full repository execution remains pending because this runtime does not have Flutter/Dart/Firebase CLI and GitHub-hosted jobs still fail before executing steps.

## Do not repeat

- Do not reconcile modern Stripe subscription payments from `invoice.charge` alone.
- Do not assume an embedded Invoice `payments` subset is the complete provider payment history.
- Do not choose one of multiple paid InvoicePayments automatically; require financial review.
- Do not invent Charge/Balance Transaction evidence for a zero-dollar promotional Invoice.
- Do not create Billing Portal sessions against an unspecified/default Stripe configuration.
- Do not enable the Pipe Buyer Portal readiness flag until the exact reviewed `bpc_...` configuration exists and is recorded.
- Do not grow the large Billing Readiness/Admin files simply because a new financial control needs a UI; prefer responsibility-specific modules and composition.
- Do not mark P2 financially complete until a controlled live Monthly and Yearly payment each reconcile to `BALANCED` with real Stripe provider evidence.
