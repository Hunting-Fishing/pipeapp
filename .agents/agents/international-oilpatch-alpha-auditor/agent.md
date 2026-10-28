---
name: international-oilpatch-alpha-auditor
description: 20-Worker Parallel Google Maps International Oil & Gas + Accredited Training (OPITO / BOSIET / IWCF / IADC / PETRONAS / NCDMB) Alphabetical & Sector Audit Agent covering UK/Norway & North Sea, Middle East, Latin America, Australia, Africa, and Southeast/South/Central Asia.
---

# International Oil & Gas & Training Alphabetical (A–Z) Audit Fleet

- **Primary Fleet Engine**: `tools/yellow_pages_agents/bot16_google_alphabetical_audit_fleet.mjs --scope international --sync --agents 20`
- **Global Pipeline Supervisor**: `tools/yellow_pages_agents/bot20_global_completion_pipeline.mjs`
- **Field Hygiene & Consistency Engine**: `tools/yellow_pages_agents/bot15_full_consistency_auditor.mjs`
- **Facet Count Indexer**: `tools/yellow_pages_agents/bot13_directory_facet_counts.mjs`

## Global Corridors Covered (194 International Hubs across 41 Countries)
1. **UK / Norway & North Sea (`--corridor uk_norway`)**: `GB` (`Aberdeen`, `Dyce`, `Westhill`, `Altens`, `Peterhead`, `Montrose`, `Dundee`, `Great Yarmouth`, `Lowestoft`, `Middlesbrough`, `Newcastle upon Tyne`), `NO` (`Stavanger`, `Tananger`, `Forus`, `Sandnes`, `Bergen`, `Ågotnes`, `Oslo`, `Kristiansund`, `Hammerfest`), `NL` (`Rotterdam`, `Den Helder`, `IJmuiden`, `Emmen`), `DE` (`Celle`).
2. **Middle East (`--corridor middle_east`)**: `AE` (`Abu Dhabi`, `Mussafah`, `Ruwais`, `Dubai`, `Jebel Ali`, `Sharjah`, `Hamriyah`, `Fujairah`), `SA` (`Dammam`, `Al Khobar`, `Dhahran`, `Jubail`, `Yanbu`, `Riyadh`, `Jeddah`), `QA` (`Doha`, `Ras Laffan`, `Mesaieed`), `OM` (`Muscat`, `Sohar`, `Duqm`, `Nizwa`), `KW` (`Ahmadi`, `Kuwait City`, `Shuaiba`), `BH` (`Manama`, `Sitra`).
3. **Latin America & Caribbean (`--corridor latin_america`)**: `BR` (`Macaé`, `Rio de Janeiro`, `Niterói`, `Santos`, `Vitória`), `MX` (`Villahermosa`, `Paraíso`, `Ciudad del Carmen`, `Reynosa`, `Tampico`, `Coatzacoalcos`, `Poza Rica`), `AR` (`Neuquén`, `Añelo`, `Comodoro Rivadavia`), `CO` (`Bogotá`, `Barrancabermeja`, `Yopal`), `GY` (`Georgetown`), `TT` (`San Fernando`, `Point Lisas`, `Port of Spain`).
4. **Australia (`--corridor australia`)**: `AU` (`Perth`, `Welshpool`, `Henderson`, `Karratha`, `Dampier`, `Port Hedland`, `Brisbane`, `Toowoomba`, `Roma`, `Gladstone`, `Darwin`, `Adelaide`, `Moomba`, `Sale`, `Melbourne`).
5. **Africa (`--corridor africa`)**: `NG` (`Port Harcourt`, `Onne`, `Lagos`, `Warri`, `Eket`, `Abuja`), `AO` (`Luanda`, `Cabinda`, `Soyo`, `Lobito`), `EG` (`Cairo`, `Alexandria`, `Suez`, `Port Said`, `Ras Gharib`), `GH` (`Takoradi`, `Accra`, `Tema`), `DZ` (`Hassi Messaoud`, `Algiers`, `Oran`), `ZA` (`Cape Town`, `Durban`, `Johannesburg`), `NA` (`Walvis Bay`, `Lüderitz`, `Windhoek`), `MZ` (`Maputo`, `Pemba`), `GA` (`Port-Gentil`, `Libreville`), `CG` (`Pointe-Noire`), `CI` (`Abidjan`), `SN` (`Dakar`), `UG` (`Kampala`), `TZ` (`Dar es Salaam`), `LY` (`Tripoli`).
6. **Southeast, South & Central Asia (`--corridor asia_caspian`)**: `SG` (`Singapore`, `Tuas`, `Jurong`, `Loyang`), `MY` (`Kuala Lumpur`, `Shah Alam`, `Miri`, `Bintulu`, `Labuan`, `Kota Kinabalu`, `Kemaman`, `Johor Bahru`), `ID` (`Jakarta`, `Balikpapan`, `Batam`, `Duri`, `Pekanbaru`, `Surabaya`), `BN` (`Kuala Belait`, `Bandar Seri Begawan`), `TH` (`Rayong`, `Songkhla`, `Bangkok`), `VN` (`Vung Tau`, `Ho Chi Minh City`), `KZ` (`Atyrau`, `Aktau`, `Uralsk`, `Almaty`), `AZ` (`Baku`, `Sumqayit`), `IN` (`Mumbai`, `Kakinada`, `Vadodara`, `Duliajan`).

## Strict Hygiene & Anti-Zoom-Out Rules
- Validates ITU country dial codes across all 41 international jurisdictions (including Kazakhstan `+7 7xx` / CIS `8 (7xx)` separation from Russian `+7` and Trinidad `+1 868`) and resolves intra-country zoom-outs to their true canonical city & sub-region.
- Classifies offshore & onshore safety academies (`OPITO`, `BOSIET`, `T-BOSIET`, `FOET`, `HUET`, `IWCF`, `IADC WellSharp`, `IRATA`, `CBSP`, `PETRONAS / NIOSH`, `MIGAS / BNSP`) into `oil_gas_training_courses`.
- Never pre-verifies scraped records (`verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`).
