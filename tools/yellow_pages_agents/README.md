# PipeBuyer Oilfield Directory — Global & North America Multi-Agent Crawler Suite

This suite discovers, cross-references, live-audits (`Old Number -> New Number` + DNS/HTTP liveness + phone/website verification), and publishes **Worldwide (197-Country)** Oil & Gas service, OCTG/pipe, midstream, marine/offshore, and EPCM companies for the **PipeBuyer Oilfield Directory** (`/services`).

## Live Production Coverage (`flutter-flow-pipe`)
- **Worldwide Public Active Providers:** `63,134` across **`30` Oil & Gas Service Sectors**, **`107` Countries**, **`172` Sub-Regions**, and **`3,625` Canonical Towns** (`0` pre-verified; `0` non-canonical city spellings; `0` empty-region hub splits)
  - **North America (`CA`, `US`, `MX`, `TT`, Caribbean & Central America):** `55,020` active public entries (including `6,540` Global **Oil & Gas Training Facilities & Courses** and `721` Global **Crew Hotels, Extended-Stay & Oilfield Worker Rates**)
  - **Asia (`MY`, `SG`, `IN`, `ID`, `KZ`, `TH`, `BN`, `AZ`, `VN`, `CN`, `JP`, `KR`, etc.):** `3,428` active public entries
  - **Europe (`GB`, `NO`, `NL`, `DE`, `IT`, `GR`, `FR`, `AT`, `CH`, `ES`, `DK`, `RO`, `PL`, etc.):** `2,009` active public entries
  - **Middle East (`AE`, `SA`, `OM`, `QA`, `BH`, `KW`, `EG`, `TR`, `IL`, `IQ`, `JO`):** `1,859` active public entries
  - **Africa (`NG`, `GH`, `ZA`, `EG`, `NA`, `UG`, `AO`, `DZ`, `CI`, `MZ`, `TZ`, `GA`, `SN`, `CG`, `LY`, etc.):** `1,594` active public entries
  - **Australia & Oceania (`AU`, `NZ`, `PG`):** `753` active public entries
  - **South America (`BR`, `AR`, `CO`, `GY`, `PE`, `EC`, `SR`, `CL`, `BO`, etc.):** `561` active public entries

## Bot & Daemon Inventory

### North America Baseline Suite (`Bot 1` – `Bot 8`)
1. **`overnight_master_crawler.mjs` (Continuous 100% Full-Universe Daemon)** — Loops `Bot 1`–`Bot 8` with atomic crash-safe checkpoints until 100% of North American candidates are audited.
2. **`bot1_firestore_inventory.mjs`** — Read-only Staging (`pipebuyer-5c77f`) & Production (`flutter-flow-pipe`) Firestore inventory.
3. **`bot2_cossd_north_america_discovery.mjs`** — Catalogs `17,945` `cossd.com` profiles (excluding non-oilfield businesses and directory ad links) with resumable checkpoints.
4. **`bot3_live_operations_phone_auditor.mjs`** — Cross-merges discovery ledgers, maintains persistent corporate hostname DNS/HTTP liveness cache, catches `Old Number -> New Number` transitions, and blocks dead/liquidated domains.
5. **`bot4_book_drive_page_auditor.mjs`** — Vision OCR & SHA-256 page tracker for the **2015/2016 COSSD Physical Yellow Book** archive.
6. **`bot5_firestore_publisher_sync.mjs`** — Streams `05_private_companies.jsonl` & `05_public_entries.jsonl` (`--dry-run` default; `--apply --project <id>` for Firestore batch-commit).
7. **`bot6_open_web_oil_gas_crawler.mjs`** — Crawls **8 US & Canadian SEC EDGAR Oilfield/Pipe/Valve/Pipeline SICs** (`1381`, `1382`, `1389`, `3533`, `3317`, `3490`, `4610`, `4922`), WCSB/Permian/Bakken/Appalachia/Gulf Coast corporate sites, and OpenStreetMap Overpass.
8. **`bot7_usdot_fmcsa_oilfield_carriers.mjs`** — Crawls the federal **USDOT / FMCSA Active Company Census** (`data.transportation.gov`) for active Oilfield Equipment, Pipe, Heavy Machinery, and Fluid/Tank fleets.
9. **`bot8_energy_regulator_registries.mjs`** — Crawls **Texas Comptroller Active Oil & Gas NAICS** + **City of Edmonton & City of Calgary Active Commercial Oilfield Licences**.

