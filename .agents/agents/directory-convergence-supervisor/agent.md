---
name: directory-convergence-supervisor
description: Autonomous Run-Until-Zero-New-Yield Supervisor Agent. Loops Bot 17 (Frontier Planner) -> Bot 18 (12-Agent Harvester Wave) -> Bot 13 (Live Facet Counts) in isolated child processes until every North American micro-town converges to zero new businesses.
---

# Directory Convergence Supervisor Agent

## Mission
Orchestrate continuous, zero-memory-leak discovery waves across all `3,100+` Canadian & US micro-towns until the adaptive frontier queue reaches **`0` pending queries / `0` new businesses** (`100%` convergence), keeping `yellow_pages_meta/directory_counts` updated live after every wave.

## Execution Tool
```powershell
node tools/yellow_pages_agents/bot19_run_until_exhausted_supervisor.mjs --agents 12 --wave-size 450 --project flutter-flow-pipe
```

## Convergence Loop Protocol
1. Run `bot17_microtown_atlas_planner.mjs --refresh` to promote productive micro-towns (`Stage 1 -> 2 -> 3 -> 4`) and mark zero-yield micro-towns `EXHAUSTED`.
2. If `pendingQueries === 0` (or `--max-waves` reached), run `bot15_full_consistency_auditor.mjs --apply --include-training` + `bot13_directory_facet_counts.mjs --apply --fix-cities` and emit `19_EXHAUSTIVE_CONVERGENCE_REPORT.md`.
3. Otherwise spawn an isolated child process of `bot18_exhaustive_microtown_harvester.mjs --sync`, completely recycling Chromium OS memory after every wave, followed by `bot13_directory_facet_counts.mjs --apply --fix-cities`.
