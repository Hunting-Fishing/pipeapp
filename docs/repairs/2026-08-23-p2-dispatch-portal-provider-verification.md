# Repair record — P2 Dispatch Billing Portal provider verification

Date: 2026-08-23  
Branch: `p2-dispatch-subscription-hardening`

> **Current-policy note:** this record documents the original provider-verification repair. Its original launch rule that required subscription updates/Monthly↔Yearly switching to remain OFF has been **superseded** by `docs/repairs/2026-08-23-dispatch-unified-product-customer-reuse-plan-switching.md`. Current Portal policy revision is `2026-08-23-p2-v2-dispatch-plan-switching`. Current plan switching is allowed only for the exact canonical Dispatch Product and exact Monthly/Yearly Prices, Price-only updates, quantity OFF, and no plan-change proration. All other provider-verification controls in this record remain applicable.

## Root cause originally repaired

Pinning Portal sessions to a syntactically valid `bpc_...` solved mutable-default risk, but did not prove that the referenced LIVE Stripe configuration actually had the approved features. Stored provider proof could also become stale after an operator changed the Stripe configuration.

The repair therefore established two controls that remain current:

1. **provider-authored verification before enabling Portal readiness**; and
2. **live re-verification of the exact stored `bpc_...` before client-exposed Checkout/Manage Billing actions**.

## Original provider-verification architecture

`firebase/functions/dispatch_billing_portal_verification_commands.js`

Callable `verifyDispatchBillingPortalConfiguration`:

1. validates exact `bpc_...` identity;
2. validates reviewed Pipe Buyer HTTPS return URL;
3. requires MFA-admin production confirmation and audit reason;
4. retrieves the exact LIVE Stripe Portal configuration;
5. runs the current provider feature assessment;
6. fails closed on identity/feature mismatch;
7. only successful provider proof can enable `platform_configuration/dispatch_billing_portal`;
8. stores exact configuration binding, provider-policy revision, sanitized provider features, administrator identity, timestamps, and audit evidence.

`setDispatchBillingPortalReadiness` remains emergency revoke/disable-only. It cannot manually establish provider-authored readiness.

## Runtime drift control

`firebase/functions/dispatch_subscription_portal_runtime_gate.js`

Before client-exposed Dispatch Checkout or Billing Portal session creation, the server:

- requires an authenticated Firebase request before provider reads;
- validates stored provider proof against the current policy revision and exact `bpc_...`;
- re-reads the exact LIVE configuration from Stripe;
- runs the current provider assessment again;
- fails closed before the inner billing handler if provider configuration drifted.

This protects against post-verification changes to payment-method updates, customer-update fields, invoices, cancellation behavior, plan-switching scope, quantity permission, proration policy, Product/Price selection, configuration identity, active state, or livemode.

## Current provider policy

The original v1 policy required plan switching OFF. That rule is historical and must not be followed for the current cutover.

Current revision:

`2026-08-23-p2-v2-dispatch-plan-switching`

Current exact LIVE Portal proof requires:

- LIVE + active exact `bpc_...`;
- payment-method updates ON;
- customer updates ON for exactly Name, Email, Billing address, Phone, Tax ID;
- Shipping address editing OFF;
- invoice history ON;
- cancellation ON, `at_period_end`, cancellation proration `none`;
- subscription update ON;
- update field exactly `price`;
- quantity changes OFF;
- subscription update proration `none`;
- exactly Product `prod_V2WkE5D16GhGaD`;
- exactly Monthly Price `price_1U2SYGDkO07WMXyRm6xbprUn` and Yearly Price `price_1U7bTCDkO07WMXyRvLkWVHHu`.

Plan switching is safe only because a later repair also changed Pipe Buyer lifecycle and reconciliation authority from stale `metadata.dispatchPlan` to provider Price evidence.

## Live provider state now

A LIVE Billing Portal configuration now exists:

`bpc_1U7aEmDkO07WMXyRjjSqn4SF`

Payment-method updates, reviewed customer information fields, invoice history, cancel-at-period-end, Pipe Buyer header/return URL, and legal links have been configured. At the latest provider read, subscription update/plan switching is still OFF, so current v2 provider verification correctly remains not-ready until the Dashboard change is made.

The connected Stripe tool available to this workspace exposes Portal configuration reads but not a writable Portal-configuration operation. The remaining exact plan-switching configuration is therefore a Dashboard step, followed by server provider verification.

## Controls that must not regress

- Do not equate `bpc_...` format validation with provider configuration verification.
- Do not treat stored proof as permanently valid; re-read Stripe before protected billing actions.
- Do not perform provider reads for unauthenticated requests.
- Do not manually enable Portal readiness; only provider-backed verification may establish it.
- Do not reuse proof after configuration ID or provider-policy revision changes.
- Do not allow quantity changes, extra Products/Prices, or plan-change proration.
- Do not use `metadata.dispatchPlan` as current plan authority; current Subscription state and invoice accounting follow provider Price evidence.
- Do not add live lifecycle webhook events or run controlled money until the accepted receiver/verifier stack is deployed and reviewed.
