# Pipe Buyer Phase 1.1 Experience Upgrade

Status: In progress  
Started: August 5, 2026  
Baseline branch: `main` at `9cb4a784c468ad87c1e330509ad22d035562d3ad`  
Working branch: `phase-1-1-experience-upgrade`

## Verified production baseline

The Phase 1.1 user-experience work starts only after the following production
controls were completed and evidenced:

- Firebase production deployment from the exact reviewed `main` commit
- Production App Check enforcement
- Function inventory and release-manifest parity
- Mobile and desktop web visual acceptance
- Public `/about`, `/privacy`, and `/terms` pages
- Google OAuth branding verification and publication

This document does not claim Android or Apple store publication. Signed mobile
release candidates and physical-device/store acceptance remain separate release
activities.

## Safety boundaries

The experience upgrade must not weaken existing authentication, App Check,
Firestore/Storage rules, callable-command boundaries, idempotency, feature
flags, moderation, reporting, or release evidence.

The following remain unavailable until separate provider, legal, operational,
and reconciliation work is approved:

- platform-held deposits
- escrow or trust-fund custody
- payment release or refund controls
- paid boosts and paid auction fees
- carrier billing and settlement

A user-facing screen must not imply that Pipe Buyer holds or releases money
unless the complete approved settlement system is present.

## Design direction

Retain the current Pipe Buyer industrial identity:

- navy and slate for structure and trust
- marketplace blue for primary actions
- safety orange for emphasis and warnings
- white cards on a light neutral background
- Outfit headings and Manrope interface text
- the existing industrial asset library

The archived Buyer and Seller boards are workflow references, not a request to
restore the former all-purple visual system.

## Delivery order

### 1. Design system and adaptive shell

- consolidate repeated marketplace colors, spacing, radii, and elevations
- extract reusable page headers, cards, status chips, seller summaries, and
  action bars
- preserve the phone bottom navigation
- add tablet and desktop navigation patterns
- constrain wide-screen content instead of stretching mobile layouts
- move release identity to Account > Settings > About

### 2. Home and discovery

- repair industrial artwork used by the main action cards
- promote Gas Pipe and Oil Pipe entry points without changing the canonical
  Firestore category contract
- add responsive one-, two-, three-, and four-column marketplace grids
- improve filter, sort, map/list, loading, empty, and recovery states

### 3. Listing details

- responsive media gallery and full-screen image inspection
- structured pipe and equipment specifications
- seller verification, User Score, ratings, and report actions
- persistent message, offer, quote, freight, save, and share actions

### 4. Create listing

- guided listing-type and category workflow
- category-specific required fields
- media ordering, cover selection, retry, and preview
- logistics, location privacy, offer, RFQ, and auction settings
- final public preview and completeness validation

### 5. Buyer and seller centers

- buyer saved listings, searches, offers, purchases, and alerts
- seller inventory, drafts, inquiries, offers, views, saves, and listing health
- responsive seller performance metrics and charts
- one account model personalized by Buy, Sell, or Both intent

### 6. Messages, transactions, auctions, and Dispatch

- single-pane mobile and split-pane desktop messaging
- listing and transaction context in conversations
- consistent lifecycle timelines
- responsive auction and Dispatch workspaces

### 7. Administration and final acceptance

- dense operational tables with safe filters and audit history
- screenshot baselines at 390x844, 768x1024, 1024x768, and 1440x1000
- loading, empty, offline, denied, and failed-command states
- keyboard, screen-reader, Android, Apple compile, and web acceptance

## First implementation increment

The first code increment is intentionally narrow:

1. improve marketplace grid breakpoints so medium and desktop layouts do not
   jump from two directly to four columns
2. preserve explicit user density preferences while clamping them to readable
   card widths
3. add accessibility labels to the density control
4. update unit tests for compact, medium, expanded, and wide layouts

This change affects presentation only. It does not alter Firebase data,
queries, authentication, payments, commands, or production configuration.

## Pull-request rule

Every increment must be isolated in a branch, reviewed through the complete
Quality workflow, and squash-merged only after required checks pass. Production
deployment remains a separate exact-SHA action after `main` is green.
