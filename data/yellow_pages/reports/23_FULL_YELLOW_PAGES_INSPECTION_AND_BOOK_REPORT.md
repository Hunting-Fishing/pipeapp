# Full Yellow Pages Deep Inspection & 73-Image COSSD Book Cross-Reference Report

**Generated:** `2026-11-06`  |  **Production Project:** `flutter-flow-pipe` (`https://pipebuyer.com`)

## 1. Executive Summary

| Inspection Domain | Metric | Verified Result | Notes |
| :--- | :--- | ---: | :--- |
| **Google Drive Book (`OIL FIELD BOOK`)** | Total Drive Photos Cross-Referenced | **73 / 73 (100%)** | Every single image rotated upright & split into top/bottom tiles |
| **Google Drive Book (`OIL FIELD BOOK`)** | Half-Page High-Res Tiles Audited | **146 / 146 (100%)** | `0` missed tiles, `0` corrupt JSONL lines |
| **Google Drive Book (`OIL FIELD BOOK`)** | Raw Transcribed Rows | **14,919** | Includes `963` tile-overlap / duplicate-page rows deduplicated before diff |
| **Google Drive Book (`OIL FIELD BOOK`)** | Unique Book Listings Cross-Referenced | **13,956** | Every unique company + phone + city listing across all 73 pages |
| **Google Drive Book (`OIL FIELD BOOK`)** | Matched Pre-Existing Website Listings | **3,495** | Already on `pipebuyer.com` (by current phone, legacy phone, or canonical/stem name) |
| **Google Drive Book (`OIL FIELD BOOK`)** | Matched Listings Enriched From Book | **79** | Missing email, website, toll-free phone, or street address backfilled |
| **Google Drive Book (`OIL FIELD BOOK`)** | Brand-New Unique Businesses Added Live | **+6,751** | Published as `verified: false` (`free_basic`) with full geo & 30-sector tags |
| **Google Drive Book (`OIL FIELD BOOK`)** | Held Back (Same Name Other Town / Cropped) | **3,710** | Prevents moved-shop duplicates (`627`) and margin-cropped rows (`146`) |
| **Full Yellow Pages Inspection (`Bot 23`)** | Active Public Businesses Before Clean | **69,440** | Across all 107 countries & 3,822 canonical towns |
| **Full Yellow Pages Inspection (`Bot 23`)** | Misspelled / Stem / Partial Duplicates Merged | **134** | Old phones preserved in survivor `legacyPhones`; `0` false positives |
| **Full Yellow Pages Inspection (`Bot 23`)** | Standalone Typos & Inverted Names Repaired | **61** | Fixed `Oilfeild`/`Oilfiled`/`Sevices`/`Constructon`/`Enviromental`, `... The` -> `The ...`, parens |
| **Full Yellow Pages Inspection (`Bot 23`)** | **Final Clean Active Public Businesses** | **69,306** | Post-clean audit verified **`0` remaining duplicates** & **`0` remaining name defects** |
| **Geo & Verification Hygiene** | Non-Canonical Town/City Spellings | **0** | `0` town/city spelling splits (`3,822` canonical cities) |
| **Geo & Verification Hygiene** | Pre-Verified Listings (`verified=true`) | **0** | `0` pre-verified (green checkmark strictly reserved for verified accounts) |
| **Geo & Verification Hygiene** | Populated Oil & Gas Service Sectors | **30 / 30** | Includes Accredited Training (`oil_gas_training`) & Crew Hotels (`crew_hotels_workforce_lodging`) |
| **`pipebuyer2026` Outreach Readiness** | Businesses With Valid Email On File Now | **9,515** | Ready immediately for `pipebuyer2026` 6-months-free email campaign |
| **`pipebuyer2026` Outreach Readiness** | Businesses With Website URL (Email Discoverable) | **38,510** | Public `info@`/`sales@` contact emails extractable from company domain |
| **`pipebuyer2026` Outreach Readiness** | Phone-Only Listings | **21,281** | Reachable via PipeBuyer Contact Center phone outreach |

## 2. Companion Spreadsheet Files

