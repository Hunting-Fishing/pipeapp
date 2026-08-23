# Dispatch Directory Functional Actions + Reputation

Status: REQUIRED before the Dispatch Directory is considered a functional business directory.

## Problem statement

The current Directory foundation is discovery-only. A provider card can expose company name, services, service area, availability, emergency/remote capability and approximate home base, but the card does not yet provide the actions a buyer needs to transact with that business.

The public seller storefront already supports seller/business identity, published contact fields, specialties and active listings, but the Directory does not link the provider card into that storefront or into messaging/request-for-work flows.

The marketplace also has an owner-facing `Trust Readiness` score based on account security/ownership signals. That is NOT the same thing as a public marketplace performance/reputation score and must not be presented as one.

This document is the source of truth for the missing functional Directory and reputation work.

---

## 1. Directory provider-card actions

Every eligible Dispatch Directory company card must provide a clear action area.

Required primary actions:

1. **View Business**
   - Opens the provider's public business/seller storefront.
   - Shows published profile, public contact choices, specialties/services and active listings.
   - Must never expose private legal/contact/location data.

2. **Message**
   - Opens an in-app company-level conversation.
   - Must not require the user to first find one of the provider's listings.
   - Conversation membership remains restricted to the signed-in requester and provider.
   - Existing message attachment, abuse-rate-limit, notification and Trust & Safety controls should be reused.

3. **Request Work / Get Quote**
   - Opens Request Service with the provider preselected.
   - Carries the selected `serviceCode` when the Directory is already filtered by a service.
   - Supports one provider or a controlled multi-provider request.
   - Provider receives an in-app notification and can respond through the service-request/quote workflow.

Required conditional actions when the provider has explicitly published the field:

4. **Call** — click/tap-to-call using the seller's public phone only.
5. **Email** — click/tap-to-email using the seller's public email only.
6. **Website** — opens the published HTTPS website.

Safety action:

7. **Report Business**
   - Opens the existing private Trust & Safety reporting flow.
   - Reports are not automatically treated as guilt or used as an immediate score penalty.

### Desktop card layout

Provider summary + score/status at top, service chips in the body, action row at the bottom:

`View Business | Message | Get Quote | Call | Email | More`

### Mobile card layout

Keep the card simple:

- Primary button: `Get Quote`
- Secondary: `Message`
- Tertiary: `View Business`
- Call/email/website/report under a compact More menu.

---

## 2. Company-level messaging

Current marketplace conversation creation is listing-scoped. A Directory business must be contactable even when it has no active listing.

Add a server-controlled command such as `openBusinessConversation` that reuses the existing `conversations/{conversationId}` and message infrastructure but creates a business context instead of a listing context.

Recommended conversation fields:

- `memberUids`
- `contextType: "business"`
- `contextId: providerUid`
- `contextTitle: operatingName`
- `providerUid`
- `openedByUid`
- `openedAt`
- `messageCount`
- `unreadCounts`

The existing send/read/attachment commands should continue to enforce membership and rate limits.

Do not make phone/email mandatory for a Directory provider. In-app messaging must remain available for providers who choose not to publish direct contact details.

---

## 3. Request Work / Get Quote

Request Service must become a generic industrial service-request flow rather than only a trucking-job form.

Required request flow:

1. Service category and specific service.
2. Work/pickup location and optional destination when transportation is involved.
3. Requested date/time/window.
4. Scope, equipment, quantities, dimensions and notes.
5. Recipient mode:
   - selected company;
   - selected companies;
   - all matching eligible companies;
   - open Dispatch network.
6. Review and send.

When launched from a Directory provider card, prefill the provider and current service filter.

Do not overload transportation-only `dispatch_jobs` indefinitely for non-transport work. The generic service-request data model should support industrial services without fabricating trucking fields.

---

## 4. Separate security readiness from public reputation

### Existing score: Trust Readiness

`Trust Readiness` is an account-protection score. It is based on ownership/security controls such as verified email, verified mobile and MFA. It is useful, but it is not a measure of marketplace professionalism or transaction performance.

### New score: Pipe Buyer Reputation Score

Create a distinct server-owned **Pipe Buyer Reputation Score** from 0-100.

It must be explainable and based on authoritative marketplace events. Clients must never write their own score.

A new account with insufficient marketplace history must display **New / Building history** rather than a misleading `0/100` or fabricated high score.

Recommended score dimensions (100 total):

- **Identity & business integrity — 20 points**
  - verified ownership/security state;
  - completed business profile;
  - administrator-confirmed business verification when applicable.

- **Listing/profile quality — 15 points**
  - structured required fields completed;
  - useful description/specifications;
  - valid location/service area;
  - sufficient legitimate media;
  - no confirmed duplicate/deceptive listing abuse.

- **Responsiveness — 15 points**
  - server-measured response rate to legitimate inquiries/service requests;
  - rolling median/percentile response time;
  - stale or spam interactions excluded.

- **Transaction/service performance — 25 points**
  - completed marketplace/Dispatch transactions;
  - punctual accepted milestones;
  - provider-caused cancellations/no-shows;
  - unresolved disputes and confirmed failures;
  - successful resolution history.

