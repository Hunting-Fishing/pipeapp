# Pipe Buyer Core Journey Matrix

Status: active operational acceptance index  
Purpose: prevent autonomous development from optimizing isolated screens while missing complete user journeys.

This is an acceptance index, not a claim that every row is already complete. Implementation status comes from the domain trackers, tests, and real source. A worker may close a journey only when applicable UI, server/data/security behavior, failure handling, and verification agree.

## Public and account journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-PUB-01 | Public visitor | Open app → browse/search/filter/sort Marketplace → paginate | Real listing data, bounded reads, useful loading/empty/error states |
| J-PUB-02 | Public visitor | Open listing deep link → listing detail → seller profile | Stable route/deep link, structured details, public-safe data only |
| J-PUB-03 | Public visitor | Privacy / Terms / Support / account-deletion information | Stable public routes and current policy/support information |
| J-ACC-01 | User | Sign up/sign in → authenticated return path | Firebase Auth behavior, safe redirects, clear failure/retry state |
| J-ACC-02 | User | Account security → devices/sessions/MFA-sensitive admin boundaries | No client-trusted privilege, safe unavailable/denied states |
| J-ACC-03 | User | Export/delete account → cancel/recovery where supported | Server-owned lifecycle, auditability, privacy-safe confirmation |

## Seller journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-SEL-01 | Seller | Create draft → add structured specifications/media → publish listing | Server/rules validation, upload authorization, no mock production path |
| J-SEL-02 | Seller | Edit active listing → media/details → save | Existing listing identity/history preserved |
| J-SEL-03 | Seller | Expire/renew/relist/transition listing | Server-authoritative lifecycle and user-visible state |
| J-SEL-04 | Seller | View listing insights/saves/messages/offers | Participant-safe analytics and bounded reads |

## Buyer / offer / transaction journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-BUY-01 | Buyer | Save/unsave listing → return to saved discovery state | Server/rules-safe persistence and deterministic UI |
| J-MSG-01 | Buyer/Seller | Open listing conversation → send/read message → deep-link return | Membership authorization, safe upload/message states, notifications |
| J-OFR-01 | Buyer | Create offer with quantity/amount → seller receives it | Server-authoritative amount/quantity snapshot and idempotent command |
| J-OFR-02 | Buyer/Seller | Counter/revise/accept offer | Immutable/revision history, no client-forged acceptance state |
| J-TRX-01 | Buyer/Seller | Accepted offer → transaction lifecycle updates | Server-owned transitions, recovery/failure states and audit history |
| J-TRX-02 | Buyer/Seller/Admin | Cancel/dispute where allowed | Financial guard honored; paid state cannot be silently discarded |

## Wanted Ads journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-WNT-01 | Buyer | Create/edit Wanted criteria → active Wanted item | Structured criteria, lifecycle and authorization |
| J-WNT-02 | Buyer/Seller | New supply → ranked match → contact/dismiss/restore | Bounded matching, safe participant data, deterministic dismissal state |

## Auction journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-AUC-01 | Seller | Create/convert listing to auction → configure timing/reserve | Reserve stays private and server validation owns lifecycle |
| J-AUC-02 | Bidder | Place/withdraw bid | Authorization, server-owned bid order, negative-path handling |
| J-AUC-03 | Bidder | Buy It Now | Server-authoritative atomic outcome and duplicate prevention |
| J-AUC-04 | Seller/System | Auction expiry → finalize → accepted transaction | Scheduled/manual finalization agree; reserve semantics preserved |
| J-AUC-05 | Admin/participants | Default/dispute/recovery state | Operationally visible and does not fabricate financial resolution |

## Dispatch journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-DSP-01 | Carrier/provider | Apply/onboard → reviewed provider → fleet readiness | Role/verification server-owned; denied/pending states clear |
| J-DSP-02 | Shipper | Create Dispatch draft → private exact route → publish public-safe job | Exact participant data never leaked to public document |
| J-DSP-03 | Carrier | Browse eligible jobs → submit/revise quote | Server authorization and immutable quote history |
| J-DSP-04 | Shipper | Compare quotes → award | Server-owned award; non-winners and lifecycle update correctly |
| J-DSP-05 | Participants | Awarded job → transaction/status updates | Participant authorization, private route access, recovery/error handling |

## Subscription / payment journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-BIL-01 | Dispatch customer | Select Monthly CA$25 → server checkout → provider completion | Client cannot set amount/Price ID; redirect alone grants no entitlement |
| J-BIL-02 | Dispatch customer | Select Yearly CA$300 → server checkout → provider completion | Same server/provider authority as monthly |
| J-BIL-03 | Subscriber | Renewal / payment failure / cancellation / end-of-period | Webhook/provider state drives entitlement and recovery UI |
| J-BIL-04 | Eligible subscriber | 1-year / 5-year free entitlement | Server-owned eligibility; zero-dollar invoice must not create false revenue |
| J-BIL-05 | Subscriber | Manage subscription/self-service | Authenticated server-owned provider path and return/recovery state |
| J-FEE-01 | Marketplace parties | Both confirm external settlement → fee snapshot → fee-only checkout | One-party confirmation cannot bill; no seller-proceeds Transfer |
| J-FEE-02 | Admin | Reconcile checkout/payment/refund/dispute identifiers | Provider IDs, webhook event and immutable fee revision visible/actionable |

## Trust / support / administration journeys

| ID | Persona | Journey | Required outcome |
| --- | --- | --- | --- |
| J-TRU-01 | User/Admin | Submit verification → admin review → account state update | Protected review, audit history, no client-written privilege |
| J-MOD-01 | User/Admin | Report content/user → review → appeal where supported | Human-reviewed enforcement, safe evidence and audit trail |
| J-SUP-01 | User/Admin | Create support case → reply/update/close | Participant authorization, actionable status and history |
| J-ADM-01 | Admin | Enter admin surfaces | Administrator claim + MFA required; no email/profile bypass |
| J-ADM-02 | Admin | Payment/readiness/reconciliation review | Read-only visibility where provider evidence absent; mutations explicitly gated |

## Required failure modes

For every P0/P1 journey being closed, verify at least the applicable failures:

- signed out / expired session;
- authorization denied;
- network/provider unavailable;
- invalid or stale state;
- duplicate/retry invocation;
- empty data;
- partial server/provider completion;
- user retry after failure;
- mobile narrow layout and desktop layout;
- back/deep-link navigation where relevant.

## Sprint rule

During the 48–72 hour operational sprint, workers should close incomplete P0/P1 journeys before adding optional feature depth. Do not mark a journey complete because one screen renders or one server command exists. The complete path and its important failure state must be evidenced.