- **Multi-Tab Excel Workbook (`.xlsx`):** `data/yellow_pages/reports/COSSD_Book_Cross_Reference_And_YP_Inspection.xlsx`
  - Tab 1: `Executive Summary`
  - Tab 2: `73 Drive Images Index` (all 73 photos + A/B tile verification + per-page counts)
  - Tab 3: `All Book Listings` (all `13,956` unique listings from the book + live match ID & outcome)
  - Tab 4: `Added New From Book` (all net-new businesses added to `pipebuyer.com`)
  - Tab 5: `Held Review Or Branch` (moved-town / edge-cropped rows held out of auto-publish)
  - Tab 6: `YP Duplicates Cleaned` (all `134` merged cross-source duplicates with kept vs. merged IDs & phones)
  - Tab 7: `Name Typos Repaired` (all `61` standalone spelling/title repairs)
  - Tab 8: `Standalone Name Audit` (`0` unresolved defects remaining)
  - Tab 9: `30 Sectors & Outreach` (counts across all 30 sectors + email/website readiness by discovery channel)
- **73-Image Summary CSV:** `data/yellow_pages/reports/cossd_73_drive_images_summary.csv`
- **Full 13,956-Row Book Cross-Reference CSV:** `data/yellow_pages/reports/cossd_all_book_listings_crossref.csv`

## 3. All 73 Google Drive Book Images — Page-by-Page Verification

