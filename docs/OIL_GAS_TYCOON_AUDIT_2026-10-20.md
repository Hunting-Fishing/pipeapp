# Pipeapp and Oil & Gas Tycoon audit

Date: 2026-10-20

Repository: `Hunting-Fishing/pipeapp`

Audited baseline: `b7c479ee1d359d50c8470de8c9009efb29df38c5` (`main`)

## Conclusion

Pipeapp is an existing Flutter application named **Pipe Buyer**, with substantial
industrial marketplace, timed buying, messaging, dispatch, profile, and payment
code. **The audited main branch did not contain an Oil & Gas Tycoon game.**
This change adds a new, playable single-player simulation and mobile interface.
The delivered game covers lease operations, commodity trading, equipment and
vehicles, employees, supporting businesses, company finance, career progression,
and local save recovery.

This audit distinguishes source evidence from runtime acceptance. File and
function presence establishes that implementation exists; it does not establish
that every customer journey currently works in production. Historical readiness
documents are used for context, not as fresh test results or current completion
percentages.

## Scope and method

- Inspected the current main source, application entrypoint and router, marketplace
  navigation, domain modules, Functions exports, tests, and release documentation.
- Searched `lib`, `test`, `firebase`, and `docs` for tycoon, gameplay, game state,
  and game-screen implementation. No existing game implementation was found.
- Searched accessible branch names for `game` and `tycoon`; neither search
  returned a branch.
