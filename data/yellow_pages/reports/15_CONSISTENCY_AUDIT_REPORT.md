# Bot 15 — Full Directory Field Consistency & Town Consolidation Audit Report

- **Generated At**: `2026-10-26T18:17:44.646Z`
- **Project**: `flutter-flow-pipe` (`apply=true`, `includeTraining=true`)
- **Total Public Entries Audited**: **13,480**
- **Total Entries Repaired / Standardized**: **1,213**
  - Town / County / USDOT / FMCSA City Names Canonicalized: **258**
  - Empty `city` Records Recovered via NANPA Exchange / Name: **110**
  - `countryCode` / `regionCode` Repaired via Area Code: **119**
  - ALL-CAPS / HTML-Entity Company Names Normalized: **269**
  - Missing `basins` Backfilled: **247**
  - Service Categories Enriched / Fixed: **594** (Oil & Gas Training Tagged: **103**)
  - Exact Duplicate Public Entries Removed: **3**

## Sample Field Standardizations

- `cossd-10017`: `DSI Dalco Services Inc | Red Deer Co, AB, CA | cats=3` → **`DSI Dalco Services Inc | Red Deer, AB, CA | cats=trucking_heavy_haul,drilling_rigs_directional,completions_frac_wireline`**
- `cossd-10063`: `MasterBond | Hackensack, NJ, US | cats=1` → **`MasterBond | Hackensack, NJ, US | cats=welding_machining_fab`**
- `cossd-10081`: `Cadman Power Equipment | Courtland, ON, CA | cats=0` → **`Cadman Power Equipment | Courtland, ON, CA | cats=pumps_artificial_lift`**
- `cossd-10083`: `JCPump LLC | Coffeyville, KS, US | cats=0` → **`JCPump LLC | Coffeyville, KS, US | cats=equipment_rentals_tools`**
- `cossd-10101`: `Acutus Industrial Power Inc (AIPI) | Delson, QC, CA | cats=0` → **`Acutus Industrial Power Inc (AIPI) | Delson, QC, CA | cats=pumps_artificial_lift`**
- `cossd-10118`: `Cypress Engine Accessories | Cypress, TX, US | cats=0` → **`Cypress Engine Accessories | Cypress, TX, US | cats=pumps_artificial_lift`**
- `cossd-10135`: `John Brooks Company Limited | Lachine, QC, CA | cats=0` → **`John Brooks Company Limited | Lachine, QC, CA | cats=pumps_artificial_lift`**
- `cossd-10137`: `KGS Tools Inc | Edmonton, AB, CA | cats=0` → **`KGS Tools Inc | Edmonton, AB, CA | cats=pumps_artificial_lift`**
- `cossd-10139`: `Little Red Services Inc | Anchorage, AK, US | cats=0` → **`Little Red Services Inc | Anchorage, AK, US | cats=equipment_rentals_tools`**
- `cossd-10140`: `Lynco Products Inc | Calgary, AB, CA | cats=0` → **`Lynco Products Inc | Calgary, AB, CA | cats=pumps_artificial_lift,surveying_engineering_geomatics`**
- `cossd-10141`: `Master Pumps & Power | Aliquippa, PA, US | cats=0` → **`Master Pumps & Power | Aliquippa, PA, US | cats=pumps_artificial_lift`**
- `cossd-10151`: `Rotech Pumps & Systems Inc | Mississauga, ON, CA | cats=0` → **`Rotech Pumps & Systems Inc | Mississauga, ON, CA | cats=pumps_artificial_lift`**
- `cossd-10160`: `Tulsa Rig Iron | Kiefer, OK, US | cats=0` → **`Tulsa Rig Iron | Kiefer, OK, US | cats=pumps_artificial_lift`**
- `cossd-10179`: `Phase Technologies LLC | Rapid City, SD, US | cats=0` → **`Phase Technologies LLC | Rapid City, SD, US | cats=equipment_rentals_tools`**
- `cossd-10209`: `Xceed Machine Works Inc | Edmonton, AB, CA | cats=0` → **`Xceed Machine Works Inc | Edmonton, AB, CA | cats=pumps_artificial_lift`**
- `cossd-10261`: `Blue Ridge Excavating | Rocky View Co, AB, CA | cats=3` → **`Blue Ridge Excavating | Rocky View County, AB, CA | cats=pipe_inspection_ndt,environmental_remediation_waste,pipe_octg_supply`**
- `cossd-10327`: `Geotemps Inc | Reno, NV, US | cats=0` → **`Geotemps Inc | Reno, NV, US | cats=equipment_rentals_tools`**
- `cossd-10330`: `Johnson ReSource Group | Corpus Christi, TX, US | cats=0` → **`Johnson ReSource Group | Corpus Christi, TX, US | cats=equipment_rentals_tools`**
- `cossd-10363`: `H Broer Equipment Sales & Service Inc | Aylmer, ON, CA | cats=0` → **`H Broer Equipment Sales & Service Inc | Aylmer, ON, CA | cats=equipment_rentals_tools`**
- `cossd-10385`: `Henry Technologies Ltd | Brantford, ON, CA | cats=0` → **`Henry Technologies Ltd | Brantford, ON, CA | cats=equipment_rentals_tools`**
- `cossd-10412`: `Iron Horse Earthworks | Rocky View, AB, CA | cats=3` → **`Iron Horse Earthworks | Rocky View County, AB, CA | cats=trucking_heavy_haul,matting_lease_civil,environmental_remediation_waste`**
- `cossd-10421`: `Summit Liability Solutions Inc | Swift Curretn, SK, CA | cats=1` → **`Summit Liability Solutions Inc | Swift Current, SK, CA | cats=environmental_remediation_waste`**
- `cossd-10477`: `IronGate Tubular Services | Corpus Christi, TX, US | cats=0` → **`IronGate Tubular Services | Corpus Christi, TX, US | cats=pipe_octg_supply`**
- `cossd-10545`: `MegaDeck Mats | Flower Mound, TX, US | cats=0` → **`MegaDeck Mats | Flower Mound, TX, US | cats=equipment_rentals_tools`**
- `cossd-10546`: `Presto Geosystems | Appleton, WI, US | cats=0` → **`Presto Geosystems | Appleton, WI, US | cats=equipment_rentals_tools`**