| # | Photo Filename | A+B Tiles | Book Page(s) | Section(s) | Raw Rows | Unique Rows | Added New | Matched Existing | Held / Review |
| ---: | :--- | :---: | :--- | :--- | ---: | ---: | ---: | ---: | ---: |
| 1 | `20261025_114157.jpg` | **YES** | 11 | `white, yellow_ad` | 86 | 86 | **37** | 23 | 26 |
| 2 | `20261025_114218.jpg` | **YES** | 12 | `white, yellow_ad` | 128 | 128 | **57** | 26 | 45 |
| 3 | `20261025_114232.jpg` | **YES** | 13 | `white` | 143 | 143 | **81** | 29 | 33 |
| 4 | `20261027_110025.jpg` | **YES** | — | `white` | 153 | 146 | **58** | 55 | 33 |
| 5 | `20261027_113808.jpg` | **YES** | 140 | `by_town` | 207 | 204 | **141** | 28 | 35 |
| 6 | `20261027_113901.jpg` | **YES** | 141 | `by_town` | 202 | 197 | **100** | 43 | 54 |
| 7 | `20261027_114821.jpg` | **YES** | 142 | `by_town` | 220 | 208 | **94** | 42 | 72 |
| 8 | `20261027_114920.jpg` | **YES** | 143 | `by_town` | 241 | 203 | **88** | 58 | 57 |
| 9 | `20261027_115347.jpg` | **YES** | 144 | `white` | 232 | 232 | **93** | 68 | 71 |
| 10 | `20261027_115429.jpg` | **YES** | 145 | `yellow_ad, white` | 254 | 254 | **112** | 67 | 75 |
| 11 | `20261027_115528.jpg` | **YES** | 146 | `white` | 243 | 243 | **99** | 72 | 72 |
| 12 | `20261027_115721.jpg` | **YES** | 148 | `white` | 259 | 259 | **112** | 79 | 68 |
| 13 | `20261027_120211.jpg` | **YES** | 150 | `by_town` | 260 | 260 | **94** | 91 | 75 |
| 14 | `20261027_120515.jpg` | **YES** | — | `by_town` | 242 | 242 | **112** | 73 | 57 |
| 15 | `20261027_121121.jpg` | **YES** | 151 | `by_town` | 246 | 246 | **95** | 76 | 75 |
| 16 | `20261028_161758.jpg` | **YES** | 152 | `by_town` | 208 | 208 | **129** | 32 | 47 |
| 17 | `20261028_163224.jpg` | **YES** | 155 | `white, yellow_ad` | 201 | 193 | **95** | 44 | 54 |
| 18 | `20261028_163706.jpg` | **YES** | 156 | `white` | 233 | 185 | **76** | 59 | 50 |
| 19 | `20261028_163808.jpg` | **YES** | 157 | `by_town` | 246 | 246 | **95** | 82 | 69 |
| 20 | `20261028_164023.jpg` | **YES** | 158 | `by_town` | 246 | 246 | **105** | 68 | 73 |
| 21 | `20261028_164142.jpg` | **YES** | 159 | `by_town` | 244 | 244 | **95** | 83 | 66 |
| 22 | `20261028_165610.jpg` | **YES** | 160 | `by_town` | 260 | 260 | **70** | 86 | 104 |
| 23 | `20261028_165717.jpg` | **YES** | 160 | `by_town` | 260 | 64 | **1** | 17 | 46 |
| 24 | `20261028_165803.jpg` | **YES** | 161 | `by_town` | 242 | 242 | **104** | 83 | 55 |
| 25 | `20261028_170134.jpg` | **YES** | 162 | `white, yellow_ad` | 238 | 238 | **109** | 63 | 66 |
| 26 | `20261028_170746.jpg` | **YES** | — | `white` | 182 | 182 | **84** | 57 | 41 |
| 27 | `20261028_170806.jpg` | **YES** | 163 | `white` | 68 | 68 | **32** | 16 | 20 |
| 28 | `20261028_171531.jpg` | **YES** | 164 | `by_town` | 178 | 173 | **73** | 52 | 48 |
| 29 | `20261028_171559.jpg` | **YES** | — | `by_town` | 172 | 57 | **24** | 10 | 23 |
| 30 | `20261028_171846.jpg` | **YES** | 165 | `by_town` | 192 | 189 | **102** | 20 | 67 |
| 31 | `20261028_172711.jpg` | **YES** | 166 | `by_town` | 203 | 197 | **88** | 44 | 65 |
| 32 | `20261028_173126.jpg` | **YES** | 167 | `white, yellow_ad` | 205 | 201 | **119** | 47 | 35 |
| 33 | `20261028_173317.jpg` | **YES** | 168 | `white, yellow_ad` | 196 | 181 | **90** | 41 | 50 |
| 34 | `20261028_173834.jpg` | **YES** | 168 | `white, yellow_ad, by_town` | 236 | 2 | **2** | 0 | 0 |
| 35 | `20261028_174144.jpg` | **YES** | 169 | `by_town` | 224 | 224 | **97** | 56 | 71 |
| 36 | `20261028_174650.jpg` | **YES** | 170 | `by_town` | 188 | 188 | **89** | 49 | 50 |
| 37 | `20261028_174751.jpg` | **YES** | 171 | `by_town` | 174 | 173 | **95** | 34 | 44 |
| 38 | `20261028_175256.jpg` | **YES** | 172 | `by_town` | 215 | 214 | **152** | 20 | 42 |
| 39 | `20261028_175639.jpg` | **YES** | — | `white, yellow_ad` | 198 | 190 | **118** | 20 | 52 |
| 40 | `20261028_180022.jpg` | **YES** | — | `white` | 241 | 237 | **102** | 56 | 79 |
| 41 | `20261028_180433.jpg` | **YES** | 175 | `white, yellow_ad, by_town` | 264 | 226 | **130** | 42 | 54 |
| 42 | `20261028_180612.jpg` | **YES** | 176 | `by_town` | 231 | 230 | **116** | 70 | 44 |
| 43 | `20261028_180928.jpg` | **YES** | 177 | `by_town` | 221 | 218 | **100** | 50 | 68 |
| 44 | `20261105_131443.jpg` | **YES** | 178 | `by_town` | 186 | 175 | **88** | 41 | 46 |
| 45 | `20261105_131658.jpg` | **YES** | 179 | `by_town` | 228 | 226 | **94** | 71 | 61 |
| 46 | `20261105_132021.jpg` | **YES** | 180 | `white, yellow_ad` | 199 | 196 | **119** | 25 | 52 |
| 47 | `20261105_132111.jpg` | **YES** | 181 | `white, yellow_ad` | 212 | 193 | **99** | 37 | 57 |
| 48 | `20261105_132413.jpg` | **YES** | 182 | `by_town` | 237 | 237 | **89** | 74 | 74 |
| 49 | `20261105_132549.jpg` | **YES** | 183 | `by_town` | 232 | 232 | **96** | 67 | 69 |
| 50 | `20261105_132754.jpg` | **YES** | 184 | `by_town` | 217 | 215 | **109** | 45 | 61 |
| 51 | `20261105_133443.jpg` | **YES** | 185 | `by_town` | 172 | 171 | **85** | 38 | 48 |
| 52 | `20261105_133728.jpg` | **YES** | 186 | `by_town` | 228 | 223 | **108** | 41 | 74 |
| 53 | `20261105_134238.jpg` | **YES** | 188 | `white, yellow_ad` | 219 | 214 | **135** | 35 | 44 |
| 54 | `20261105_134756.jpg` | **YES** | 189 | `white, yellow_ad` | 202 | 196 | **139** | 29 | 28 |
| 55 | `20261105_135749.jpg` | **YES** | 190 | `white, yellow_ad, by_town` | 236 | 197 | **127** | 28 | 42 |
| 56 | `20261105_140040.jpg` | **YES** | 191 | `by_town` | 205 | 196 | **136** | 25 | 35 |
| 57 | `20261105_140809.jpg` | **YES** | 192 | `by_town` | 188 | 188 | **101** | 33 | 54 |
| 58 | `20261105_142524.jpg` | **YES** | 193 | `by_town` | 197 | 191 | **96** | 40 | 55 |
| 59 | `20261105_142650.jpg` | **YES** | 194 | `by_town` | 204 | 203 | **105** | 55 | 43 |
| 60 | `20261105_142942.jpg` | **YES** | 195 | `white, yellow_ad` | 227 | 220 | **99** | 66 | 55 |
| 61 | `20261105_143522.jpg` | **YES** | 196 | `white, yellow_ad` | 232 | 232 | **96** | 70 | 66 |
| 62 | `20261105_143717.jpg` | **YES** | 197 | `white, yellow_ad` | 162 | 156 | **88** | 43 | 25 |
| 63 | `20261105_143820.jpg` | **YES** | 198 | `white, yellow_ad` | 162 | 161 | **72** | 48 | 41 |
| 64 | `20261105_143928.jpg` | **YES** | 199 | `by_town` | 155 | 150 | **75** | 47 | 28 |
| 65 | `20261105_144049.jpg` | **YES** | 200 | `by_town` | 149 | 144 | **51** | 63 | 30 |
| 66 | `20261105_144117.jpg` | **YES** | 201 | `by_town` | 157 | 152 | **81** | 36 | 35 |
| 67 | `20261105_144320.jpg` | **YES** | 202 | `white` | 195 | 191 | **91** | 50 | 50 |
| 68 | `20261105_144531.jpg` | **YES** | 203 | `white, yellow_ad` | 178 | 174 | **100** | 27 | 47 |
| 69 | `20261105_144621.jpg` | **YES** | 204 | `white, by_town` | 235 | 188 | **106** | 42 | 40 |
| 70 | `20261105_144642.jpg` | **YES** | 205 | `by_town` | 230 | 226 | **102** | 67 | 57 |
| 71 | `20261105_144754.jpg` | **YES** | 206 | `by_town` | 117 | 110 | **72** | 24 | 14 |
| 72 | `20261105_144842.jpg` | **YES** | 207 | `by_town` | 129 | 126 | **50** | 46 | 30 |
| 73 | `20261105_144926.jpg` | **YES** | 208 | `by_town` | 147 | 146 | **77** | 51 | 18 |

