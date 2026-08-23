# Pipe Buyer — Dispatch Stripe Acceptance Matrix

Status: pre-activation test specification  
Owner: Pipe Buyer engineering  
Implementation PR: #88 `fix/dispatch-checkout-hardening`  
Progress dashboard: `docs/PAYMENTS_PROGRESS_SCORECARD.md`

## Purpose

This document defines the provider-level acceptance evidence required before Pipe Buyer enables Dispatch subscription billing for customers. It is deliberately stricter than a successful browser redirect.

A test is complete only when the Stripe object/event, Firebase callable response, Firestore state, user-visible state, idempotency behavior, and accounting result agree.

## Non-negotiable invariants

- `invoice.paid` is the only Stripe event that establishes or extends paid Dispatch access.
- `checkout.session.completed` and subscription lifecycle events may record provider state but never grant paid access.
- A browser success URL never grants paid access.
- A failed renewal never removes time that was already paid for.
- Cancellation at period end preserves access through `currentPeriodEnd` and not beyond it.
- A provider subscription that is nonterminal blocks creation of another subscription, even if no paid entitlement exists yet.
- Client code never supplies a Stripe Price ID or authoritative amount.
- Both customer-facing Dispatch price surfaces use the authenticated server catalog.
- 100%-discount invoices may grant the provider-confirmed paid period but must create zero subscription revenue base and zero affiliate commission.
- Customer Portal is restricted to payment-method updates and cancel-at-period-end. Plan switching is disabled for the first launch.

---

# A. Preflight configuration

| ID | Test | Expected evidence | Pass |
| --- | --- | --- | :---: |
| A01 | Production Functions entrypoint | `production_bootstrap.js` re-exports `bootstrap.js`; Dispatch callables are present | [ ] |
| A02 | Stripe account identity | Production credential belongs to the approved Pipe Buyer live Stripe account; do not expose secret | [ ] |
| A03 | Monthly price | Server catalog and Checkout config both resolve to approved CA$25/month recurring price | [ ] |
| A04 | Yearly price | Server catalog and Checkout config both resolve to approved CA$300/year recurring price | [ ] |
| A05 | 1-year promotion | Server-owned entitlement maps only to approved 1-year 100% coupon | [ ] |
| A06 | 5-year promotion | Server-owned entitlement maps only to approved 5-year 100% coupon | [ ] |
| A07 | Payment readiness | Read production `platform_configuration/payment_provider_readiness`; record revision and relevant booleans/URLs without secrets | [ ] |
| A08 | Success URL | HTTPS Pipe Buyer URL resolves to `/payments/success` | [ ] |
| A09 | Cancel URL | HTTPS Pipe Buyer URL resolves to `/payments/cancel` | [ ] |
| A10 | Dispatch Portal return URL | HTTPS Pipe Buyer URL resolves to `/payments/dispatch` | [ ] |
| A11 | Webhook endpoint | Correct live endpoint URL, API version, status and account ownership | [ ] |
| A12 | Webhook event catalog | Live endpoint exactly matches `STRIPE_WEBHOOK_EVENTS` after handler deployment | [ ] |
| A13 | Customer Portal config | Approved `bpc_…` config is active, payment-method update ON, cancel ON at period end, subscription update OFF | [ ] |
| A14 | GitHub final gate | Hosted Actions billing intentionally restored only when branch is otherwise ready; real CI jobs start | [ ] |

---

# B. Price and UI truth

| ID | Test | Expected evidence | Pass |
| --- | --- | --- | :---: |
| B01 | Dispatch onboarding price | Monthly/yearly labels come from `getDispatchSubscriptionCatalog`; obsolete pilot price text absent | [ ] |
| B02 | Membership page price | Monthly/yearly labels come from `getDispatchSubscriptionCatalog`; no local price fallback | [ ] |
| B03 | Catalog unavailable | UI displays `Price unavailable` or payment-held state and disables checkout | [ ] |
| B04 | Checkout held | `checkoutAvailable=false` prevents payment button from starting a charge | [ ] |
| B05 | Active membership | Current paid member cannot start another Dispatch Checkout | [ ] |
| B06 | Portal availability | Manage-billing button appears only when server reports an approved Portal and owned provider subscription | [ ] |
| B07 | Payment issue messaging | Failed renewal is shown without claiming paid access ended early | [ ] |
| B08 | Cancel-at-period-end messaging | UI states access remains through the paid-through date | [ ] |

---

# C. Checkout idempotency and provider-state protection

