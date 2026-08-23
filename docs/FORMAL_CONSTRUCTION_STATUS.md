# Pipe Buyer Formal Construction Status

Updated: August 15, 2026

This document tracks the implementation sequence that follows the approved Pipe Buyer web/mobile mockups. It is intentionally separate from marketplace business logic so design work can advance without overwriting active behavior branches.

## Current implementation state

### 1. Home + Discovery — integrated on design branch

Implemented through the existing Home welcome insertion point:

- signed-out industrial marketplace hero
- signed-in personalized workspace hero
- Pipe Buyer category identity panel
- North America-first positioning
- trust band using implemented verification, messaging, offers and Dispatch concepts
- existing 30-day listing lifecycle surfaced without changing lifecycle rules
- mobile scrolling contract coverage

### 2. Browse + Map — presentation foundation complete

Reusable presentation components now exist for:

- result count / toolbar
- active filter chips
- filter-panel shell
- Grid / Map segmented control
- map header/chrome
- refresh and expand controls
- Search as I move the map control

Live wiring must preserve the active listing query, filters, approximate-location privacy rules, deep links and current map behavior.

### 3. Listing Detail — presentation foundation complete

Reusable components now exist for:

- responsive media / summary / detail / sidebar shell
- price, unit and location summary
- Message Seller / Make Offer / Request Quote / Get Trucking action grouping
- specification grid
- seller trust card
- protection/trust sections

The behavior layer remains owned by the existing marketplace listing-detail implementation.

### 4. Create Listing — guided-form foundation complete

Reusable components now exist for:

- category-to-publish step progress
- responsive guided form shell
- section cards
- inline guidance/tip cards
- mobile-first Back / Save Draft / Continue action bar

The final production flow should preserve the existing catalog, media upload, location privacy, feature gates, listing command and moderation behavior.

### 5. Messages / Deal Room — presentation foundation complete

Reusable components now exist for:

- three-pane desktop Deal Room
- two-pane medium layout
- mobile single-pane conversation layout
- listing-aware conversation header
- deal summary
- offer card with Counter / Accept / Decline presentation
- status sections for inspection, payment-provider status, trucking and documents

No message, offer, attachment, notification or transaction command is replaced by this layer.

### 6. Trucking & Dispatch — presentation foundation complete

Reusable components now exist for:

- professional Dispatch hero
- dispatch metrics
- responsive load-board workspace
- desktop table-style load row
- mobile load cards
- map/sidebar placement contracts

Provider signup, subscription access, route logic, bids, awards, pilot-truck workflows and carrier permissions remain behavior-owned.

### 7. Buyer / Seller Centers — presentation foundation complete

Reusable components now exist for:

- buyer/seller center hero
- responsive main/sidebar grid
- quick actions
- listing-health presentation
- profile/listing completeness status

Existing private offer history, seller-only best-offer visibility, saved items and account security rules remain unchanged.

### 8. Responsive / release acceptance — active

Widget contracts cover representative desktop and mobile layouts for the new formal components. Final release acceptance still requires the repository Quality gate, Flutter analyzer/tests, release build and rendered browser/device checks.

### 9. Seller listing analytics — integrated and under acceptance testing

The existing seller-only `getMarketplaceListingInsights` callable and listing-insights dialog now include a formal analytics experience without adding public scale claims or exposing other sellers' private activity.

Implemented analytics include:

- comparable median and comparable price range using normalized price basis
- seller listing position relative to the comparable median
- views, shares, saves, messages and offers from existing marketplace activity counters
- view-to-save, view-to-message and view-to-offer rates
- a clearly labelled engagement signal (`building`, `developing`, `strong`, or `limited`)
- conversion-oriented recommendations for high views with no saves/offers and conversations with no offers
- responsive KPI cards and buyer-engagement funnel presentation
- deterministic emulator analytics fixtures for visual acceptance testing
- unit tests for rate calculations, comparable pricing and engagement-signal logic
- widget tests for the formal analytics metric grid, signal band and funnel

The analytics UI explicitly states that activity counters are not unique-buyer counts and that comparable analytics are not an appraisal, valuation or guarantee of demand/sale price.

## Behavior-stack integration gate

The live marketplace behavior is currently spread across stacked/open pull requests, including:

- #79 dependency/CI package stack
- #80 Dispatch provider/service-area and account recovery work
- #81 listing activity, locations and offer guidance
- #82 smart offers, enriched messages/activity and current live Hosting bundle

The formal design branch must not overwrite those changes by copying an older `oil_gas_marketplace.dart`, `marketplace_messages_page.dart`, Dispatch page or account hub over them.

When the behavior stack is reconciled onto `main`, integration should proceed in this order:

1. rebase the formal design branch onto the reconciled behavior head/main
2. resolve Home personalization by retaining the newer user-data behavior and the formal hero presentation
3. wire Browse + Map components around the existing listing query and map data
4. wrap the existing Listing Detail behavior with the formal detail shell
5. wrap Create Listing sections without changing command payloads
6. wrap Messages with Deal Room components while retaining enriched listing context and attachments
7. wrap Dispatch around provider/subscription/bid/award behavior
8. wrap Buyer/Seller centers around private offer/listing/account data
9. run analyzer, widget tests, Firebase/Functions tests, release build and rendered smoke checks
10. only then promote the PR from Draft and consider production release

## Production safety boundary

No design component may:

- weaken Firebase Security Rules, App Check, Auth or MFA
- expose exact private listing locations
- expose private offer terms to competing buyers
- invent seller counts, ratings, transaction volume or other marketplace scale claims
- imply Pipe Buyer holds customer funds unless the production financial capability is explicitly enabled and approved
- bypass Dispatch membership/provider eligibility
- change listing lifecycle, offer, auction, payment, moderation or Dispatch command semantics

## Result

The complete visual construction sequence now has reusable Flutter building blocks. Listing-level seller analytics are also implemented on the formal branch with deterministic local fixtures. The remaining large integration work is controlled wiring with the reconciled behavior stack, not another round of one-off page styling.