## 4. Duplicate & Misspelled / Partial-Word Cleanup Summary (`Bot 23`)

| Duplicate Pattern | Merged Count | Example Survivors (`Kept` <- `Merged`) |
| :--- | ---: | :--- |
| `same_phone_and_name_variant` | **58** | `Journey Oilfield Equipment LLC` <- `Journey Oilfiled Equipment LLC`; `Fidelity Machine & Moulding Solutions` <- `... Mould Solutions`; `Tu-Case Group` <- `Tu-Casa Group` |
| `exact_compact_core_same_city` | **47** | `Foremost` <- `Foremost - Or`; `Tornado Infrastructure Equipment LTD` <- `... (NA) Inc`; `Arapahoe Oilfield Services` <- `Arapahoe Oil Field Services`; `Keep it 100 Hot Shot` <- `Keep It 100 Hotshot` |
| `singular_plural_stem_same_city` | **29** | `Hydrostatic Pipe Service INC` <- `Hydrostatic Pipe Services Inc`; `3D Hotshot Service` <- `3D Hotshot Services`; `Adams Testing Services` <- `Adams Testing Service`; `Offshore Partner AS` <- `Offshore Partners AS` |

### Representative Standalone Spelling & Title Repairs (`61` Repaired -> `0` Remaining Defects)

