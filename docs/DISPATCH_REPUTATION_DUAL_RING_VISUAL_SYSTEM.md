# Pipe Buyer Dual-Ring Membership + Reputation Visual System

Status: active UI contract for Dispatch Directory and future public seller surfaces.

## Purpose

A user's paid membership level and their marketplace reputation are two different concepts and must never be visually or mathematically merged.

The public score badge therefore uses **two independent colored borders** around the score number:

1. **Outer ring — membership level**
2. **Inner ring — Pipe Buyer Reputation**

Membership can unlock product benefits, but it must never purchase or inflate reputation.

## Outer membership ring

Public display tiers:

- Standard — slate/gray
- Bronze — bronze
- Silver — silver
- Gold — gold
- VIP — purple premium ring

Bronze/Silver/Gold are a new display/entitlement contract. The existing application already supports VIP access, but the lower paid membership tiers must not be treated as live billing products until the server billing catalog and entitlement mapping explicitly publish them.

The client may display only the server-owned public membership tier. A user cannot write their own membership color/tier.

## Inner reputation ring

Reputation color scale:

- Blue — New / Building history; no public numeric score yet
- Dark green — 90–100 Excellent
- Green — 80–89 Strong
- Yellow — 70–79 Good
- Orange — 60–69 Watch
- Red — below 60 At risk

A legitimate new account must not appear as `0 / 100`. Until the minimum data/confidence threshold is reached, the center reads **NEW** and the label reads **Building reputation**.

## Interaction

Desktop/web:

- Hover shows a concise Tooltip identifying membership ring, reputation band and current score state.
- Selecting/clicking the badge opens a compact legend and explanation popup.

Mobile:

- Tap opens the same legend/explanation popup.

The explanation includes the current reputation dimensions:

- Identity & business integrity — 20%
- Listing/profile quality — 15%
- Responsiveness — 15%
- Transaction/service performance — 25%
- Verified reviews — 15%
- Trust & Safety standing — 10%

## Anti-scam / fairness boundary

Only server-owned, policy-approved signals may affect the reputation score.

- Raw user reports do not automatically reduce a score.
- Confirmed moderation outcomes may affect Trust & Safety standing.
- Serious confirmed fraud/scam behavior should trigger enforcement, not merely a cosmetic lower score.
- Duplicate listing/photo detection can create a private review signal, but must not publish an accusation before the policy threshold or administrator review is satisfied.
- Paid membership tier is never an input to reputation score calculation.

## Initial implementation

Reusable UI:

`lib/marketplace/marketplace_reputation_badge.dart`

The component accepts only a bounded public reputation summary and a public membership tier.

Directory action surface:

`lib/marketplace/marketplace_dispatch_directory_actions.dart`

The Directory uses the dual-ring score beside real provider actions. If no authoritative reputation projection exists yet, it displays the blue **NEW / Building reputation** state rather than fabricating a score.

## Required future projection

The public provider/seller projection may contain only bounded fields such as:

- `membershipTier`
- `reputationScore`
- `reputationStatus`
- `reviewAverage`
- `reviewCount`
- `completedTransactionCount`
- `responseBand`
- `reliabilityBand`
- `scoreVersion`
- `lastCalculatedAt`

It must not contain raw report counts, reporter identities, private security state, internal moderation evidence, exact scoring inputs or private contact data.
