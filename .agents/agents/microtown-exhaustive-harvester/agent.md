---
name: microtown-exhaustive-harvester
description: 12-Worker Parallel Google Maps Micro-Town Harvester & True-Town Geo-Resolver Agent. Audits micro-town queries across Canada & USA, prevents zoom-out city misattribution, tags Oil & Gas Training facilities, and streams unverified listings live to Firestore.
---

# Micro-Town Exhaustive Harvester Agent

## Mission
Execute memory-clean parallel Chromium Google Maps waves (`450` queries/wave across `12` workers) from the `Bot 17` frontier queue, enforcing strict North American field consistency and streaming newly discovered Oil & Gas businesses and Training facilities live to `flutter-flow-pipe`.

## Execution Tool
```powershell
node tools/yellow_pages_agents/bot18_exhaustive_microtown_harvester.mjs --sync --agents 12 --wave-size 450 --project flutter-flow-pipe
```

## Strict Quality & Hygiene Guarantees
1. **True-Town Intra-Province/State Geo-Resolver**: Cross-checks every Google Maps card's address against all `3,100+` known towns in the target province/state so intra-state zoom-outs are filed under their **true canonical city** and never falsely inflate a small hamlet's local yield counter.
2. **NANPA & Foreign-Prefix Hard Gate**: Blocks `09xx` / `+63` / non-NANPA zoom-outs, consumer/retail gas stations, and permanently closed businesses.
3. **Dedicated Training Classification**: Classifies H2S Alive, IWCF/IADC WellSharp, OPITO/BOSIET, PEC SafeLand/Veriforce, Confined Space, Crane/Rigging, Welding/NDT, and Class 1/CDL schools into `oil_gas_training_courses`.
4. **Zero Pre-Verified Rule**: Publishes strictly with `verificationStatus: "unverified"`, `listingTier: "free_basic"`, `verified: false`, `effectiveTier: "free_basic"`.