| ID | Test | Procedure / expected state | Pass |
| --- | --- | --- | :---: |
| C01 | Monthly first attempt | One `cs_…` session, one checkout-state attempt number, one Stripe idempotency key | [ ] |
| C02 | Monthly rapid double click | No second provider Checkout session; UI/server duplicate guard holds | [ ] |
| C03 | Same-plan retry | Existing open `cs_…` session is reused while valid | [ ] |
| C04 | Network interruption during create | Retry uses same server attempt number after lease expiry; no second provider operation | [ ] |
| C05 | Different-plan overlap | Monthly open/creating blocks Yearly until prior attempt is resolved/expired | [ ] |
| C06 | Checkout completed before invoice paid | Provider state records `sub_…`/`cus_…`; membership is still not granted | [ ] |
| C07 | Nonterminal provider subscription | `active`, `trialing`, `incomplete`, `past_due`, `unpaid`, `paused`, `checkout_completed`, unknown all block new Checkout | [ ] |
| C08 | Terminal provider subscription | `canceled` / `incomplete_expired` permit a later new Checkout when no current paid membership remains | [ ] |

---

# D. Monthly paid subscription

| ID | Test | Expected Stripe / Firestore result | Pass |
| --- | --- | --- | :---: |
| D01 | Complete Monthly Checkout | Stripe creates subscription using approved monthly Price; Checkout session persisted | [ ] |
| D02 | Browser success return | Page says submitted/pending provider confirmation; membership is not granted by redirect | [ ] |
| D03 | `checkout.session.completed` | Provider state updated; no entitlement creation from this event | [ ] |
| D04 | First `invoice.paid` | `dispatch_subscription_invoices/{invoiceId}` recorded and `dispatch_memberships/{uid}` created/extended | [ ] |
| D05 | Paid-through period | Membership period equals provider-authored invoice period; plan is monthly | [ ] |
| D06 | Bid access after paid event | Server-side Dispatch quote guard accepts current paid member | [ ] |
| D07 | Duplicate `invoice.paid` delivery | Event ledger prevents duplicate processing; paid-through/revenue not double-counted | [ ] |
| D08 | Out-of-order replay | Older paid event cannot shorten a newer membership paid-through date | [ ] |
| D09 | Reconciliation | Invoice ID, subscription ID, customer ID, amount paid, currency, tax and ledger state reconcile with zero unexplained difference | [ ] |

---

# E. Yearly paid subscription

| ID | Test | Expected Stripe / Firestore result | Pass |
| --- | --- | --- | :---: |
| E01 | Complete Yearly Checkout | Stripe creates subscription using approved yearly Price | [ ] |
| E02 | `invoice.paid` | Membership plan yearly; provider-authored annual period recorded | [ ] |
| E03 | Duplicate event | No duplicate entitlement/revenue/commission side effect | [ ] |
| E04 | Bid access | Current annual paid membership passes server-side bid guard | [ ] |
| E05 | Reconciliation | Annual invoice/payment/state reconciles with zero unexplained difference | [ ] |

---

# F. Renewal and recovery

| ID | Test | Expected result | Pass |
| --- | --- | --- | :---: |
| F01 | Successful renewal | New `invoice.paid` extends paid-through once; never shortens previous period | [ ] |
| F02 | Duplicate renewal event | Second delivery is idempotent | [ ] |
| F03 | Failed renewal | `invoice.payment_failed` records failed invoice and `paymentIssue=true` | [ ] |
| F04 | Paid time preserved | Existing membership remains usable until its current paid-through timestamp | [ ] |
| F05 | Retry succeeds | Later `invoice.paid` clears payment issue and extends entitlement | [ ] |
| F06 | Retry does not succeed | After paid-through expires, status callable reports expired and bid guard rejects access | [ ] |
| F07 | Smart Retry settings review | Stripe Billing recovery configuration and customer emails are reviewed before launch | [ ] |

---

# G. Cancellation, pause and resume

| ID | Test | Expected result | Pass |
| --- | --- | --- | :---: |
| G01 | Cancel at period end | Subscription lifecycle records `cancelAtPeriodEnd=true`; existing paid access continues | [ ] |
| G02 | Before period end | Status remains active/active-until-period-end; bidding still works | [ ] |
| G03 | At/after period end | Membership normalizes expired/canceled and bid guard rejects access | [ ] |
| G04 | Subscription deleted | Provider state becomes terminal; no new entitlement is created | [ ] |
| G05 | Pause event | Provider state becomes paused/payment issue; no new paid time is invented | [ ] |
| G06 | Resume event | Provider state returns to provider status from Stripe; entitlement still governed by paid invoice period | [ ] |
| G07 | New checkout after terminal state | Allowed only after prior paid access is no longer current | [ ] |

---

# H. Customer Portal

| ID | Test | Expected result | Pass |
| --- | --- | --- | :---: |
| H01 | No Portal config | Server fails closed; UI does not expose management | [ ] |
| H02 | Wrong/inactive config | Server retrieves `bpc_…`, rejects it before creating a Portal session | [ ] |
| H03 | Plan switching enabled | Server rejects Portal config; subscription update must be OFF | [ ] |
| H04 | Immediate cancellation configured | Server rejects Portal config; cancellation mode must be at period end | [ ] |
| H05 | Approved config | Portal session created only for caller-owned `cus_…` + `sub_…` | [ ] |
| H06 | Portal URL | Returned URL is HTTPS `billing.stripe.com`; URL is not persisted in Firestore | [ ] |
| H07 | Update payment method | Stripe updates payment method; no entitlement changes from browser action alone | [ ] |
| H08 | Cancel in Portal | Signed subscription lifecycle event updates cancel-at-period-end state | [ ] |
| H09 | Return to Pipe Buyer | Returns to Dispatch membership page and refreshes provider-authored status | [ ] |