| City, Region | Before Repair | After Repair |
| :--- | :--- | :--- |
| High Prairie, AB | `Honda Shop The` | **`The Honda Shop`** |
| Dawson Creek, BC | `Drain Surgeon The` | **`The Drain Surgeon`** |
| Edmonton, AB | `Mc Rae's Enviromental` | **`Mc Rae's Environmental`** |
| Edmonton, AB | `Alberta Association of Architects The` | **`The Alberta Association of Architects`** |
| Calgary, AB | `Coast Plaza Hotel The` | **`The Coast Plaza Hotel`** |
| Westlock, AB | `Container Guy The` | **`The Container Guy`** |
| Calgary, AB | `Delta Bow Valley Hotel The` | **`The Delta Bow Valley Hotel`** |
| Edson, AB | `Diesel Shop The` | **`The Diesel Shop`** |
| Egremont, AB | `Egremont Hotel The` | **`The Egremont Hotel`** |
| Calgary, AB | `Fairmont Palliser The` | **`The Fairmont Palliser`** |
| Edmonton, AB | `Metterra Hotel The` | **`The Metterra Hotel`** |
| Calgary, AB | `Print Shoppe The` | **`The Print Shoppe`** |
| Edmonton, AB | `Super Poly Partnership The` | **`The Super Poly Partnership`** |
| Calgary, AB | `Westin Hotel The` | **`The Westin Hotel`** |
| Edmonton, AB | `Westin Hotel The` | **`The Westin Hotel`** |
| Fort St. John, BC | `Shepherd's Inn, The` | **`The Shepherd's Inn`** |
| Dawson Creek, BC | `Steel Yard, The` | **`The Steel Yard`** |
| Mount Pearl, NL | `Scale Shop (1985) Ltd The` | **`The Scale Shop (1985) Ltd`** |
| Abu Dhabi, AZ | `Hydrolic Technical Equipments Maintenace Est` | **`Hydraulic Technical Equipments Maintenance Est`** |
| Gladstone, QLD | `A1 Engineering & Maintanence` | **`A1 Engineering & Maintenance`** |
| Saskatoon, SK | `lg Construction Saskatoon` | **`Lg Construction Saskatoon`** |
| Pointe-Noire, PNR | `Bouara & Cie Sarl (Sécurité Navigation / Navigation Security` | **`Bouara & Cie Sarl (Sécurité Navigation / Navigation Security)`** |
| Ahmadi, AH | `Ajal Petroleum & Enviroment Integral Services Co` | **`Ajal Petroleum & Environment Integral Services Co`** |
| Atyrau, ATY | `ТОО MARKLIFT в г. Атырау (Стропы в Атырау, Стяжные ремни, Такелаж, Лебёдки, Тали цепные, кран гаражный, захваты, рохли` | **`ТОО MARKLIFT в г. Атырау (Стропы в Атырау, Стяжные ремни, Такелаж, Лебёдки, Тали цепные, кран гаражный, захваты, рохли)`** |
| Lacombe, AB | `Good Water Co The` | **`The Good Water Co`** |
| Mirror, AB | `Water Bus The` | **`The Water Bus`** |
| Sparwood, BC | `DC Contracting Sevices` | **`DC Contracting Services`** |
| Cranbrook, BC | `Energy Mines & Petroleum Resources-Ministry Of` | **`Ministry of Energy, Mines & Petroleum Resources`** |
| Miramichi, NB | `DEW Engineering and` | **`DEW Engineering`** |
| Miramichi, NB | `Safety Equipment & Acces Div` | **`Safety Equipment & Access Division`** |

## 5. All 30 Oil & Gas Sectors (Post-Clean Active Counts)

