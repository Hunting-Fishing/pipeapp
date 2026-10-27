# Bot 15 — Full Directory Field Consistency & Town Consolidation Audit Report

- **Generated At**: `2026-10-27T13:50:22.218Z`
- **Project**: `flutter-flow-pipe` (`apply=true`, `includeTraining=true`)
- **Total Public Entries Audited**: **57,643**
- **Total Entries Repaired / Standardized**: **2**
  - Town / County / USDOT / FMCSA City Names Canonicalized: **0**
  - Empty `city` Records Recovered via NANPA Exchange / Name: **0**
  - `countryCode` / `regionCode` Repaired via Area Code: **0**
  - ALL-CAPS / HTML-Entity Company Names Normalized: **0**
  - Missing `basins` Backfilled: **0**
  - Service Categories Enriched / Fixed: **2** (Oil & Gas Training Tagged: **2**)
  - Exact Duplicate Public Entries Removed: **0**

## Sample Field Standardizations

- `gmaps-no-ro-nwe-nord-welding-engineering-as-1100-14039`: `NWE (Nord Welding & Engineering AS) | Tananger, RO, NO | cats=3` → **`NWE (Nord Welding & Engineering AS) | Tananger, RO, NO | cats=welding_machining_fab,safety_h2s_medics,surveying_engineering_geomatics,oil_gas_training_courses`**
- `gmaps-sa-ri-iipd-global-riyadh-industrial-automation-bms-k-9055-63833`: `IIPD Global Riyadh - Industrial Automation , BMS , KNX, Cybersecurity, Digital Marketing - معهد الابتكار والتطوير المهني | Riyadh, RI, SA | cats=3` → **`IIPD Global Riyadh - Industrial Automation , BMS , KNX, Cybersecurity, Digital Marketing - معهد الابتكار والتطوير المهني | Riyadh, RI, SA | cats=electrical_automation_scada,safety_h2s_medics,camps_catering_accommodations,oil_gas_training_courses`**
