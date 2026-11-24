# Pipe Buyer App Store listing draft

> **DRAFT - OWNER APPROVAL REQUIRED BEFORE LIVE SUBMISSION**
>
> This packet is local preparation only. It does not authorize saving more live
> metadata, uploading media or a build, adding the version for review, or
> releasing the app. Product, privacy, legal, support, and release owners must
> approve the exact signed-candidate presentation first.

Prepared: 2026-11-24 for the controlled free-core mobile test scope.

## Proposed App Store fields

App name:

```text
Pipe Buyer
```

Subtitle (30-character limit):

```text
Industrial Buy & Sell
```

Promotional text (170-character limit):

```text
Buy and sell pipe, equipment, and materials. Post wanted ads, compare offers, message participants, use timed buying, and coordinate eligible Dispatch work.
```

Keywords (100-character limit, comma-separated with no duplicate variants):

```text
pipe,equipment,materials,industrial,marketplace,buy,sell,wanted,offers,auction,dispatch
```

Categories:

- Primary: **Shopping**
- Secondary: **Business**

Full description (4,000-character limit):

```text
Pipe Buyer is an industrial marketplace for pipe, equipment, materials, and field work.

BROWSE AND DISCOVER
- Browse industrial listings and view item details and photos.
- Save listings and manage marketplace activity.
- Publish wanted ads for the items you need.

BUY, SELL, AND NEGOTIATE
- Create listings with user-selected media.
- Send, revise, compare, accept, and close offers.
- Use timed buying when it is enabled for the admitted release.
- Keep conversations connected to marketplace activity.

COORDINATE ELIGIBLE DISPATCH WORK
- Request service, review quote revisions, award work, and follow supported Dispatch workflows where available.

ACCOUNT AND SAFETY CONTROLS
- Sign in using supported account methods.
- Report marketplace activity for review.
- Access support, policy, privacy, data-export, and account-deletion controls.

The first mobile release is intended for controlled free-core testing. Availability can depend on region, account eligibility, and server-controlled feature flags. Native digital-subscription purchasing is not enabled in this test cohort.

Pipe Buyer does not hold purchase funds or provide escrow. Users remain responsible for item verification, final contracts, payment, permits, loading, transportation, and legal, tax, safety, or regulatory compliance.
```

## Length validation

Validated locally on 2026-11-24. Description length uses normalized LF line
endings; all fields remain comfortably below their App Store limits.

| Field | Characters | Limit | Result |
| --- | ---: | ---: | --- |
| Subtitle | 21 | 30 | Pass |
| Promotional text | 156 | 170 | Pass |
| Keywords | 87 | 100 | Pass |
| Full description | 1,304 | 4,000 | Pass |

## Category rationale

**Shopping is primary** because the principal customer journey is discovering,
listing, buying, and selling pipe, equipment, and materials through wanted ads,
offers, and eligible timed-buying workflows.

**Business is secondary** because company/provider profiles and eligible
Dispatch request, quote, award, and tracking workflows support industrial and
commercial work, but they are not the app's primary marketplace entry point.

## Six-shot controlled-test capture plan

Capture the same approved six concepts for every required Apple device class;
do not stretch an iPhone capture to fill an iPad frame.

| Shot | Proposed headline | Exact candidate view | Acceptance boundary |
| --- | --- | --- | --- |
| 1 | Buy & Sell Industrial Gear | Marketplace Home with browse entry points and representative industrial categories | Use release-safe approved test data; no unfinished or regulated property categories |
| 2 | Find Pipe & Equipment | Browse/search results containing pipe, equipment, or materials | Show only content available in the admitted candidate |
| 3 | Review Listing Details | One listing detail with approved media, specifications, save, and offer entry points | No real seller identity, location, contact details, or unapproved claims |
| 4 | List It or Post a Wanted Ad | Listing/wanted-ad creation choice or completed release-safe form state | Use anonymized fixtures; hide keyboards, debug overlays, and validation errors |
| 5 | Compare Offers & Timed Buying | Marketplace activity showing offer history and an eligible timed-buying state | Capture only if the exact release flags enable both presented workflows |
| 6 | Coordinate Dispatch Work | Eligible Dispatch request and quote workflow | Capture only supported regions/roles; do not imply carrier approval or service coverage that is not present |

Capture rules:

- Use the exact admitted signed candidate and approved feature-flag state.
- Use synthetic or explicitly approved test accounts and content; expose no
  real names, messages, addresses, phone numbers, emails, credentials, tokens,
  precise locations, or private business records.
- Remove debug banners, system notifications, test watermarks, loading states,
  and unrelated browser or device chrome.
- Review legibility, safe areas, orientation, and console crop on each required
  iPhone and iPad size before approval.
- Retain original captures, candidate version/build, device/OS, feature flags,
  capture time, and owner approval in the private acceptance bundle.

## Verified scope used for this draft

The language is intentionally limited to capabilities recorded in:

- [`README.md`](../README.md): industrial listings, timed auctions, wanted ads,
  offers, messaging, reporting, and Dispatch services;
- [`MOBILE_STORE_RELEASE_READINESS_2026-11-23.md`](MOBILE_STORE_RELEASE_READINESS_2026-11-23.md):
  the controlled free-core test scope and store-release boundaries;
- [`PHASE_1_LAUNCH_FINALIZATION_PLAN.md`](PHASE_1_LAUNCH_FINALIZATION_PLAN.md):
  accepted equipment/materials, wanted-ad, offer, messaging, timed-auction,
  Dispatch, reporting, and account boundaries;
- [`STORE_RELEASE_METADATA.md`](STORE_RELEASE_METADATA.md): production URLs,
  media requirements, privacy/reviewer gates, and repeatable update controls.

This copy deliberately excludes native subscription purchasing, escrow,
platform-held funds, regulated property/right transactions, guaranteed service
coverage, and any claim that store review or physical-device acceptance has
already passed.

## Approval checklist

- [ ] Product owner confirms that every pictured and described workflow is
  enabled in the exact candidate.
- [ ] Privacy/legal reviewers approve the copy, screenshots, policy alignment,
  category/content-rights answers, and regional presentation.
- [ ] Support owner confirms the production support path and coverage.
- [ ] Release owner validates character limits, device media, version/build,
  signed artifact, and live console preview.
- [ ] Owner gives action-time approval before any field or image is saved in
  App Store Connect.