---

# I. 100%-discount promotions

| ID | Test | Expected result | Pass |
| --- | --- | --- | :---: |
| I01 | 1-year free eligibility | Only server-owned active entitlement selects 1-year coupon | [ ] |
| I02 | 1-year free paid invoice | Stripe `invoice.paid` with zero amount grants provider-authored period | [ ] |
| I03 | 1-year revenue | Commission/revenue base is zero; no affiliate commission ledger is created | [ ] |
| I04 | 5-year free eligibility | Only server-owned active entitlement selects 5-year coupon | [ ] |
| I05 | 5-year free paid invoice | Provider-authored paid period is accepted; no manual five-year date is fabricated by client | [ ] |
| I06 | 5-year revenue | Zero amount creates zero commission/revenue base | [ ] |
| I07 | Promotion replay | Duplicate zero-dollar paid event cannot extend or duplicate access beyond provider evidence | [ ] |

---

# J. Webhook deployment and delivery

| ID | Test | Expected result | Pass |
| --- | --- | --- | :---: |
| J01 | Signature rejection | Invalid signature returns HTTP 400 | [ ] |
| J02 | Timestamp tolerance | Stale signature fails | [ ] |
| J03 | Event ledger | `evt_…` recorded processed once | [ ] |
| J04 | Processing failure | Failed event recorded `failed` and endpoint returns non-2xx for Stripe retry | [ ] |
| J05 | Existing endpoint bootstrap | Existing `we_…` is disabled and its enabled events synchronized to repo catalog before handler deploy | [ ] |
| J06 | Signed deployment probe | New deployed handler accepts signed readiness probe | [ ] |
| J07 | Endpoint re-enable | Endpoint becomes enabled only after probe passes | [ ] |
| J08 | Final catalog comparison | Stripe enabled event list exactly matches `STRIPE_WEBHOOK_EVENTS` | [ ] |
| J09 | `invoice.payment_failed` delivery | Real/test provider event reaches handler and updates membership issue state | [ ] |
| J10 | Lifecycle delivery | create/update/delete/pause/resume events reach provider-state wrapper | [ ] |

---

# K. Security and abuse controls

| ID | Test | Expected result | Pass |
| --- | --- | --- | :---: |
| K01 | Unauthenticated checkout | Callable rejects request | [ ] |
| K02 | Unauthenticated status/catalog/portal | Private callables reject request | [ ] |
| K03 | App Check | Protected callable policy enforced on deployed surface | [ ] |
| K04 | Price tampering | Client-supplied amount/Price ID is ignored/not accepted | [ ] |
| K05 | Portal ownership | User cannot create Portal session for another user's provider state | [ ] |
| K06 | Membership ownership | User cannot bid using another user's membership document | [ ] |
| K07 | Malformed IDs | Invalid UID/session/customer/subscription/config IDs fail closed | [ ] |
| K08 | Rate limits | Checkout/status/catalog/portal abuse controls behave as intended | [ ] |

---

# L. Final release gates

| ID | Gate | Pass |
| --- | --- | :---: |
| L01 | Functions syntax/lint/unit suite passes | [ ] |
| L02 | Flutter analyze/test suite passes | [ ] |
| L03 | GitHub Quality passes | [ ] |
| L04 | GitHub Financial Safety passes | [ ] |
| L05 | GitHub Callable Safety passes | [ ] |
| L06 | Current Apple App Store purchase-policy review complete for native builds | [ ] |
| L07 | Current Google Play Billing policy review complete for native builds | [ ] |
| L08 | Live payment-readiness revision reviewed and explicitly approved | [ ] |
| L09 | Live Portal configuration explicitly approved | [ ] |
| L10 | Live webhook event expansion occurs only after deployed handler acceptance | [ ] |
| L11 | Monthly colleague acceptance passes | [ ] |
| L12 | Yearly colleague acceptance passes | [ ] |
| L13 | Free-promotion acceptance passes | [ ] |
| L14 | Reconciliation closes with zero unexplained difference | [ ] |
| L15 | No full Marketplace buyer-to-seller money movement enabled by Dispatch launch | [ ] |
| L16 | Affiliate payouts remain disabled until economics are separately approved | [ ] |
| L17 | VIP billing remains disabled until separately approved | [ ] |

## Definition of done

Dispatch subscription billing is complete when every required row above is checked with evidence, the final hosted CI gates pass, controlled Stripe acceptance reconciles, and the approved launch surface can sell Monthly/Yearly access without duplicate subscriptions, premature access, stale pricing, or unreconciled money.
