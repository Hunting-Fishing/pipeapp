#!/usr/bin/env node
/**
 * Bot 19 — Autonomous Run-Until-Zero-New-Yield Micro-Town Convergence Supervisor
 *
 * Orchestrates continuous, memory-isolated discovery waves across all 3,100+ North American
 * (Canada -> USA) micro-towns until the adaptive frontier converges to 0 pending queries /
 * 0 new businesses:
 *
 *   Loop:
 *     1. Bot 17 (`runMicrotownPlanner`): Refresh town universe & escalate productive towns
 *        (`Stage 1 PROBE -> Stage 2 SECTOR -> Stage 3 A-Z -> Stage 4 TAIL -> EXHAUSTED`).
 *     2. If `pendingQueriesInFrontier === 0` (all micro-towns exhausted):
 *          Run final Bot 15 consistency audit + Bot 13 facet publish -> EXIT 0.
 *     3. Spawn isolated child process `bot18_exhaustive_microtown_harvester.mjs --sync`
 *        (destroying & recreating Chromium OS memory completely after every wave).
 *     4. Run `bot13_directory_facet_counts.mjs --apply --fix-cities` so `pipebuyer.com/services`
 *        reflects newly discovered businesses and micro-towns in real time after every wave.
 *     5. Update `data/yellow_pages/reports/19_EXHAUSTIVE_CONVERGENCE_REPORT.md`.
 */

import {spawn} from "node:child_process";
import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import {runMicrotownPlanner} from "./bot17_microtown_atlas_planner.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");
const SUPERVISOR_REPORT_PATH = path.join(REPORTS_DIR, "19_EXHAUSTIVE_CONVERGENCE_REPORT.md");
const HISTORY_JSON_PATH = path.join(LEDGER_DIR, "19_supervisor_wave_history.json");

const args = process.argv.slice(2);
const agentsIdx = args.indexOf("--agents");
const NUM_AGENTS = agentsIdx !== -1 ? Number(args[agentsIdx + 1] || 20) : 20;
const waveSizeIdx = args.indexOf("--wave-size");
const WAVE_SIZE = waveSizeIdx !== -1 ? Number(args[waveSizeIdx + 1] || 900) : 900;
const maxWavesIdx = args.indexOf("--max-waves");
const MAX_WAVES = maxWavesIdx !== -1 ? Number(args[maxWavesIdx + 1] || 999) : 999;
const countryIdx = args.indexOf("--country");
const COUNTRY_FILTER = countryIdx !== -1 ? String(args[countryIdx + 1] || "").toUpperCase() : "";
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";