- **Verified reviews — 15 points**
  - reviews only from completed eligible transactions/jobs;
  - one review per participant per transaction;
  - no arbitrary public review creation;
  - rating volume and recency considered so one review cannot dominate a long-lived score.

- **Trust & Safety standing — 10 points**
  - only confirmed moderation decisions affect this component;
  - raw/unreviewed user reports never directly lower the public score;
  - serious confirmed fraud/scam behavior should trigger enforcement/suspension, not merely a cosmetic score reduction.

Weights must be versioned and may be adjusted after real marketplace data is observed.

---

## 5. Anti-scam and professionalism signals

Signals requested for the reputation system include:

- email/mobile/MFA ownership;
- completed business profile;
- quality/completeness of active listings;
- verified completed jobs/transactions;
- response rate and response time;
- punctuality against accepted job/transaction milestones;
- verified reviews;
- provider-caused cancellations/no-shows;
- confirmed disputes/administrative findings;
- confirmed misleading information;
- confirmed duplicate listings;
- confirmed reused/stolen photos;
- confirmed fraud/scam/impersonation;
- spam/harassment findings;
- account age/activity as a confidence signal, not a substitute for performance.

Automated duplicate-photo or duplicate-listing detection may create a private Trust & Safety signal/review case. It must not silently publish an accusation or penalize a seller before the policy-defined confidence/review threshold is met.

---

## 6. Reviews

Add server-controlled review eligibility after a completed Marketplace or Dispatch transaction.

Recommended collections:

- `marketplace_reviews/{reviewId}` — server-created/validated review record.
- `marketplace_reputation/{uid}` — server-owned current scorecard and private calculation inputs.
- `reputation_events/{eventId}` — immutable score-affecting audit events.

Public projections should contain only bounded safe summary fields, for example:

- `reputationScore`
- `reputationStatus` (`new`, `emerging`, `established`)
- `reviewAverage`
- `reviewCount`
- `completedTransactionCount`
- `responseBand`
- `reliabilityBand`
- `lastCalculatedAt`
- `scoreVersion`

Do not expose reporter identities, raw report counts, private moderation evidence, private security details, or exact internal score inputs.

---

## 7. Where the score must appear

Once server-calculated reputation exists, show the same bounded public summary consistently on:

- Dispatch Directory company cards;
- public seller/business storefront;
- Marketplace listing cards;
- listing detail seller block;
- Timed Buying / auction seller block;
- Dispatch quote/provider selection surfaces.

Example public treatment:

- `92 / 100 • Established`
- `4.8 ★ • 37 verified reviews`
- `Usually responds within 2 hours`
- `128 completed transactions`

For insufficient history:

- `New provider • Building reputation`
- show verified identity/business badges that are actually supported;
- do not fabricate a numeric performance score.

---

## 8. Score explainability

Tapping the public score should open an explanation sheet with component bands rather than secret internal raw data.

Example:

- Identity & business: Strong
- Listing quality: Strong
- Responsiveness: Good
- Transaction reliability: Excellent
- Verified reviews: 4.8 / 5
- Trust & Safety: Good standing

The account owner may receive a more detailed private scorecard with concrete improvement actions.

---

## 9. Required security/privacy boundary

- Directory cards read only server-owned/public projection fields.
- Public phone/email are shown only when the business explicitly publishes them.
- Exact private addresses and private provider contact data remain private.
- Reputation score is server-calculated.
- Clients cannot write `reputationScore`, review eligibility, completion counts, response statistics or moderation outcomes.
- Unreviewed reports never automatically penalize the public score.
- Admin moderation evidence remains private.
- Verification badges are shown only when authoritative server state supports them.

---

## 10. Build order / acceptance gates

### Slice D1 — Functional Directory actions

- View Business from every provider card.
- Message from Directory without requiring a listing.
- Get Quote / Request Work with provider preselected.
- Conditional Call / Email / Website actions.
- Report Business.
- Desktop and mobile action layout.
- Participant/privacy/rate-limit tests.

Acceptance: a buyer can discover a provider and take a real next action without leaving the Directory workflow.

### Slice D2 — Public reputation foundation

- Server-owned reputation schema/calculator.
- Versioned score formula.
- `New / Building history` handling.
- public bounded reputation projection.
- no client score writes.
- no raw report-count exposure.
- score calculation tests.

### Slice D3 — Verified reviews + behavioral metrics

- completed-transaction review eligibility;
- review submission/moderation;
- response metrics;
- transaction reliability metrics;
- punctuality/cancellation/dispute inputs.

### Slice D4 — Reputation UI everywhere

- Directory cards;
- seller storefront;
- listing cards/details;
- auction/timed buying;
- Dispatch provider/quote views;
- score explanation sheet.

### Slice D5 — Automated anti-scam signals

- duplicate listing detection;
- duplicate/reused image fingerprinting;
- suspicious behavior signals;
- signals create private Trust & Safety review inputs;
- confirmed findings feed enforcement/reputation according to policy.

---

## Definition of done

The Dispatch Directory is not considered functionally complete until a user can:

1. find a business;
2. view its public business profile and listings;
3. message it;
4. request work/get a quote;
5. use its public phone/email/website when published;
6. report a safety concern;
7. see an authoritative reputation state when sufficient history exists;
8. understand why that reputation exists;
9. trust that raw accusations do not automatically become public penalties.
