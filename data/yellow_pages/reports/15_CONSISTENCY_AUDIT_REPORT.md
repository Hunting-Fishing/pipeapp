# Bot 15 — Full Directory Field Consistency & Town Consolidation Audit Report

- **Generated At**: `2026-10-28T03:26:05.891Z`
- **Project**: `flutter-flow-pipe` (`apply=true`, `includeTraining=true`)
- **Total Public Entries Audited**: **63,134**
- **Total Entries Repaired / Standardized**: **84**
  - Town / County / USDOT / FMCSA City Names Canonicalized: **0**
  - Empty `city` Records Recovered via NANPA Exchange / Name: **0**
  - `countryCode` / `regionCode` Repaired via Area Code: **0**
  - ALL-CAPS / HTML-Entity Company Names Normalized: **0**
  - Missing `basins` Backfilled: **0**
  - Service Categories Enriched / Fixed: **84** (Oil & Gas Training Tagged: **0**)
  - Exact Duplicate Public Entries Removed: **0**

## Sample Field Standardizations

- `cossd-10579`: `Norseman Oilfield Services | Red Deer, AB, CA | cats=1` → **`Norseman Oilfield Services | Red Deer, AB, CA | cats=camps_catering_accommodations,lease_security_communications_it`**
- `cossd-10604`: `Fisher Powerline Construction Ltd | Fort McMurray, AB, CA | cats=3` → **`Fisher Powerline Construction Ltd | Fort McMurray, AB, CA | cats=matting_lease_civil,camps_catering_accommodations,marine_offshore_aviation,lease_security_communications_it`**
- `cossd-10609`: `Heavy North | Fort McMurray, AB, CA | cats=3` → **`Heavy North | Fort McMurray, AB, CA | cats=vacuum_hydrovac_fluid,welding_machining_fab,matting_lease_civil,lease_security_communications_it`**
- `cossd-10814`: `Northern Canadian Supplies Ltd | Fort McMurray, AB, CA | cats=2` → **`Northern Canadian Supplies Ltd | Fort McMurray, AB, CA | cats=safety_h2s_medics,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-11130`: `Athabasca Basin Security | Corman Park, SK, CA | cats=2` → **`Athabasca Basin Security | Corman Park, SK, CA | cats=trucking_heavy_haul,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-11139`: `Securitas Canada Ltd | Edmonton, AB, CA | cats=3` → **`Securitas Canada Ltd | Edmonton, AB, CA | cats=wellhead_valves_pressure,camps_catering_accommodations,scaffolding_insulation_coatings,lease_security_communications_it`**
- `cossd-11140`: `Service Masters Security | Red Deer, AB, CA | cats=1` → **`Service Masters Security | Red Deer, AB, CA | cats=camps_catering_accommodations,lease_security_communications_it`**
- `cossd-11141`: `TAWS Security Ltd | Fort McMurray, AB, CA | cats=2` → **`TAWS Security Ltd | Fort McMurray, AB, CA | cats=vacuum_hydrovac_fluid,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-11142`: `TS Surelock Security Ltd | Edmonton, AB, CA | cats=3` → **`TS Surelock Security Ltd | Edmonton, AB, CA | cats=pipe_octg_supply,pumps_artificial_lift,pipeline_facility_construction,lease_security_communications_it`**
- `cossd-11322`: `T & S Signs Ltd | Fort McMurray, AB, CA | cats=2` → **`T & S Signs Ltd | Fort McMurray, AB, CA | cats=electrical_automation_scada,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-11713`: `Centerline Geomatics Ltd | Fort McMurray, AB, CA | cats=3` → **`Centerline Geomatics Ltd | Fort McMurray, AB, CA | cats=safety_h2s_medics,camps_catering_accommodations,surveying_engineering_geomatics,lease_security_communications_it`**
- `cossd-11811`: `TankSafe Inc | Calgary, AB, CA | cats=3` → **`TankSafe Inc | Calgary, AB, CA | cats=camps_catering_accommodations,pumps_artificial_lift,tanks_vessels_process,lease_security_communications_it`**
- `cossd-12101`: `Tremcar West | Edmonton, AB, CA | cats=2` → **`Tremcar West | Edmonton, AB, CA | cats=trucking_heavy_haul,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-12139`: `Total Truck & Trailer Repairs (TTTR) | Calgary, AB, CA | cats=3` → **`Total Truck & Trailer Repairs (TTTR) | Calgary, AB, CA | cats=pipe_octg_supply,pipeline_facility_construction,fleet_heavy_duty_repair,lease_security_communications_it`**
- `cossd-12190`: `GRB College Of Welding | Edmonton, AB, CA | cats=3` → **`GRB College Of Welding | Edmonton, AB, CA | cats=welding_machining_fab,camps_catering_accommodations,staffing_training_compliance,lease_security_communications_it`**
- `cossd-1236`: `Central Labs | Red Deer, AB, CA | cats=3` → **`Central Labs | Red Deer, AB, CA | cats=drilling_rigs_directional,pumps_artificial_lift,electrical_automation_scada,lease_security_communications_it`**
- `cossd-12405`: `CanGas Solutions Inc | Calgary, AB, CA | cats=3` → **`CanGas Solutions Inc | Calgary, AB, CA | cats=trucking_heavy_haul,pumps_artificial_lift,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-12950`: `Discount Truck Parts Ltd | Edmonton, AB, CA | cats=4` → **`Discount Truck Parts Ltd | Edmonton, AB, CA | cats=pipe_octg_supply,welding_machining_fab,camps_catering_accommodations,scaffolding_insulation_coatings,lease_security_communications_it`**
- `cossd-14098`: `Arctec Alloys Ltd | Edmonton, AB, CA | cats=3` → **`Arctec Alloys Ltd | Edmonton, AB, CA | cats=completions_frac_wireline,pumps_artificial_lift,welding_machining_fab,lease_security_communications_it`**
- `cossd-151`: `G S Equipment Ltd | Red Deer, AB, CA | cats=3` → **`G S Equipment Ltd | Red Deer, AB, CA | cats=trucking_heavy_haul,hotshot_pilot_logistics,wellhead_valves_pressure,lease_security_communications_it`**
- `cossd-15779`: `10-Code LLC | Bismarck, ND, US | cats=3` → **`10-Code LLC | Bismarck, ND, US | cats=electrical_automation_scada,environmental_remediation_waste,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-15839`: `Ackerman-Estvold | Minot, ND, US | cats=3` → **`Ackerman-Estvold | Minot, ND, US | cats=welding_machining_fab,camps_catering_accommodations,surveying_engineering_geomatics,lease_security_communications_it`**
- `cossd-18041`: `Penserv Corp - Em Surveys | Calgary, AB, CA | cats=3` → **`Penserv Corp - Em Surveys | Calgary, AB, CA | cats=pipe_octg_supply,environmental_remediation_waste,camps_catering_accommodations,lease_security_communications_it`**
- `cossd-184`: `Roll'n Oilfield Industries Ltd | Red Deer, AB, CA | cats=3` → **`Roll'n Oilfield Industries Ltd | Red Deer, AB, CA | cats=pipe_octg_supply,completions_frac_wireline,wellhead_valves_pressure,lease_security_communications_it`**
- `cossd-18533`: `Hawco Peters | Calgary, AB, CA | cats=2` → **`Hawco Peters | Calgary, AB, CA | cats=wellhead_valves_pressure,camps_catering_accommodations,lease_security_communications_it`**