### Global 197-Country Discovery, Deep-Fill & Verification Suite (`Bot 9` – `Bot 12`)
10. **`global_shared_utils.mjs`** — Shared 197-country sovereign catalog (`countries-ofthe-world.com` continents + `Middle East`), international dial-code phone parser, Oil & Gas strict relevance classifier, category mapper, corporate website `/contact` HTML auditor, and dual-collection (`yellow_pages_companies` + `yellow_pages_entries`) Firestore publisher.
11. **`bot9_global_country_crawler.mjs`** — **Sequential Country-by-Country Crawler, Live Auditor & Firestore Auto-Publisher** across all 189 active international sovereign countries (skipping OFAC/sanctioned jurisdictions), executing Wave 1 (`North America` remaining), Wave 2 (`Global Oil & Gas Hubs`), and Wave 3 (`Remaining Sovereign Countries A–Z`).
12. **`bot10_global_deep_fill_agents.mjs`** — **Global Deep-Fill Multi-Channel Orchestrator** running 4 specialized sub-agents:
    - `Agent 10A`: SEC EDGAR Foreign Oilfield/Pipe/Valve/Drilling/Midstream Registrants (`8` SICs)
    - `Agent 10B`: Wikipedia + Wikidata REST Global Oilfield Services & Country Energy Tree
    - `Agent 10C`: Multi-Hub × 12-Vertical Open-Web Corporate Domain Crawler (`100+` international oilpatch cities)
    - `Agent 10D`: Regional Oilfield Supply Base & Contractor Verification Wave
