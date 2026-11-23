# Pipe Buyer Anti-Scam / Trust Risk Runbook

**Policy revision:** `2026-08-21-review-priority-v1`  
**Purpose:** Prioritize human Trust & Safety review.  
**Automatic enforcement:** **Never.**

## 1. Operating Principle

The risk score is a queue-ordering aid. It is **not** a fraud verdict, account score, payment decision, or automatic moderation decision.

A risk score must never by itself:

- remove or hide a listing;
- suspend or restrict an account;
- block a payment or payout;
- cancel a transaction;
- prevent a user from messaging;
- publicly label a seller or buyer as fraudulent.

All final enforcement continues through the existing administrator moderation commands and appeal process.

## 2. Existing Signals Reused

This work extends existing Pipe Buyer Trust & Safety foundations rather than replacing them:

- user-submitted reports;
- exact SHA-256 image duplicate detection;
- exact-photo evidence linked to related listings;
- conservative message safety pre-screen;
- human-review-required automated cases;
- `automaticEnforcement=false` behavior;
- administrator moderation decisions;
- moderation notices and appeals.

## 3. Review Tiers

| Score | Tier | Meaning |
|---:|---|---|
| 70–100 | High review priority | Review early because multiple or strong signals exist. |
| 40–69 | Elevated review priority | Material concern exists; review when high-priority cases are covered. |
| 0–39 | Normal review priority | Standard Trust & Safety review queue. |

The score is capped at 100.

## 4. Signal Weights

### User report reason

- Fraud / scam / impersonation: +55
- Reused photos: +45
- Existing automated exact duplicate-listing media case: +45
- Duplicate listing: +35
- Misleading information: +35
- Prohibited / unsafe item: +35
- Hate / racist content: +30
- Vulgar / harassing content: +25
- Spam: +20
- Other: +10

### Existing automated message signals

- Existing automated case marked high priority: +15
- Possible payment fraud: +30
- Possible threat: +20
- Possible hate/racist content: +15
- Vulgar/harassing content: +8

### Duplicate-photo evidence

- Exact SHA-256 image-hash evidence linking listings: +20
- Multiple duplicate-media matches/evidence items: +8

Exact image matches are evidence of file reuse, **not proof of fraud**. Legitimate sellers may reuse images when relisting or advertising related inventory.

## 5. Suspicious Price Review Hint

Price analysis is deliberately conservative.

A listing is compared only when:

- it is a normal sale listing, not Wanted or Auction;
- price can be normalized to a unit basis;
- candidate listings share the same category;
- candidate listings use the same currency;
- at least **5** valid comparable peer prices are available.

Signals:

- unit price <=20% or >=500% of peer median: +18;
- unit price <=40% or >=250% of peer median: +10.

An extreme price by itself remains a weak signal. It does not establish fraud. Industrial inventory can legitimately vary due to grade, condition, length, specification, certification, location, urgency, bundled quantity and seller strategy.

## 6. Admin Review Procedure

For a prioritized case:

1. Read the original report and evidence.
2. Inspect the listing/message in context.
3. If duplicate media is shown, compare the related listing IDs and media evidence.
4. Check whether the seller legitimately owns or controls both listings.
5. If a price signal appears, verify grade/specification/condition/quantity before treating it as meaningful.
6. For payment-fraud language, inspect the actual message context; do not assume every reference to wire transfer is fraudulent in industrial B2B commerce.
7. Use the existing moderation workflow for any final decision.
8. Record a specific rationale.
9. Preserve the existing appeal process.

## 7. False-Positive Controls

The following are mandatory:

- no automatic punishment;
- no public fraud badge from this score;
- no payment block from this score;
- bounded peer comparison only;
- same-category/same-currency price comparison;
- minimum peer sample of 5;
- exact image reuse treated as review evidence, not guilt;
- human rationale required before enforcement;
- existing appeals remain available after confirmed violations.

## 8. Parallel-Branch Boundary

This Anti-Scam branch must not modify:

- Stripe Checkout or Connect;
- payment readiness;
- tax policy;
- refunds/disputes/settlement;
- Dispatch subscription billing;
- message sending or attachments;
- formal Deal Room behavior;
- Dispatch job behavior.

The initial implementation is intentionally read-only and additive so it can be reconciled after the active payment and Messaging/UI branches.

## 9. Phase 1 Definition of Done

- [x] Versioned deterministic review-priority policy.
- [x] Human-only high/elevated/normal tiers.
- [x] Existing exact duplicate-image evidence understood.
- [x] Existing message-safety signals understood.
- [x] Conservative suspicious-price hint.
- [x] Read-only Admin fraud-review queue component.
- [x] Plain-language explanations for every score contribution.
- [x] Unit/widget test coverage added.
- [ ] Flutter analyzer/test suite executed successfully.
- [ ] Admin navigation integration after active UI branches reconcile.
- [ ] Rendered desktop/mobile administrator acceptance.

## 10. Next Anti-Scam Phases

After Phase 1 is stable:

- perceptual/similar-image matching rather than exact-file-only hashing;
- device/account relationship risk, using privacy-reviewed server signals;
- repeated seller/buyer report-pattern analysis with anti-abuse safeguards;
- listing identity/ownership verification signals;
- server-authored risk snapshots for durable audit history;
- configurable review thresholds through protected administrator controls;
- model-assisted review summaries only after a separate safety/privacy review.

Any later automated restriction must be designed and approved separately. This runbook does not authorize automatic enforcement.