- Reviewed the open pull-request inventory. The recent draft PR
  [#212](https://github.com/Hunting-Fishing/pipeapp/pull/212),
  `codex/apple-launch-readiness`, contained marketplace and timed-buying
  hardening at head `6a4f0490b655f25ac95887ef272af3a7841d10f9` when inspected.
  It is separate unresolved work and was not treated as merged into main.
- Found no applicable `AGENTS.md` in the checkout.
- Baseline source inventory: 210 Dart files under `lib`, 141 Flutter test files,
  and approximately 545 declared `test`/`testWidgets` calls. These are inventory
  counts, not passing-test counts.

## Existing Pipe Buyer feature inventory

| Area | Source evidence | Observed implementation |
| --- | --- | --- |
| Application and mobile foundation | `pubspec.yaml`, `lib/main.dart`, `android/`, `ios/`, `web/` | Flutter application and platform projects; shared preferences; app initialization, diagnostics, accessibility, localization, and themes. |
| Equipment and vehicle catalog | `lib/marketplace/oil_gas_marketplace.dart`, `marketplace_listing_specs.dart`, `marketplace_catalog_repository.dart` | Industrial categories, equipment brands/models, conditions, specifications, tubular sizes, listing presentation. |
| Listing marketplace | `oil_gas_marketplace.dart`, `marketplace_actions_repository.dart`, `marketplace_listing_lifecycle.dart` | Create/edit/publish, draft media upload, browse/filter/search, saved listings, listing lifecycle commands. |
| Offers and buyer/seller activity | `marketplace_offer_comparison.dart`, `marketplace_offer_analysis.dart`, `marketplace_offer_schedule.dart`, Functions `createMarketplaceOffer` and `acceptMarketplaceOffer` | Offer creation, comparison, acceptance, scheduling, and transaction integration. |
| Timed buying | `marketplace_auctions_page.dart`, `marketplace_auction_repository.dart`, `marketplace_auction_settlement.dart` | Bids, buy-now, reserve handling, expiry/finalization, and transaction records. |
| Businesses and profiles | `marketplace_profile_repository.dart`, `marketplace_public_profile_page.dart`, `marketplace_dispatch_company_profile*` | Marketplace identities, public/private profiles, company and dispatch provider information. |
| Dispatch and logistics | `marketplace_dispatch_*`, `marketplace_freight_quote.dart`, `marketplace_trucking_plan.dart`, `marketplace_digital_bol_modal.dart` | Provider discovery, service requests, quotes, award/lifecycle commands, equipment capabilities, credentials, logistics planning, and messaging. |
| Communications and support | `marketplace_messages_page.dart`, `marketplace_notification_service.dart`, reporting/support modules | Conversations, attachments, unread state, notification plumbing, reporting, moderation, support, and block/unblock. |
| Real payments and subscriptions | `marketplace_secure_payment.dart`, `marketplace_command_client.dart`, Firebase payment/subscription modules | Server-authoritative marketplace payment and membership workflows. These are real-commerce components, not a simulation engine. |
| Maps and location | `marketplace_location_picker.dart`, `open_address_autocomplete.dart`, dispatch geography modules | Configurable map/geocoder foundation and location-privacy classes. |
| Property and rights policy design | `lib/property_rights/`, `firebase/functions/jurisdiction_policy.js` | Jurisdictional policy models and prerequisites; not fictional lease gameplay. |
| Responsive navigation | `marketplace_adaptive_layout.dart`, `marketplace_adaptive_shell.dart`, `marketplace_grouped_navigation.dart` | Phone drawer/bottom navigation and wider-window rail layouts. |

## Missing game features at the audited baseline

All the following were absent as game capabilities. Existing real marketplace
features do not substitute for the simulation rules needed here.

| Requested capability | Missing game behavior |
| --- | --- |
| Player company and progression | New company, starting capital, goals, milestones, tutorial, progression, and success conditions. |
| Equipment buying and trading | Virtual shop, ownership, condition, purchase/sale valuation, maintenance, and operating effects. |
| Vehicles | Fleet ownership, transport/storage effects, condition, maintenance, and resale. |
| Oil and gas lease sites | Fictional lease catalog, ownership, drilling and extraction, operating requirements, upgrades, depletion, and sale. |
| Businesses | Purchase, operating income/costs, staffing effects, upgrades, and sale. |
| Employees | Hiring, roles, wages, capacity/productivity effects, and dismissal. |
| Production and commodity trading | Oil/gas inventory, capacity constraints, production, variable prices, buy/sell transactions, and quantity validation. |
| Economy and time | Day advancement, payroll/upkeep, production settlement, market changes, ledger, profitability, and solvency/recovery. |
| Saving and recovery | Versioned game save, load/resume, validation, malformed-save recovery, and confirmed new-game/reset behavior. |
| Mobile game interface | Touch-friendly company dashboard, field/leases, market, equipment/fleet, businesses, team, and management screens. |
| Game verification | Economy invariants, full playthrough tests, save recovery tests, responsive widget checks, and standalone builds. |

## Implementation architecture

The implementation selected for this work is a standalone Flutter package at
`games/oil_gas_tycoon/`, with minimal dependencies and its own entrypoint,
simulation state, catalog, economy, persistence, and game interface. Pipe Buyer's
main application exposes a `/tycoon` route and entries from its home screen and
drawer navigation.

This structure is useful for three concrete reasons:

1. Pipe Buyer's `lib/main.dart` bootstraps Firebase, release configuration,
   authentication, notification navigation, themes, and localization before
   opening the marketplace. The standalone game can start and save locally
   without those network services.
2. Game cash, fictional leases, businesses, employees, and commodity trades need
   deterministic rules and isolated state. Their actions must not invoke the
   real `MarketplaceCommandClient`, payment repositories, production listing
   commands, or regulated-property control plane.
3. Marketplace destinations use fixed numeric indices, including Browse `1`,
   Sell `2`, Messages `4`, Timed Buying `6`, and Dispatch `7`. A separate game
   route avoids changing the meaning of those existing destinations.

The game package remains part of this Git repository. The original marketplace
keeps its own configuration, data, and release process. The root integration is
handled as part of the same reviewed change.

### Implemented game scope

The new source closes the baseline simulation gaps with the following concrete
capabilities. Runtime evidence is reported separately below.

| Capability | Implementation evidence |
| --- | --- |
| Company and progression | `lib/src/app.dart` creates/resumes a named company. `tycoon_engine.dart` supplies a starter operation, eight milestone objectives, a tycoon career goal, and continued play after that goal. |
| Equipment, vehicles, and storage | `TycoonCatalog.assets` defines eight purchasable asset types. Engine actions buy, sell, repair, and assign equipment; wear affects output and haul capacity, and storage constrains inventory. |
| Lease acquisition and trading | Eight fictional oil/gas sites can be acquired, developed, operated, paused, and sold. Remaining reserves persist across resale/reacquisition so trading a lease does not replenish its resources. |
| Supporting businesses | Refinery, logistics company, and parts/repair yard can be purchased, upgraded through three levels, and sold; each has operating income, upkeep, and an economy effect. |
| Employees | Operators, drivers, engineers, and mechanics can be hired, trained, assigned where applicable, and dismissed, with payroll and role-specific effects. |
| Exchange and supply contracts | Bounded integer oil/gas purchases and sales use market prices with a buy/sell spread. Supply contracts carry delivery quantities, deadlines, payouts, and refundable deposits that are forfeited on failure. |
| Daily simulation and recovery | Explicit shift advancement applies production, staffing, transport/storage limits, finite reserves, wear, business income, payroll/upkeep, credit interest, market movement, and contract expiry. Credit and insolvency restructuring provide recovery actions. |
| Save protection | `lib/src/save_store.dart` validates versioned, bounded save data, serializes writes, retains a previous good save, and supports export/restore. `app.dart` guards destructive replacement and reports failed writes before leaving. |
| Mobile interface | `lib/src/ui/tycoon_game_page.dart` supplies Operations, Exchange, Fleet, and Company tabs plus responsive rail navigation. `oil_field_scene.dart` draws the animated field, with reduced-motion support. |

Paths in this table are relative to `games/oil_gas_tycoon/`. Trading is a
single-player virtual market. Online player trading, cloud save synchronization,
multiplayer, real asset ownership, real-money billing, and store publication are
not represented as completed features of this implementation.

### Reusable visual material

The repository already contains local industrial SVG artwork, including drilling
rig sites, trucks, pumps, tanks, yards, generators, and business imagery. Example
sources include:

- `assets/images/industrial_icons/06-sites-and-logistics/03-drilling-rig-site.svg`
- `assets/images/industrial_icons/05-commercial-vehicles/01-semi-truck.svg`
- `assets/images/industrial_icons/05-commercial-vehicles/04-pickup-flatbed-truck.svg`
- `assets/images/industrial_icons/14-drilling-and-well-control/10-mud-pump.svg`
- `assets/images/industrial_icons/06-sites-and-logistics/08-storage-yard.svg`

These are available for intentional reuse alongside original game visuals.
Their presence does not mean the initial repository contained game artwork,
animations, an interactive field, or a complete game interface.

## Pre-existing marketplace work and release limitations

The following concerns belong to Pipe Buyer's real-commerce application. They
are not missing tycoon simulation mechanics and should not be silently enabled
as part of a game build.

| Area | Evidence and implication |
| --- | --- |
| Native signing and device acceptance | `docs/MOBILE_RELEASE_AND_ACCESSIBILITY.md` explicitly treats signing, store validation, and physical-device acceptance as separate release gates. A successful mobile web or unsigned build is insufficient evidence of App Store/Google Play readiness. |
| Native paid memberships | `firebase/functions/production_bootstrap.js` deliberately leaves native purchase-verification/reconciliation handlers unexported pending store credentials/readiness; status querying exists. Do not claim native billing activation from the client UI alone. |
| Regulated property/rights/business sales | README and `docs/ENGINEERING_CONTROL_BASELINE.md` describe design-only policies and disabled real publishing pending jurisdictional prerequisites. Fictional game assets use separate models. |
| Dispatch job charging | The launch-readiness audit identifies a separate freight-specific financial ledger as required before actual per-job charging/settlement. Membership monetization is a separate workflow. |
| Recent unmerged changes | Draft PR #212 contains marketplace/timed-buying hardening outside this game's scope. Its changes and acceptance remain independently reviewable. |
| Historical readiness percentages | `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md` explicitly warns that older phase percentages are superseded. This report does not reuse them as current completion claims. |

## Verification requirements and evidence boundary

No production journeys were executed during the source audit. The release
contracts, existing Flutter tests, and independent game diagnostics below were
subsequently run locally. Source findings and runtime results are recorded
separately; additional release acceptance must retain its own commands and
results.

### Observed verification

#### Existing release contracts

On 2026-10-20, Node 24.19.0 executed the following command successfully:

```sh
node --test --test-isolation=none \
  tool/oauth_branding_test.mjs \
  tool/release_manifest_test.mjs \
  tool/function_parity_test.mjs \
  tool/phase1_acceptance_test.mjs \
  tool/prepare_phase1_acceptance_test.mjs \
  tool/configure_firebase_messaging_worker_test.mjs
```

Result: **32 individual subtests passed; 0 failed, skipped, or cancelled.** The
non-isolated mode was used because this local runtime's default isolated runner
reported file-level successes without reporting the individual tests. Direct
execution and non-isolated execution established that the actual assertions ran.
These checks validate branding, release metadata, Function inventory comparison,
acceptance-evidence rules, and messaging-worker configuration. They do not
exercise live Functions, payment providers, physical devices, or the new game.

#### Existing Flutter regression suite

The complete root `test/` suite passed after integrating the game dependency and
navigation, using Flutter 3.44.6 and Dart 3.12.2:

```sh
flutter test --no-pub \
  --dart-define=PIPE_ENV=local-verification \
  --dart-define=PIPE_RELEASE_SHA=b7c479ee1d359d50c8470de8c9009efb29df38c5 \
  --reporter expanded
```

Result: **553 tests passed; process exit code 0**, in approximately 1 minute
55 seconds. This was the entire existing root Flutter suite, not a selected
subset. A font-asset declaration initially blocked test startup; correcting the
root app's declarations to `games/oil_gas_tycoon/assets/fonts/Roboto-*.ttf`
resolved that setup issue before the successful run. The standalone package
keeps its own package-relative font declarations.

These are local unit, widget, and source-contract checks. They do not establish
live backend acceptance, production payment behavior, or native device release
readiness. The game package maintains a separate test suite under
`games/oil_gas_tycoon/test/`.

#### Standalone game analysis and regression suite

The complete game package was analyzed and tested with Flutter 3.44.6 and
Dart 3.12.2, from `games/oil_gas_tycoon/`:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

Result: **analysis reported no issues; all 61 game tests passed**, with the
combined test run completing in approximately 12 seconds.

| Test file | Passed | Coverage represented |
| --- | ---: | --- |
| `test/tycoon_engine_test.dart` | 34 | Economic transactions, production constraints, contracts, progression, insolvency, validated state, treasury bounds, and seeded full careers. |
| `test/save_store_test.dart` | 10 | Exact save round trips, serialized snapshots, corrupt-save recovery, failed writes, portable backups, and invalid import rejection. |
| `test/app_host_test.dart` | 8 | Named company creation/resume, restore/reset decisions, failed-save exit choices, blocked interactions during restore, and embedded system Back. |
| `test/tycoon_game_page_test.dart` | 9 | Production/trading actions, invalid quantities, navigation, destructive-action cancellation, responsive layouts, and the Licenses screen. |

The host tests include a slow restore while touch, keyboard, and lifecycle events
occur. They verify that an old session cannot replace the newly restored save.
They also verify that a failed save does not silently close the embedded game:
the player can keep playing, export current progress, or explicitly leave.

#### Release web build and actual offline gameplay

The standalone release was built and its local offline bundle prepared with:

```sh
flutter build web --release --no-pub --no-web-resources-cdn --pwa-strategy=none
node tool/prepare_offline_web.mjs
```

Result: **web compilation succeeded in 57.1 seconds**. Offline preparation
included **41 files, approximately 41.2 MiB**, including the renderer and bundled
fonts. The preparation script checks that the canonical Roboto family is
available locally; this prevents the external startup font request discovered
in the first browser build. The corrected theme also explicitly names the
bundled font for button labels.

An actual Chromium walkthrough used a **390 × 844 mobile viewport**, then a
**1440 × 900 desktop viewport**. It created `Frontier Energy`, exercised visible
game controls, inspected the saved state, reloaded, disabled browser networking,
and continued playing from the offline cache:

| Verified step | Recorded state or result |
| --- | --- |
| Run the first shift | Day 2; 160 bbl in storage; cash 154,245. |
| Sell 100 bbl through the Exchange | Day 2; 60 bbl remain; cash 166,945. The cash change includes the earned milestone reward as well as the commodity sale. |
| Reload while online | Exact equality with the complete saved company state after the sale. |
| Disable networking and reload | The game reopens from its installed cache and restores the same saved state exactly. |
| Run another shift while offline | Day 3; 216 bbl in storage, representing 156 additional bbl; cash 166,190. |
| Browser/resource checks | 41 cached files; zero page errors, zero failed requests, and zero external resource requests during the completed walkthrough. |

This establishes a functioning production → sale → save/resume → offline
production cycle in the tested browser, after its initial cache installation.
It does not establish offline readiness before that first installation, immunity
to browser cache eviction, or acceptance on every browser/device. The exercised
company name and interface were English; optional browser font fallback for
characters outside the bundled font was not part of this check.

#### Android compilation and native release boundary

The standalone Android ARM64 profile build completed successfully with Flutter
3.44.6, Java 17, Android SDK platforms 35/36, and the required native build tools:

```sh
flutter build apk --profile --target-platform android-arm64 --no-pub
```

Result: **the build succeeded in 97.1 seconds; Flutter reported a 28.6 MB APK**.
The profile configuration is a local preview build, uses
`com.pipebuyer.oil_gas_tycoon.preview`, and remains separate from the release
application ID. The Android configuration requires a private release keystore
before creating a release build; no production signing key is included in source.
Artifact signature, exact size, and checksum checks belong to the delivery
record for the final regenerated installer.

**No physical Android installation or iOS compilation was executed as part of
these recorded checks.** iOS still requires macOS/Xcode, appropriate signing for
physical installation, and device acceptance. The manual
`.github/workflows/tycoon-game.yml` provides repeatable analysis/tests, web
packaging, an optional Android profile build, and an optional unsigned iOS
compile. It does not publish to either app store.

#### Independent game economy review

After the engine was implemented, an independent Dart diagnostic exercised
**six seeded careers for 800 shifts each: 4,800 completed shifts**. Seeds were
`1`, `2`, `7`, `366`, `123456`, and `2147483645`. It encoded and decoded the
complete state after every shift, checked exact JSON round trips and unchanged
net-worth calculations, and checked that oil/gas inventory remained between zero
and storage capacity. All six companies reached the implemented tycoon career
goal without requiring restructuring.

The scripted strategy sold stored production each day, bought and upgraded
businesses while preserving a 20,000 cash buffer, hired one mechanic, repaired
assets below 65% condition when a 15,000 buffer remained, and added developed
leases with compatible equipment and operators once sufficient cash existed.
It bought a heavy-haul fleet and hired a driver as the field expanded. It did not
depend on loans, supply contracts, modified cash, or manually completed goals.
This establishes a reachable career path and long-horizon save consistency; it
does not establish player enjoyment, ideal balance, or a fastest winning strategy.

The diagnostic also established that invalid quantities, duplicate lease
acquisition/development, nonexistent contract delivery, invalid repayment, and
incompatible equipment assignment failed without changing the serialized state.
An imported save at the maximum permitted ID counter initially produced an
unreadable next save after a purchase. The allocator was repaired to wrap and
skip existing IDs; the purchase-and-round-trip reproduction then passed.

Independent review also identified lease resale, condition-adjusted automatic
fleet selection, wear on unstaffed vehicles, and mechanic training benefits as
areas needing completion or correction. Those were passed to the engine author
for implementation and regression coverage in
`games/oil_gas_tycoon/test/tycoon_engine_test.dart`. A retained career progression
test is included there so the growth behavior can be rerun from the repository.

#### Independent mobile layout review

Five Flutter widget stress configurations passed after repairs:

| Viewport | Text scale | Checked surfaces |
| --- | --- | --- |
| 320 × 720 | 2× | All four game tabs, well assignment, commodity buying, borrowing, and settings. |
| 390 × 844 | 2× | Same surfaces. |
| 800 × 360, landscape | 1× | Same surfaces. |
| 800 × 360, landscape | 2× | Same surfaces. |
| 1024 × 768 | 2× | Same surfaces with navigation rail. |

Result: **5/5 configurations passed with no captured Flutter exceptions.** The
checks used a long company name and disabled animations to make layout checks
deterministic. They opened and cancelled dialogs; separate behavioral tests
establish transaction outcomes.

The initial checks caught an overflowing oilfield status badge at 320 pixels and
Material/ink assertions from expandable company panels. The badge was constrained
and panels were changed to Material surfaces; the same checks then passed. The
company ledger was also corrected to show the newest entries first, matching the
engine's insertion order.

The package's committed widget tests are in
`games/oil_gas_tycoon/test/tycoon_game_page_test.dart`. These simulated viewports
do not replace physical Android/iOS testing, device keyboard checks, store
signing, or accessibility testing with native assistive technology.

The existing `tool/verify.ps1` defines dependency restore, Dart analysis, Flutter
tests, OAuth/release-manifest/Function-parity/acceptance-control tests, Functions
and agent-Functions checks, dependency audit, Firestore/Storage rules emulators,
authenticated callable integration, web release build, and release-manifest
generation. Its deployment step is separate from verification.

The local tests and browser walkthrough establish the following game behavior;
physical-device and store acceptance remain separate:

- A playable cycle from company creation to lease/equipment acquisition, hiring,
  production, sales, operating costs, and progression.
- Cash and inventory invariants; affordability failures; finite, bounded
  quantities; no duplicate purchase or sale exploits.
- Day advancement settling production, payroll, upkeep, and contracts exactly
  once while respecting staffing/capacity requirements.
- Equipment, vehicle, business, employee, and lease transactions influencing
  the economy as shown by the interface.
- Save/reload consistency, invalid-save recovery, and an explicit reset decision.
- No unrecoverable accidental early-game soft lock from ordinary play.
- Narrow-phone layouts, readable controls, navigation, and relevant large-text
  behavior without overflow.
- Standalone compilation, plus root route/import and navigation verification.

### Publication status

The delivered source implements a playable single-player game, with passing
local regression checks, verified browser save/offline gameplay, and a successful
Android profile compilation. This audit does not certify an App Store listing,
Google Play release, multiplayer economy, online player trading, or store
billing. Production signing, store configuration, and physical-device acceptance
remain separate work and must be recorded when performed. The game accurately
states that its economy and trading are a single-player simulation.
