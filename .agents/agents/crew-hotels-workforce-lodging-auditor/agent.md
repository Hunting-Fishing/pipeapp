---
name: crew-hotels-workforce-lodging-auditor
description: 20-Worker Parallel Google Maps Oil & Gas Crew Hotels, Workforce Suites & 30-Sector Gap-Fill Audit Agent covering 186 North American & International oilpatch, turnaround, and offshore heliport hubs.
---

# Oil & Gas Crew Hotels, Workforce Lodging & 30-Sector Gap-Fill Audit Agent

- **Primary Fleet Engine**: `tools/yellow_pages_agents/bot21_crew_hotels_oilfield_lodging_fleet.mjs --sync --agents 20`
- **Field Hygiene & Town Consolidation Engine**: `tools/yellow_pages_agents/bot15_full_consistency_auditor.mjs --apply --include-training`
- **Facet Count Indexer**: `tools/yellow_pages_agents/bot13_directory_facet_counts.mjs --apply --fix-cities`

## Verticals & 186 Oilpatch Crew Hubs Covered
1. **`crew_hotels_workforce_lodging` (`Crew Hotels, Extended-Stay & Oilfield Worker Rates`)**:
   - Audits **48 Canadian**, **102 US**, and **36 International** oilpatch, refinery turnaround, and offshore heliport crew hubs (`Grande Prairie`, `Fort McMurray`, `Nisku`, `Leduc`, `Drayton Valley`, `Bonnyville`, `Fort St. John`, `Estevan`, `Midland`, `Odessa`, `Pecos`, `Williston`, `Watford City`, `Hobbs`, `Carlsbad`, `Cotulla`, `Houma`, `Port Arthur`, `Gillette`, `Morgantown`, `Aberdeen`, `Stavanger`, `Abu Dhabi`, `Al Khobar`, `Karratha`, `Macae`, `Ciudad del Carmen`, `Georgetown`, `Port Harcourt`, `Singapore`, `Miri`, `Atyrau`, etc.).
   - Targets extended-stay kitchenette suites, CLC Lodging partners, rig-worker motor inns, and corporate crew hotels (`Pomeroy Inn & Suites`, `BCMInns`, `Podollan`, `Microtel`, `TownePlace Suites`, `Candlewood Suites`, `Staybridge Suites`, `Home2 Suites`, `WoodSpring Suites`, `My Place Hotel`, `Target Hospitality`, etc.) while strictly blocking B&Bs, hostels, Airbnbs, RV parks, tourist resorts/casinos, pet hotels, senior living, and residential apartments.
2. **Missing Yellow Pages Sector Top-Up Across Tier-1 Hubs**:
   - `scaffolding_insulation_coatings` (*Scaffolding, Insulation, Coatings & Rope Access*)
   - `marine_offshore_aviation` (*Offshore Marine Vessels, Diving, ROV & Aviation*)
   - `industrial_supply_ppe_workwear` (*Oilfield Supply Stores, Hose, Fasteners & FR Workwear*)
   - `lease_security_communications_it` (*Lease Security, Gate Guards & Remote Wellsite Comms*)

## Strict Geo & Verification Rules
- Enforces 100% canonical town/city/region names via `canonicalizeCityName`, `inferGeoFromNanpaPhone`, and `inferRegionFromCountryAndCity` (`0` duplicate town spellings, `0` empty-region hub splits).
- Never pre-verifies crawled listings (`verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`, `effectiveTier: "free_basic"`).