function runNodeScript(scriptRelPath, scriptArgs, timeoutMs = 25 * 60 * 1000) {
  return new Promise((resolve) => {
    const fullPath = path.join(REPO_ROOT, scriptRelPath);
    const child = spawn(process.execPath, [fullPath, ...scriptArgs], {
      cwd: REPO_ROOT,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdoutTail = "";
    const timer = setTimeout(() => {
      console.warn(`[bot19] Watchdog killing child ${scriptRelPath} after ${timeoutMs}ms (checkpoint preserved)...`);
      child.kill("SIGTERM");
      setTimeout(() => child.kill("SIGKILL"), 3000);
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      const s = chunk.toString();
      process.stdout.write(s);
      stdoutTail = (stdoutTail + s).slice(-6000);
    });
    child.stderr.on("data", (chunk) => {
      process.stderr.write(chunk.toString());
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({code: code ?? 1, stdoutTail});
    });
  });
}

async function writeSupervisorReport(waveHistory, latestSummary, statusLabel) {
  await fsp.mkdir(REPORTS_DIR, {recursive: true});
  const md = [
    "# Bot 19 — Autonomous Micro-Town Exhaustive Convergence Supervisor Report",
    "",
    `- **Updated At**: \`${new Date().toISOString()}\``,
    `- **Supervisor Status**: **${statusLabel}**`,
    `- **Total Micro-Towns Tracked**: **${latestSummary.totalMicroTowns.toLocaleString()}** (\`CA\`: **${latestSummary.caMicroTowns.toLocaleString()}**, \`US\`: **${latestSummary.usMicroTowns.toLocaleString()}**)`,
    `- **Exhausted Micro-Towns (Zero Remaining Yield)**: **${latestSummary.exhaustedTowns.toLocaleString()} / ${latestSummary.totalMicroTowns.toLocaleString()}**`,
    `- **Active Escalated Micro-Towns**: Stage 2=\`${latestSummary.stage2Sector}\`, Stage 3=\`${latestSummary.stage3Alpha}\`, Stage 4=\`${latestSummary.stage4Tail}\` | Stage 1 Pending=\`${latestSummary.stage1Probe}\``,
    `- **Queries Completed**: **${latestSummary.visitedQueries.toLocaleString()}** | **Current Stage Pending Queue**: **${latestSummary.pendingQueriesInFrontier.toLocaleString()}**`,
    `- **Cumulative New Micro-Town Businesses Published**: **+${latestSummary.totalNewBusinessesFromMicroTowns.toLocaleString()}**`,
    "",
    "## Completed Wave Ledger",
    "",
    "| Wave | Queries Audited | New Businesses | Cumulative Micro-Town Yield | Exhausted Towns | Live Directory Total |",
    "| ---: | ---: | ---: | ---: | ---: | ---: |",
    ...waveHistory.map(
      (w) =>
        `| ${w.wave} | ${w.waveQueries.toLocaleString()} | **+${w.waveNew.toLocaleString()}** | **+${w.cumNew.toLocaleString()}** | ${w.exhausted.toLocaleString()} | **${w.liveTotal ? w.liveTotal.toLocaleString() : "—"}** |`,
    ),
    "",
  ];
  await fsp.writeFile(SUPERVISOR_REPORT_PATH, md.join("\n"), "utf8");
}

async function loadWaveHistory() {
  await fsp.mkdir(LEDGER_DIR, {recursive: true});
  if (fs.existsSync(HISTORY_JSON_PATH)) {
    try {
      return JSON.parse(await fsp.readFile(HISTORY_JSON_PATH, "utf8"));
    } catch (_) {}
  }
  if (fs.existsSync(SUPERVISOR_REPORT_PATH)) {
    try {
      const md = await fsp.readFile(SUPERVISOR_REPORT_PATH, "utf8");
      const rows = [];
      for (const line of md.split("\n")) {
        const m = line.match(
          /^\|\s*(\d+)\s*\|\s*([\d,]+)\s*\|\s*\*\*\+([\d,]+)\*\*\s*\|\s*\*\*\+([\d,]+)\*\*\s*\|\s*([\d,]+)\s*\|\s*\*\*([\d,—]+)\*\*\s*\|/u,
        );
        if (m) {
          rows.push({
            wave: Number(m[1]),
            waveQueries: Number(m[2].replace(/,/gu, "")),
            waveNew: Number(m[3].replace(/,/gu, "")),
            cumNew: Number(m[4].replace(/,/gu, "")),
            exhausted: Number(m[5].replace(/,/gu, "")),
            liveTotal: Number(m[6].replace(/\D+/gu, "")) || 0,
          });
        }
      }
      if (rows.length > 0) {
        await fsp.writeFile(HISTORY_JSON_PATH, JSON.stringify(rows, null, 2), "utf8");
        return rows;
      }
    } catch (_) {}
  }
  return [];
}

async function main() {
  console.log(
    `[bot19] Starting Autonomous Run-Until-Exhausted Micro-Town Supervisor (agents=${NUM_AGENTS}, waveSize=${WAVE_SIZE}, maxWaves=${MAX_WAVES}, project=${PROJECT_ID})...`,
  );

  const waveHistory = await loadWaveHistory();
  let startWaveNum = waveHistory.length > 0 ? waveHistory[waveHistory.length - 1].wave + 1 : 1;
  let lastKnownLiveTotal = waveHistory.length > 0 ? waveHistory[waveHistory.length - 1].liveTotal || 20049 : 20049;
  let prevCumNew = 0;

  for (let i = 0; i < MAX_WAVES; i++) {
    const wave = startWaveNum + i;
    console.log(`\n==================== [bot19] CONVERGENCE WAVE ${wave} ====================`);
    const summaryBefore = await runMicrotownPlanner({projectId: PROJECT_ID});
    if (i === 0) prevCumNew = summaryBefore.totalNewBusinessesFromMicroTowns;

    await writeSupervisorReport(waveHistory, summaryBefore, `RUNNING WAVE ${wave}`);

    if (summaryBefore.pendingQueriesInFrontier === 0) {
      console.log("[bot19] CONVERGED! 0 pending queries remaining across all North American micro-towns!");
      await runNodeScript("tools/yellow_pages_agents/bot15_full_consistency_auditor.mjs", [
        "--apply",
        "--include-training",
        "--project",
        PROJECT_ID,
      ]);
      const finalBot13 = await runNodeScript("tools/yellow_pages_agents/bot13_directory_facet_counts.mjs", [
        "--apply",
        "--fix-cities",
        "--project",
        PROJECT_ID,
      ]);
      const finalMatch = finalBot13.stdoutTail.match(/Total Active Public Businesses:\s*(\d+)/u);
      if (finalMatch && waveHistory.length > 0) {
        waveHistory[waveHistory.length - 1].liveTotal = Number(finalMatch[1]);
        await fsp.writeFile(HISTORY_JSON_PATH, JSON.stringify(waveHistory, null, 2), "utf8");
      }
      const verifiedFinalSummary = await runMicrotownPlanner({projectId: PROJECT_ID});
      await writeSupervisorReport(waveHistory, verifiedFinalSummary, "CONVERGED — 100% MICRO-TOWNS EXHAUSTED");
      process.exit(0);
    }

    const bot18Args = [
      "--sync",
      "--agents",
      String(NUM_AGENTS),
      "--wave-size",
      String(WAVE_SIZE),
      "--project",
      PROJECT_ID,
    ];
    if (COUNTRY_FILTER) bot18Args.push("--country", COUNTRY_FILTER);

    const prevVisited = summaryBefore.visitedQueries;
    await runNodeScript("tools/yellow_pages_agents/bot18_exhaustive_microtown_harvester.mjs", bot18Args);

    const summaryAfter = await runMicrotownPlanner({projectId: PROJECT_ID});
    const waveNew = Math.max(0, summaryAfter.totalNewBusinessesFromMicroTowns - prevCumNew);
    const waveQueries = Math.max(0, summaryAfter.visitedQueries - prevVisited);
    prevCumNew = summaryAfter.totalNewBusinessesFromMicroTowns;

    let liveTotal = lastKnownLiveTotal + waveNew;
    if (wave % 4 === 0 || summaryAfter.pendingQueriesInFrontier === 0) {
      const bot13Res = await runNodeScript("tools/yellow_pages_agents/bot13_directory_facet_counts.mjs", [
        "--apply",
        "--fix-cities",
        "--project",
        PROJECT_ID,
      ]);
      const liveMatch = bot13Res.stdoutTail.match(/Total Active Public Businesses:\s*(\d+)/u);
      if (liveMatch) liveTotal = Number(liveMatch[1]);
    }
    lastKnownLiveTotal = liveTotal;

    waveHistory.push({
      wave,
      waveQueries,
      waveNew,
      cumNew: summaryAfter.totalNewBusinessesFromMicroTowns,
      exhausted: summaryAfter.exhaustedTowns,
      liveTotal,
    });
    await fsp.writeFile(HISTORY_JSON_PATH, JSON.stringify(waveHistory, null, 2), "utf8");

    await writeSupervisorReport(waveHistory, summaryAfter, `COMPLETED WAVE ${wave}`);
    console.log(
      `[bot19] Wave ${wave} Summary: +${waveNew} new micro-town businesses (${waveQueries} queries) | Live Directory Total: ~${liveTotal} | Exhausted Towns: ${summaryAfter.exhaustedTowns}/${summaryAfter.totalMicroTowns} | Pending Queue: ${summaryAfter.pendingQueriesInFrontier}`,
    );
  }

  const finalSummary = await runMicrotownPlanner({projectId: PROJECT_ID});
  await writeSupervisorReport(waveHistory, finalSummary, `PAUSED AT MAX_WAVES=${MAX_WAVES} (CHECKPOINT SAVED)`);
  console.log(`[bot19] Reached --max-waves ${MAX_WAVES}; checkpoint saved cleanly.`);
  process.exit(0);
}

main().catch((err) => {
  console.error("[bot19] FATAL:", err);
  process.exit(1);
});