| Sector Code | Active Businesses |
| :--- | ---: |
| `trucking_heavy_haul` | **10,792** |
| `equipment_rentals_tools` | **9,801** |
| `welding_machining_fab` | **8,973** |
| `safety_h2s_medics` | **7,643** |
| `oil_gas_training_courses` | **6,548** |
| `drilling_rigs_directional` | **5,690** |
| `pipe_octg_supply` | **5,270** |
| `pumps_artificial_lift` | **4,823** |
| `surveying_engineering_geomatics` | **4,597** |
| `vacuum_hydrovac_fluid` | **3,766** |
| `crane_picker_rigging` | **3,414** |
| `hotshot_pilot_logistics` | **2,981** |
| `matting_lease_civil` | **2,849** |
| `explorers_producers_midstream` | **2,299** |
| `completions_frac_wireline` | **2,271** |
| `pipeline_facility_construction` | **2,119** |
| `electrical_automation_scada` | **2,065** |
| `fleet_heavy_duty_repair` | **1,928** |
| `environmental_remediation_waste` | **1,908** |
| `chemical_mud_lubricants` | **1,608** |
| `crew_hotels_workforce_lodging` | **1,302** |
| `pipe_inspection_ndt` | **1,287** |
| `wellhead_valves_pressure` | **1,006** |
| `tanks_vessels_process` | **961** |
| `camps_catering_accommodations` | **815** |
| `staffing_training_compliance` | **725** |
| `industrial_supply_ppe_workwear` | **713** |
| `scaffolding_insulation_coatings` | **574** |
| `marine_offshore_aviation` | **376** |
| `lease_security_communications_it` | **206** |

## 6. Outreach Readiness & `pipebuyer2026` (6 Months Free) Implementation Plan

### Email & Website Coverage by Discovery Channel

| Discovery Channel | Active Businesses | Valid Email Now | Website URL On File |
| :--- | ---: | ---: | ---: |
| `google_maps_microtown_audit` | **31,316** | 1 | 21,031 |
| `google_maps_alpha_audit` | **10,569** | 1 | 8,141 |
| `usdot_fmcsa_oilfield_census` | **7,937** | 7,685 | 0 |
| `cossd_book_2026_photo_ocr` | **6,305** | 0 | 55 |
| `cossd_directory` | **4,535** | 1,806 | 4,491 |
| `google_maps_training_audit` | **3,376** | 0 | 2,626 |
| `google_maps_microtown_training` | **3,074** | 0 | 2,392 |
| `google_maps_crew_hotel_audit` | **714** | 0 | 422 |
| `google_maps_sector_gap_audit` | **601** | 0 | 452 |
| `wikidata_global_oilfield_tree` | **227** | 0 | 227 |
| `curated_international_oilfield_hub` | **169** | 0 | 169 |
| `sec_edgar_sic_registry` | **134** | 9 | 0 |
| `basin_hub_deep_fill` | **81** | 0 | 81 |
| `wikidata_national_energy_registry` | **81** | 0 | 81 |
| `regional_oilfield_contractor_registry` | **80** | 0 | 80 |
| `sec_edgar_international_registry` | **59** | 0 | 0 |
| `direct_oilpatch_operator_seed` | **30** | 13 | 30 |
| `deep_fill_hub_vertical_crawl` | **11** | 0 | 11 |
| `localized_basin_web_crawl` | **4** | 0 | 4 |
| `open_web_country_crawl` | **3** | 0 | 3 |

### Phase 2 Technical Architecture (`pipebuyer2026` Promo + Email Campaign)
1. **Stripe Coupon & Promotion Code (`pipebuyer2026`):**
   - Provision an idempotent Stripe Coupon (`percent_off: 100`, `duration: 'repeating'`, `duration_in_months: 6`) and active Promotion Code `pipebuyer2026` (`STRIPE_SECRET_PRODUCTION`) restricted to eligible monthly plans (`applies_to[products]`).
   - Fix the latent import bug in `firebase/functions/yellow_pages_billing.js` (`safeConfiguredUrl` and `stripeFormRequest` imported from `./stripe_checkout_commands`) and wire `resolveSubscriptionPromotionCode` (`subscription_promotion_resolver.js`) + `allow_promotion_codes=true` into Yellow Pages & Dispatch Checkout sessions so businesses can either click a pre-applied invite link (`?promo=pipebuyer2026&claim=<companyId>`) or type `pipebuyer2026` directly at checkout.
2. **Compliant Email Outreach Pipeline & Unsubscribe Tracking:**
   - Optional Phase 2A enricher: crawl public homepage/contact pages of the `38,510` businesses with a website URL to non-destructively populate public `info@`/`sales@` emails.
   - Add throttled batch outreach Cloud Functions + Contact Center UI controls (`pipebuyer_contact_center_dashboard.dart`) with per-company claim deep-links, `doNotContact` one-click unsubscribe (`CASL` / `CAN-SPAM` compliant), `outreachStatus` tracking, and `yellow_pages_contact_events` audit logging.
