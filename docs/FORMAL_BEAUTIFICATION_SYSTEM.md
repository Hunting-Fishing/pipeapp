# Pipe Buyer Formal Beautification System

Status: Active implementation guide  
Started: August 15, 2026  
Scope: Web, tablet, Android and Apple marketplace presentation  
Reference: Pipe Buyer premium UI mockups supplied for the Phase 1.1 redesign

## Goal

Create one production-grade Pipe Buyer visual language from the strongest recurring patterns in the approved mockups while preserving existing Firebase schemas, commands, permissions, feature gates, billing controls and release safeguards.

The target is an industrial marketplace that feels closer to a mature B2B commerce product than a generated FlutterFlow application: restrained, fast to scan, image-led, high-trust and consistent across desktop and mobile.

## Non-negotiable product boundaries

- Do not invent marketplace statistics, seller counts, review counts, transaction volume, countries served or payout totals from design mockups.
- Do not imply that Pipe Buyer holds funds, provides escrow, releases money or guarantees settlement unless the corresponding production capability and legal/operational gate are enabled.
- Keep seller verification, anti-scam, fraud, reporting and dispute wording tied to actual implemented controls.
- Exact private coordinates stay private. Public location presentation uses the existing approximate-location boundary.
- Presentation work must not weaken App Check, Firebase rules, authentication, MFA, marketplace commands or audit history.

## Canonical brand system

### Core colors

Use the existing `PipeBuyerColors` contract as the source of truth.

- Safety Orange: `#FF6A00` — primary CTA, selected state, pricing emphasis and premium highlight.
- Ink: `#0D1117` — top utility bars, dark trust panels, primary text on light surfaces.
- Graphite: `#1E2938` — dark gradients, secondary dark surfaces and industrial depth.
- Slate / Muted: `#475569` / `#64748B` — secondary text and non-primary controls.
- Canvas: `#F6F7F9` — default app background.
- Surface: `#FFFFFF` — cards, navigation and data panels.
- Industrial Blue: `#0F52BA` — informational state, maps, selected informational layers and secondary system actions.
- Success: `#148A45` — verified and completed states.
- Warning: `#F59E0B` — time-sensitive or incomplete actions.
- Danger: `#D92D20` — destructive or blocking actions.

Orange is the commercial/action color. Blue is not the primary marketplace CTA.

## Typography

Use one typography pair everywhere:

- `Outfit` — display, hero, page heading and high-impact commercial headings.
- `Manrope` — interface text, filters, buttons, forms, cards, metadata and dense operational data.

Avoid page-by-page font switching. The mockups contain several font explorations; the production implementation standardizes on the existing Pipe Buyer Outfit + Manrope contract.

### Type hierarchy

- Hero / Display: 44–56 desktop, 34–40 tablet, 28–34 mobile, weight 800–900.
- Page H1: 32–40 desktop, 28–32 tablet, 24–28 mobile, weight 800.
- Section H2: 22–28, weight 800.
- Card title: 15–18, weight 700–800.
- Body: 14–16, weight 500–600.
- Metadata: 11–13, weight 600.
- Eyebrow / badge: 10–12, weight 800–900, restrained letter spacing.

## Shape, spacing and elevation

### Radius

- Search / form controls: 10–12 px.
- Standard cards: 12–14 px.
- Feature / hero panels: 18–22 px.
- Bottom sheets: 24 px top radius.
- Status pills: fully rounded.

### Spacing

Use an 8 px rhythm wherever practical: 4, 8, 12, 16, 24, 32, 40, 48, 64.

Desktop pages should use generous section spacing and restrained card padding. Dense admin/dispatch tables may use tighter row spacing while retaining 44–48 px interactive targets.

### Elevation

Prefer borders and subtle shadows over floating Material cards.

- Standard cards: 1 px neutral border, 0–1 visual elevation.
- Menus/dialogs: higher controlled shadow.
- Dark promotional panels: border + gradient, not excessive drop shadow.

## Desktop shell

The canonical desktop shell follows the strongest mockup pattern:

1. Thin dark utility bar for support/contact, worldwide availability, currency and language.
2. White primary navigation bar with Pipe Buyer logo, marketplace sections, account actions and orange Sign Up / primary CTA.
3. Constrained content width so large displays do not stretch mobile layouts.
4. Search/filter controls aligned as one horizontal commerce toolbar where width permits.
5. Footer with marketplace, sales resources, company, support, legal and payment/provider information that is actually enabled.

The existing adaptive rail remains appropriate for authenticated workspace-style areas where persistent workspace navigation is more useful than public-site navigation.

## Mobile shell

- Compact Pipe Buyer brand header.
- Search immediately reachable near the top of marketplace screens.
- Bottom navigation preserved for primary destinations.
- Primary action uses orange.
- Cards move to one-column or compact horizontal layouts without shrinking tap targets.
- Dense desktop seller/detail sidebars collapse below primary content.
- Sticky bottom actions are preferred for Message, Make Offer, Request Quote or Dispatch actions on listing detail.

