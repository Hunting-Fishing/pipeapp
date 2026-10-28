# Bot 15 — Full Directory Field Consistency & Town Consolidation Audit Report

- **Generated At**: `2026-10-28T01:00:39.323Z`
- **Project**: `flutter-flow-pipe` (`apply=true`, `includeTraining=true`)
- **Total Public Entries Audited**: **61,819**
- **Total Entries Repaired / Standardized**: **4**
  - Town / County / USDOT / FMCSA City Names Canonicalized: **0**
  - Empty `city` Records Recovered via NANPA Exchange / Name: **0**
  - `countryCode` / `regionCode` Repaired via Area Code: **0**
  - ALL-CAPS / HTML-Entity Company Names Normalized: **0**
  - Missing `basins` Backfilled: **0**
  - Service Categories Enriched / Fixed: **4** (Oil & Gas Training Tagged: **4**)
  - Exact Duplicate Public Entries Removed: **0**

## Sample Field Standardizations

- `gmaps-in-gj-gulfnde-ndt-training-services-classes-placemen-3085-97856`: `Gulfnde : NDT Training, Services, Classes, Placement in Vadodara | Vadodara, GJ, IN | cats=3` → **`Gulfnde : NDT Training, Services, Classes, Placement in Vadodara | Vadodara, GJ, IN | cats=pipe_inspection_ndt,safety_h2s_medics,surveying_engineering_geomatics,oil_gas_training_courses`**
- `gmaps-ng-ri-eben-uk-resources-crane-operation-pipeline-wel-5323-44858`: `EBEN UK RESOURCES - Crane operation, Pipeline welding, AutoCAD, PDMS, Safety training, Forklift Operation, Primavera P6 | Port Harcourt, RI, NG | cats=3` → **`EBEN UK RESOURCES - Crane operation, Pipeline welding, AutoCAD, PDMS, Safety training, Forklift Operation, Primavera P6 | Port Harcourt, RI, NG | cats=crane_picker_rigging,welding_machining_fab,pipeline_facility_construction,oil_gas_training_courses`**
- `gmaps-ng-ri-muchilla-integrated-services-6831-44785`: `Muchilla Integrated Services Ltd | Onne, RI, NG | cats=3` → **`Muchilla Integrated Services Ltd | Onne, RI, NG | cats=drilling_rigs_directional,pipeline_facility_construction,safety_h2s_medics,oil_gas_training_courses`**
- `gmaps-za-kzn-welding-boilermaker-plumbing-pipe-fitter-carpe-0140-45381`: `Welding, boilermaker, plumbing, Pipe fitter, carpentry, Panel Beater School | Durban, KZN, ZA | cats=3` → **`Welding, boilermaker, plumbing, Pipe fitter, carpentry, Panel Beater School | Durban, KZN, ZA | cats=pipe_octg_supply,welding_machining_fab,equipment_rentals_tools,oil_gas_training_courses`**
