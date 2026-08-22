# Repair record — Canadian GST/HST small-supplier billing mode

Date: 2026-08-23
Branch: `p3-external-settlement-checkout`
PR: #95

## Decision

Pipe Buyer can continue implementing and validating its own Marketplace-fee and Dispatch-subscription revenue flows while the Canadian GST/HST account is not yet registered, provided the operating business remains eligible for the CRA small-supplier treatment and the production readiness record explicitly reflects that status.

This is **not** the same state as `stripeTaxRegistrationPending` and it must never be represented as `stripeTaxReady=true`.

## CRA baseline used for the application rule

CRA guidance reviewed on 2026-08-23 states that, for most businesses, the small-supplier threshold is CAD $30,000 of worldwide taxable supplies before expenses, including associated businesses, measured both in a single calendar quarter and across the previous four consecutive calendar quarters.

If the threshold is exceeded in a single calendar quarter, GST/HST applies starting with the supply that causes the threshold to be exceeded. If the threshold is exceeded only across four consecutive quarters, CRA applies the later effective-date rule described in its small-supplier guidance.

References:

- https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/when-register-charge.html
- https://www.canada.ca/en/revenue-agency/services/forms-publications/publications/rc4022/general-information-gst-hst-registrants.html

## Root cause

The payment readiness model previously understood only three practical conditions:

1. tax registered / Stripe Tax ready;
2. registration pending with a separate billing approval;
3. tax not ready.

That model incorrectly forced an eligible unregistered Canadian small supplier into either `not_ready` or `registration_pending`, neither of which accurately describes the legal/business state.

## Repair

Added explicit readiness field:

`canadaGstHstSmallSupplier`

When true:

- Pipe Buyer platform-fee billing may pass the federal GST/HST readiness gate;
- Dispatch subscription billing may pass the federal GST/HST readiness gate;
- Stripe automatic tax remains OFF;
- checkout metadata records `small_supplier_unregistered` as the tax collection status;
- no provisional registration-pending tax reserve is created;
- full buyer-to-seller Marketplace Checkout remains blocked because that flow still requires `stripeTaxReady=true`;
- the readiness validator prevents `small supplier`, `registration pending`, and `registered` from being active simultaneously.

The central provider-readiness loader now exposes this field so all payment callables consume the same rule.

Added `canada_small_supplier_policy.js` as the single threshold-calculation helper. It uses CAD $30,000 as the federal threshold, preserves exactly $30,000 as not exceeded, and exposes 75% warning, 90% high-warning, and exceeded states for future administrator monitoring.

## Important operating constraint

Pipe Buyer cannot prove the CRA $30,000 threshold solely from Stripe revenue. The threshold includes worldwide taxable supplies before expenses from all relevant businesses and associates. Production activation of `canadaGstHstSmallSupplier=true` therefore requires an explicit audited business attestation/review outside automatic Stripe calculations.

## Follow-up before/while revenue grows

- Add an administrator threshold-monitoring record for quarterly taxable supplies and any external/associated-business adjustment.
- Feed the authoritative threshold helper from that administrator record plus Pipe Buyer revenue evidence.
- Warn well before CAD $30,000 so registration work can begin without interrupting billing.
- When GST/HST registration becomes effective, atomically switch from `canadaGstHstSmallSupplier=true` to `stripeTaxReady=true` only after the registration and Stripe Tax configuration are verified.
- Keep provincial sales-tax obligations (for example BC PST where applicable) as a separate analysis; the federal $30,000 GST/HST threshold does not automatically resolve provincial tax obligations.

## Verification added

Unit coverage verifies:

- small-supplier mode authorizes Pipe Buyer fee/Dispatch billing;
- Stripe automatic tax remains disabled;
- no GST/HST reserve is computed for small-supplier status;
- pending registration alone remains insufficient;
- full Marketplace Checkout still requires active tax registration;
- tax identity states are mutually exclusive;
- CAD $30,000 is not treated as exceeded;
- one cent over the threshold is treated as exceeded;
- warning levels are deterministic;
- invalid negative/fractional threshold inputs fail closed.

Do not remove these invariants when the GST/HST number is added later; change the readiness state instead.