## Home / discovery page

The public and first-use marketplace home should be image-led and commercially direct.

### Hero

- Industrial hero photography: pipe racks, hauling, cranes, pumpjacks or energy infrastructure.
- Left-aligned value proposition on desktop; readable overlay or separate text block on mobile.
- Two primary choices: Browse Marketplace and List Your Equipment.
- Trust strip immediately below: Verified Sellers, Secure Payments / provider-safe wording, Global Network and Fraud / Buyer Protection wording supported by production controls.

### Search

Prominent unified search composed of:

- category
- keyword / item
- location
- distance
- Search CTA

Do not duplicate competing search boxes on the same viewport unless one is clearly a global header search and the other is an advanced marketplace filter.

### Category strip

Use industrial illustration/icon assets, not generic Material warning/fallback icons, for category identity.

Priority visible groups:

- Pipe & Tubing
- Heavy Equipment
- Buildings & Shacks / Portable Buildings
- Crew Sites
- Crew Vehicles
- Trucking & Dispatch
- Marketplace / All Categories
- Scam Protection / Trust Center

Additional oilfield, tank, drilling, farm/ranch and property categories remain accessible through All Categories.

### Featured listings

Cards must standardize:

- consistent media ratio
- status badge in image area
- favorite action
- title
- price and unit
- seller verification
- location
- optional distance and activity signals

Never use fabricated listing counts from design mockups.

## Marketplace browse

Desktop browse should support two canonical modes:

### Grid mode

- left filter panel or horizontal filter toolbar depending on viewport
- results count + active chips
- sort control
- grid density control
- 1/2/3/4 column responsive policy based on readable card width

### Map mode

- result cards in a scrollable panel
- interactive map occupying the remaining width
- category-aware pins/clusters
- Search as I move the map
- map/list state must preserve active filters

## Listing detail

Desktop target is a structured three-zone layout:

1. media gallery and thumbnails
2. listing title, price, location, specifications and description
3. seller / trust / shipping sidebar

Required visible actions should include only implemented capabilities:

- Message Seller
- Make / Send Offer
- Request Quote
- Get Trucking / Dispatch
- Save
- Share
- Report

Mobile collapses to media, core listing data, seller/trust, specifications and sticky primary actions.

## Messaging / deal room

Desktop messaging uses a three-pane model where available:

- conversation list
- active conversation + listing context
- deal summary / documents / next actions

Mobile uses one pane at a time with explicit back navigation.

Offer cards, deadlines, documents and transaction actions should use the same status colors and labels as listing/transaction history.

## Dispatch

Dispatch is a professional logistics workspace, not a generic marketplace category screen.

Desktop priority:

- Post a Load / Find Trucks hero actions
- origin, destination, trailer type, load type and pickup date search
- active haul listings table/cards
- route map
- available trucks
- service/plan status and subscription state

Mobile prioritizes active jobs, quote/bid actions, route summary and awarded-job timeline.

## Trust / anti-scam presentation

Trust signals should appear repeatedly but not noisily:

- verified seller/business
- protected messaging
- payment/provider status
- reporting
- dispute/support access
- identity/profile completeness where applicable

Use dark trust panels selectively on home, listing detail, transaction and account security surfaces.

## Component migration order

### Increment A — visual foundation

- canonicalize typography inside `PipeBuyerTheme`
- finish hover/focus/pressed/disabled states
- finish card elevation and surface rules
- add visual contract tests

### Increment B — public home + discovery

- hero
- unified search toolbar
- category strip
- featured listing card polish
- responsive trust band

### Increment C — browse + map

- filter toolbar / side panel
- result cards
- map split layout
- active filters / saved search presentation

### Increment D — listing detail

- responsive media gallery
- specification tables
- seller/trust sidebar
- mobile sticky actions

### Increment E — create listing

- guided category workflow
- progressive sections
- media ordering / cover selection
- public preview

### Increment F — messages + deal room

- desktop split panes
- listing/deal context
- offer and document cards

### Increment G — Dispatch

- load board
- route workspace
- truck/provider cards
- subscription state

### Increment H — profile, seller center and admin

- buyer/seller dashboards
- seller storefront
- metrics
- operational tables

## Acceptance screenshots

Each increment should be checked at minimum at:

- 390 × 844 mobile
- 768 × 1024 tablet portrait
- 1024 × 768 tablet/desktop compact
- 1440 × 1000 desktop

Also verify browser zoom / large text, keyboard navigation, loading, empty, denied, offline and failure states.

## Branch and release policy

Beautification work remains isolated from behavior work. Each increment should be its own branch and PR, rebased or reconciled against active behavior branches before merge. Production deploy remains an exact-SHA action after the full Quality gate passes.