13. **`bot11_wikidata_and_phone_unlock.mjs`** — **Wikidata SPARQL Global Petroleum/Oilfield Entity Resolver & Deep Contact Phone Unlock Agent** (`P17` country, `P856` official website, `P1329` phone, `P159` HQ city + deep `/contact-us`, `/locations`, `/impressum`, `tel:` & JSON-LD `telephone` extraction).
14. **`bot12_basin_hub_boost.mjs`** — **Global Oil & Gas Basin Hub Booster** targeting 25+ international energy basins (`North Sea`, `Arabian Gulf`, `Santos/Campos`, `Guyana-Suriname`, `Vaca Muerta`, `Burgos/Campeche`, `Niger Delta`, `North West Shelf`, `Bombay High`, `Caspian`, `Mediterranean`).
15. **`bot13_directory_facet_counts.mjs`** — **Live Directory Area & Town Business Counts Indexer** canonicalizing town/city spellings + backfilling international sub-region codes across `yellow_pages_public_entries` & `yellow_pages_companies` and publishing `yellow_pages_meta/directory_counts` across all **`30` service sectors** (including **Oil & Gas Training Facilities & Courses** and **Crew Hotels, Extended-Stay & Oilfield Worker Rates**).
16. **`bot14_reset_preverified_status.mjs`** — **Zero Pre-Verification Enforcer** ensuring crawled/seeded listings remain `unverified` (`free_basic`, `verified: false`) while preserving live public visibility and reserving the green checkmark badge strictly for genuinely verified/paid businesses.
17. **`bot15_full_consistency_auditor.mjs`** — **Full Directory Field Consistency & Global Town/Region Consolidation Auditor** consolidating county/MD/RM/USDOT/FMCSA/diacritic town variants (`Co of GrandPr` -> `Grande Prairie`, `Fort Saint John` -> `Fort St. John`, `Macaé` -> `Macae`, `Watford` -> `Watford City`, etc.), eliminating empty-region international hub splits via `inferRegionFromCountryAndCity`, recovering missing `city` / `regionCode` / `countryCode` via NANPA area & exchange codes, normalizing ALL-CAPS company names, backfilling `basins`, and tagging **Oil & Gas Training** + the 5 expanded Yellow Pages sectors.
18. **`bot16_google_alphabetical_audit_fleet.mjs`** — **Parallel Google Maps Alphabetical (`A–Z`) & Training Discovery Fleet** sweeping North America (`Canada` + `USA`) and 6 International Corridors (`UK/Norway`, `Middle East`, `Latin America`, `Australia`, `Africa`, `Asia-Caspian`) alphabetically (`A -> Z`), across sectors, and across **Oil & Gas Training Facilities & Courses** (`H2S Alive`, `IWCF / IADC WellSharp`, `OPITO / BOSIET`, `PEC SafeLand`, `PETRONAS / NIOSH`, `NCDMB`).
19. **`bot17_microtown_atlas_planner.mjs`** — **North America (`CA -> US`) Micro-Town Atlas & Adaptive 4-Stage Frontier Planner** combining `680+` curated unlisted oilpatch micro-towns with `2,670+` proven database towns and dynamically mined rural street-address towns, escalating productive micro-towns across `PROBE -> SECTOR_SWEEP -> ALPHA_SWEEP -> EXTENDED_TAIL -> EXHAUSTED`.
20. **`bot18_exhaustive_microtown_harvester.mjs`** — **12-Agent Parallel Google Maps Micro-Town Harvester & True-Town Geo-Resolver** executing memory-bounded waves (`450` queries/wave), preventing intra-state zoom-out city misattribution via `KNOWN_TOWNS_BY_REGION`, and streaming unverified (`verified: false`) Oil & Gas + Training listings live to Firestore.
21. **`bot19_run_until_exhausted_supervisor.mjs`** — **Autonomous Run-Until-Zero-New-Yield Convergence Supervisor** looping `Bot 17 -> Bot 18 -> Bot 13` in isolated child processes until every North American micro-town converges to `0` pending queries / `0` new businesses.
22. **`bot20_global_completion_pipeline.mjs`** — **End-to-End Global Completion Supervisor** orchestrating North America Micro-Town Convergence (`Bot 19`), International 6-Corridor Alphabetical + Training Sweeps (`Bot 16 --scope international`), `Bot 15` Consistency Audit, and `Bot 13` Facet Sync.
23. **`bot21_crew_hotels_oilfield_lodging_fleet.mjs`** — **20-Agent Parallel Oil & Gas Crew Hotels, Workforce Lodging & New Sector Gap-Fill Fleet** auditing `186` North American & International oilpatch, turnaround, and offshore heliport crew hubs for **Crew Hotels, Extended-Stay Suites & Oilfield Worker-Rate Motels** (`crew_hotels_workforce_lodging` — CLC Lodging partners, kitchenette suites, rig-worker motor inns; strictly blocking tourist B&Bs, resorts, hostels, RV parks, pet hotels, and residential apartments) plus targeted Tier-1 hub top-ups for `scaffolding_insulation_coatings`, `marine_offshore_aviation`, `industrial_supply_ppe_workwear`, and `lease_security_communications_it`.
24. **`verify_global_live_counts.mjs`** — Live production verification harness calling `searchPipeBuyerYellowPages` across Worldwide, all 7 World Regions, and 45+ Popular Oil & Gas Countries.

## Usage

```powershell
# 1. Global Country-by-Country Crawl & Live Auto-Publish (189 active international countries)
node tools/yellow_pages_agents/bot9_global_country_crawler.mjs --apply --project flutter-flow-pipe --concurrency 8

# 2. Global Deep-Fill Multi-Agent Suite (SEC EDGAR + Wikidata + 100-Hub Verticals + Regional Contractors)
node tools/yellow_pages_agents/bot10_global_deep_fill_agents.mjs --apply --project flutter-flow-pipe

# 3. Wikidata SPARQL Global Energy Sweep + Contact Subpage Phone Unlock
node tools/yellow_pages_agents/bot11_wikidata_and_phone_unlock.mjs --apply --project flutter-flow-pipe

# 4. International Basin Hub Boost
node tools/yellow_pages_agents/bot12_basin_hub_boost.mjs --apply --project flutter-flow-pipe

# 5. Canonicalize Town Spellings & Publish Live Area/Town Counts Index
node tools/yellow_pages_agents/bot13_directory_facet_counts.mjs --apply --fix-cities --project flutter-flow-pipe

# 6. Autonomous North America Micro-Town Exhaustive Convergence Loop (Canada -> USA until 0 new yield)
node tools/yellow_pages_agents/bot19_run_until_exhausted_supervisor.mjs --agents 12 --wave-size 450 --project flutter-flow-pipe

# 7. Live Production Verification Smoke Suite
node tools/yellow_pages_agents/verify_global_live_counts.mjs
```
