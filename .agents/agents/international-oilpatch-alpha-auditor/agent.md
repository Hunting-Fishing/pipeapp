---
name: international-oilpatch-alpha-auditor
description: 18-Worker Parallel Google Maps International Oil & Gas + Accredited Training (OPITO / BOSIET / IWCF / IADC) Alphabetical & Sector Audit Agent covering UK/Norway & North Sea, Middle East, Latin America, and Australia.
---

# International Oil & Gas & Training Alphabetical (A–Z) Audit Fleet

- **Primary Fleet Engine**: `tools/yellow_pages_agents/bot16_google_alphabetical_audit_fleet.mjs --scope international --sync --agents 18`
- **Global Pipeline Supervisor**: `tools/yellow_pages_agents/bot20_global_completion_pipeline.mjs`
- **Field Hygiene & Consistency Engine**: `tools/yellow_pages_agents/bot15_full_consistency_auditor.mjs`
- **Facet Count Indexer**: `tools/yellow_pages_agents/bot13_directory_facet_counts.mjs`

## Global Corridors Covered (122 International Hubs)
1. **UK / Norway & North Sea (`--corridor uk_norway`)**: `GB` (`Aberdeen`, `Dyce`, `Westhill`, `Altens`, `Peterhead`, `Montrose`, `Dundee`, `Great Yarmouth`, `Lowestoft`, `Middlesbrough`, `Newcastle upon Tyne`), `NO` (`Stavanger`, `Tananger`, `Forus`, `Sandnes`, `Bergen`, `Ågotnes`, `Oslo`, `Kristiansund`, `Hammerfest`), `NL` (`Rotterdam`, `Den Helder`, `IJmuiden`, `Emmen`), `DE` (`Celle`).
2. **Middle East (`--corridor middle_east`)**: `AE` (`Abu Dhabi`, `Mussafah`, `Ruwais`, `Dubai`, `Jebel Ali`, `Sharjah`, `Hamriyah`, `Fujairah`), `SA` (`Dammam`, `Al Khobar`, `Dhahran`, `Jubail`, `Yanbu`, `Riyadh`, `Jeddah`), `QA` (`Doha`, `Ras Laffan`, `Mesaieed`), `OM` (`Muscat`, `Sohar`, `Duqm`, `Nizwa`), `KW` (`Ahmadi`, `Kuwait City`, `Shuaiba`), `BH` (`Manama`, `Sitra`).
3. **Latin America (`--corridor latin_america`)**: `BR` (`Macaé`, `Rio de Janeiro`, `Niterói`, `Santos`, `Vitória`), `MX` (`Villahermosa`, `Paraíso`, `Ciudad del Carmen`, `Reynosa`, `Tampico`, `Coatzacoalcos`, `Poza Rica`), `AR` (`Neuquén`, `Añelo`, `Comodoro Rivadavia`), `CO` (`Bogotá`, `Barrancabermeja`, `Yopal`), `GY` (`Georgetown`), `TT` (`San Fernando`, `Point Lisas`, `Port of Spain`).
4. **Australia (`--corridor australia`)**: `AU` (`Perth`, `Welshpool`, `Henderson`, `Karratha`, `Dampier`, `Port Hedland`, `Brisbane`, `Toowoomba`, `Roma`, `Gladstone`, `Darwin`, `Adelaide`, `Moomba`, `Sale`, `Melbourne`).

## Strict Hygiene & Anti-Zoom-Out Rules
- Validates ITU country dial codes (`+44`, `+47`, `+31`, `+49`, `+971`, `+966`, `+974`, `+968`, `+965`, `+973`, `+55`, `+52`, `+54`, `+57`, `+592`, `+1 868`, `+61`) and resolves intra-country zoom-outs to their true canonical city & sub-region.
- Classifies offshore & onshore safety academies (`OPITO`, `BOSIET`, `FOET`, `HUET`, `IWCF`, `IADC WellSharp`, `IRATA`, `CBSP`) into `oil_gas_training_courses`.
- Never pre-verifies scraped records (`verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`).
