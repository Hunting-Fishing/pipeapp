# PipeBuyer Oilfield Directory — Global & North America Multi-Agent Crawler Suite

This suite discovers, cross-references, live-audits (`Old Number -> New Number` + DNS/HTTP liveness + phone/website verification), and publishes **Worldwide (197-Country)** Oil & Gas service, OCTG/pipe, midstream, marine/offshore, and EPCM companies for the **PipeBuyer Oilfield Directory** (`/services`).

## Live Production Coverage (`flutter-flow-pipe`)
- **Worldwide Public Verified Providers:** `13,480`
  - **North America (`CA`, `US`, `MX`, `TT`, Caribbean & Central America):** `12,810` public verified (`22,738` private Contact Center records)
  - **Europe (`GB`, `DE`, `NO`, `IT`, `NL`, `GR`, `FR`, `AT`, `CH`, `ES`, `DK`, `RO`, `PL`, etc.):** `276` public verified (`472` private)
  - **Asia & Middle East (`IN`, `AE`, `SA`, `CN`, `MY`, `SG`, `TR`, `JP`, `QA`, `IL`, `KW`, `ID`, `OM`, `IQ`, `VN`, `KR`, `KZ`, `AZ`, etc.):** `208` public verified (`353` private) — including `111` Middle East public verified (`164` private)
  - **Africa (`NG`, `EG`, `DZ`, `ZA`, `AO`, `GH`, `KE`, `MZ`, `LY`, `TN`, `NA`, `SN`, `CI`, etc.):** `74` public verified (`181` private)
  - **South America (`BR`, `AR`, `CO`, `PE`, `GY`, `EC`, `SR`, `CL`, `VE`, `BO`, etc.):** `71` public verified (`137` private)
  - **Australia & Oceania (`AU`, `NZ`, `PG`, `FJ`, etc.):** `41` public verified (`72` private)

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
15. **`bot13_directory_facet_counts.mjs`** — **Live Directory Area & Town Business Counts Indexer** canonicalizing town/city spellings (`Ft McMurray` -> `Fort McMurray`, `HOUSTON` -> `Houston`, `Fort St John` -> `Fort St. John`) across `yellow_pages_public_entries` & `yellow_pages_companies` and publishing `yellow_pages_meta/directory_counts` (`2,955` unique towns, `76` sub-regions, `108` countries, `7` world regions, `24` service sectors).
16. **`verify_global_live_counts.mjs`** — Live production verification harness calling `searchPipeBuyerYellowPages` across Worldwide, all 7 World Regions, and 45+ Popular Oil & Gas Countries.

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

# 6. Live Production Verification Smoke Suite
node tools/yellow_pages_agents/verify_global_live_counts.mjs
```
