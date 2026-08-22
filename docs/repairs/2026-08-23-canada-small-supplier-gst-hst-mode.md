# Repair record — Canadian GST/HST small-supplier billing mode

Date: 2026-08-23  
Branch: `p3-external-settlement-checkout`  
PR: #95

## Decision

Pipe Buyer can continue implementing and validating its own Marketplace-fee and Dispatch-subscription revenue flows while the Canadian GST/HST account is not yet registered, provided the operating business remains eligible for CRA small-supplier treatment and the production readiness record is backed by current audited threshold evidence.

This is **not** the same state as `stripeTaxRegistrationPending` and it must never be represented as `stripeTaxReady=true`.

## CRA baseline used for the application rule

CRA guidance reviewed on 2026-08-23 states that, for most businesses, the small-supplier threshold is CAD $30,000 of worldwide taxable supplies before expenses, including associated businesses, measured both in a single calendar quarter and across the previous four consecutive calendar quarters.

If the threshold is exceeded in a single calendar quarter, GST/HST applies starting with the supply that causes the threshold to be exceeded. If the threshold is exceeded only across four consecutive quarters, CRA applies the later effective-date rule described in its small-supplier guidance.

References:

- https://www.canada.ca/en/revenue-agency/services/tax/businesses/topics/gst-hst-businesses/when-register-charge.html
- https://www.canada.ca/en/revenue-agency/services/forms-publications/publications/rc4022/general-information-gst-hst-registrants.html

## Root cause

The original readiness model understood only registered, registration-pending, and not-ready states. After adding a proper Canadian small-supplier state, two additional integrity gaps remained:

1. an administrator could theoretically set the small-supplier readiness boolean without first proving a current audited threshold assessment; and
2. after small-supplier billing was enabled, a later assessment could exceed the threshold while the old readiness record continued to authorize fee/subscription billing.

Both are unsafe because Stripe revenue alone cannot prove CRA small-supplier eligibility and threshold evidence changes over time.

## Repair

### Explicit tax identity state

Added readiness field:

`canadaGstHstSmallSupplier`

When valid and active:

- Pipe Buyer platform-fee billing may pass the federal GST/HST readiness gate;
- Dispatch subscription billing may pass the federal GST/HST readiness gate;
- Stripe automatic tax remains OFF;
- checkout metadata records `small_supplier_unregistered`;
- no registration-pending provisional tax reserve is created;
- full buyer-to-seller Marketplace Checkout remains blocked because that flow still requires `stripeTaxReady=true`;
- registered, registration-pending, and Canadian small-supplier tax identity states are mutually exclusive.

### Authoritative threshold calculation

`canada_small_supplier_policy.js` is the single threshold-calculation helper.

It uses CAD $30,000 as the federal threshold, preserves exactly CAD $30,000 as not exceeded, and exposes:

- under 75%: `within_threshold`;
- 75%+: `warning`;
- 90%+: `high_warning`;
- more than CAD $30,000: `exceeded`.

The helper separately records single-quarter and rolling-four-quarter exceedance.

### Audited threshold assessment

The MFA administrator threshold workflow requires:

- single-calendar-quarter taxable supplies in CAD cents;
- rolling-four-quarter taxable supplies in CAD cents;
- bookkeeping/evidence source note;
- explicit attestation that worldwide taxable supplies before expenses and associated businesses are included;
- versioned assessment revision and audit history.

The application cannot infer this evidence from Stripe alone.

### Small-supplier readiness cannot be a bare boolean

Added `canada_small_supplier_readiness_guard.js`.

`setPaymentProviderReadiness` now refuses to enable `canadaGstHstSmallSupplier=true` unless the current audited assessment:

- exists;
- includes the worldwide/associated-business attestation;
- contains valid CAD-cent values;
- uses the authoritative CAD $30,000 threshold;
- is not exceeded;
- does not require registration review;
- has a valid audit revision.

When activation succeeds, the readiness record and readiness audit store:

`canadaGstHstSmallSupplierAssessmentRevision`

This binds the billing authorization to the threshold assessment that justified it.

### Reassessment keeps the binding current

While small-supplier billing remains active, every new under-threshold assessment transactionally:

- preserves `canadaGstHstSmallSupplier=true`;
- preserves current fee/subscription billing flags;
- advances `canadaGstHstSmallSupplierAssessmentRevision` to the new assessment revision;
- advances the readiness revision;
- records a `small_supplier_assessment_refreshed` readiness audit entry.

The app-managed readiness record therefore does not legitimately remain bound to an older threshold review after a new assessment is saved.

### Threshold exceedance automatically removes the old authorization

If a new audited assessment exceeds the threshold while Canadian small-supplier readiness is active, the same Firestore transaction automatically:

- sets `canadaGstHstSmallSupplier=false`;
- clears `canadaGstHstSmallSupplierAssessmentRevision`;
- sets `stripeFeeBillingEnabled=false`;
- sets `stripeSubscriptionsEnabled=false`;
- advances the readiness revision;
- writes a readiness audit identifying `small_supplier_threshold_exceeded`;
- records the triggering threshold-assessment revision.

It deliberately **does not** guess the GST/HST registration effective date, set `stripeTaxReady=true`, or automatically invent a registration-pending state. Tax registration/effective-date review is required before billing is deliberately re-enabled under the correct tax state.

If Pipe Buyer is already in actual registered tax-ready mode and small-supplier mode is inactive, a small-supplier threshold assessment does not rewrite or disable that registered configuration.

## Important operating constraint

Pipe Buyer cannot prove the CRA CAD $30,000 threshold solely from Stripe revenue. The threshold includes worldwide taxable supplies before expenses from relevant businesses and associates. The administrator assessment must therefore be maintained from bookkeeping/business evidence, not just Stripe payment totals.

Provincial sales-tax obligations remain separate. The federal GST/HST small-supplier threshold does not automatically determine BC PST or other provincial obligations.

## Verification executed

Focused Node 22 coverage verifies:

- small-supplier mode authorizes Pipe Buyer fee/Dispatch billing while properly configured;
- Stripe automatic tax remains disabled;
- no GST/HST reserve is computed for small-supplier status;
- pending registration alone remains insufficient;
- full Marketplace Checkout still requires active tax registration;
- tax identity states are mutually exclusive;
- CAD $30,000 is not treated as exceeded;
- one cent over the threshold is treated as exceeded;
- warning levels are deterministic;
- invalid negative/fractional threshold inputs fail closed;
- activation without an audited assessment is rejected;
- valid activation stores the assessment revision in readiness and audit evidence;
- an exceeded assessment cannot authorize small-supplier activation;
- active under-threshold reassessment refreshes the readiness binding to the new assessment revision without stopping billing;
- active exceeded reassessment automatically disables the small-supplier-dependent fee/subscription billing paths;
- registered tax-ready configuration is not damaged when small-supplier mode is inactive.

Latest focused control-plane run for activation/binding/shutdown: **10 tests passed, 0 failed**.

## Do not repeat

- Do not fake `stripeTaxReady=true` before actual registration/configuration is verified.
- Do not represent eligible small-supplier status as `stripeTaxRegistrationPending`.
- Do not allow `canadaGstHstSmallSupplier=true` without an audited threshold assessment.
- Do not leave readiness bound to an old assessment after a newer threshold assessment is saved.
- Do not leave fee/subscription billing enabled under the small-supplier authorization after the threshold assessment is exceeded.
- When the GST/HST number becomes available, change the readiness state deliberately; do not rebuild the checkout architecture or bypass these audit controls.
