---
name: microtown-frontier-planner
description: North America (Canada -> USA) Oilpatch Micro-Town Atlas & Dynamic Frontier Escalation Planner Agent. Builds and updates the 3,100+ micro-town discovery state machine across Stages 1-4 until every town converges to zero new yield.
---

# Micro-Town Frontier Planner Agent

## Mission
Maintain the exhaustive North American (`Canada` first, `USA` second) Oil & Gas + Training micro-town discovery frontier (`data/yellow_pages/ledger/17_microtown_frontier_state.json`) by merging:
1. The **Curated Unlisted Oilpatch Micro-Town Atlas** (`650+` Canadian & US oilfield hamlets, pipeline terminals, and field yards).
2. Live Firestore `yellow_pages_meta/directory_counts` (`townsPacked` — `2,670+` proven North American towns).
3. Newly discovered rural towns extracted dynamically from Google Maps street addresses during harvesting.

## Execution Tool
```powershell
node tools/yellow_pages_agents/bot17_microtown_atlas_planner.mjs --refresh --project flutter-flow-pipe
```

## Adaptive Escalation Contract
- **Stage 1 (`PROBE`)**: 3 broad discovery + training queries per micro-town. Towns with `0` local oilfield cards transition immediately to `EXHAUSTED`. Towns with `>= 1` new business or `>= 2` local oilfield cards escalate to Stage 2.
- **Stage 2 (`SECTOR_SWEEP`)**: 15 specialized oilfield sector + accredited safety/well-control training queries. Escalates to Stage 3 if `stageNewBusinesses >= 1`, else `EXHAUSTED`.
- **Stage 3 (`ALPHA_SWEEP`)**: 26 strict `A -> Z` oilfield & energy queries. Escalates to Stage 4 if `stageNewBusinesses >= 3`, else `EXHAUSTED`.
- **Stage 4 (`EXTENDED_SYNONYM_TAIL`)**: 10 long-tail field & course queries (`Roustabout`, `Saltwater Disposal`, `B-Pressure Welding`, `Slickline`, `Rig Moving`, `CDL / Crane School`), then `EXHAUSTED`.
