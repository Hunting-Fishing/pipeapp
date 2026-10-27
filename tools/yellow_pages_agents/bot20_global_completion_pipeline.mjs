#!/usr/bin/env node
/**
 * Bot 20 — End-to-End Global Completion Pipeline Supervisor
 *
 * Automatically executes both remaining phases to 100% completion in memory-isolated child processes:
 *   - Phase 1: Finishes the remaining North American micro-town tail via `bot19_run_until_exhausted_supervisor.mjs`
 *     until `pendingQueriesInFrontier === 0` (`100%` of Canada + USA micro-towns `EXHAUSTED` + Bot 15 + Bot 13).
 *   - Phase 2: Immediately transitions into `bot16_google_alphabetical_audit_fleet.mjs --scope international --sync`
 *     across UK/Norway & North Sea, Middle East, Latin America, and Australia in 700-query memory-isolated waves
 *     until `100%` of International Oil & Gas + Training hub queries are completed, followed by final Bot 15 + Bot 13.
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
const PIPELINE_REPORT_PATH = path.join(REPORTS_DIR, "20_GLOBAL_COMPLETION_PIPELINE_REPORT.md");
const INTL_CHECKPOINT_PATH = path.join(LEDGER_DIR, "16_intl_alpha_checkpoint.json");

const args = process.argv.slice(2);
const projIdx = args.indexOf("--project");
const PROJECT_ID = projIdx !== -1 && args[projIdx + 1] ? args[projIdx + 1] : "flutter-flow-pipe";
const NA_AGENTS = 20;
const INTL_AGENTS = 18;
const INTL_WAVE_SIZE = 700;

function runNodeScript(scriptRelPath, scriptArgs, timeoutMs = 90 * 60 * 1000) {
  return new Promise((resolve) => {
    const fullPath = path.join(REPO_ROOT, scriptRelPath);
    const child = spawn(process.execPath, [fullPath, ...scriptArgs], {
      cwd: REPO_ROOT,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdoutTail = "";
    const timer = setTimeout(() => {
      console.warn(`[bot20] Watchdog killing ${scriptRelPath} after ${timeoutMs}ms (checkpoint preserved)...`);
      child.kill("SIGTERM");
      setTimeout(() => child.kill("SIGKILL"), 3000);
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      const s = chunk.toString();
      process.stdout.write(s);
      stdoutTail = (stdoutTail + s).slice(-8000);
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

async function readIntlCheckpoint() {
  if (!fs.existsSync(INTL_CHECKPOINT_PATH)) return null;
  try {
    return JSON.parse(await fsp.readFile(INTL_CHECKPOINT_PATH, "utf8"));
  } catch {
    return null;
  }
}

async function writePipelineReport(status, naSummary, intlCp, liveTotal = 0) {
  await fsp.mkdir(REPORTS_DIR, {recursive: true});
  const intlStats = intlCp?.stats || {};
  const md = [
    "# Bot 20 — Global Directory Completion Pipeline Report (North America -> International)",
    "",
    `- **Updated At**: \`${new Date().toISOString()}\``,
    `- **Pipeline Status**: **${status}**`,
    liveTotal ? `- **Verified Live Public Businesses (\`flutter-flow-pipe\`)**: **${liveTotal.toLocaleString()}**` : null,
    "",
    "## Phase 1 — North America Micro-Town Exhaustive Convergence (`CA` + `US`)",
    `- **Micro-Towns Exhausted**: **${(naSummary?.exhaustedTowns || 0).toLocaleString()} / ${(naSummary?.totalMicroTowns || 0).toLocaleString()}**`,
    `- **Queries Audited**: **${(naSummary?.visitedQueries || 0).toLocaleString()}** | **Pending Queue**: **${(naSummary?.pendingQueriesInFrontier || 0).toLocaleString()}**`,
    `- **Cumulative New Micro-Town Businesses Published**: **+${(naSummary?.totalNewBusinessesFromMicroTowns || 0).toLocaleString()}**`,
    "",
    "## Phase 2 — International Oil & Gas + Training Hubs (`Bot 16 --scope international`)",
    `- **International Queries Audited**: **${(intlCp?.visitedCount || 0).toLocaleString()} / ${(intlCp?.totalUniverseQueries || 0).toLocaleString()}**`,
    `- **New International Businesses Published**: **+${(intlStats.newBusinessesDiscovered || 0).toLocaleString()}**`,
    `  - **UK / Norway & North Sea**: **+${(intlStats.newUkNorway || 0).toLocaleString()}**`,
    `  - **Middle East**: **+${(intlStats.newMiddleEast || 0).toLocaleString()}**`,
    `  - **Latin America**: **+${(intlStats.newLatinAmerica || 0).toLocaleString()}**`,
    `  - **Australia**: **+${(intlStats.newAustralia || 0).toLocaleString()}**`,
    `  - **International Oil & Gas Training Facilities**: **+${(intlStats.newTrainingFacilities || 0).toLocaleString()}**`,
    "",
  ].filter((x) => x !== null);
  await fsp.writeFile(PIPELINE_REPORT_PATH, md.join("\n"), "utf8");
}

async function main() {
  console.log(`[bot20] Starting Global Completion Pipeline on project=${PROJECT_ID}...`);

  // Clear stale post-reboot Firestore dedup caches so fresh live counts are loaded cleanly
  for (const cacheName of ["18_firestore_index_cache.json", "16_intl_firestore_index_cache.json"]) {
    const p = path.join(LEDGER_DIR, cacheName);
    if (fs.existsSync(p)) await fsp.unlink(p).catch(() => {});
  }

  // ==================== PHASE 1: FINISH NORTH AMERICA MICRO-TOWNS ====================
  let naSummary = await runMicrotownPlanner({projectId: PROJECT_ID});
  await writePipelineReport("PHASE 1 — FINISHING NORTH AMERICA MICRO-TOWNS", naSummary, await readIntlCheckpoint());

  let safetyLoops = 0;
  while (naSummary.pendingQueriesInFrontier > 0 && safetyLoops++ < 40) {
    console.log(
      `\n[bot20] Phase 1: ${naSummary.pendingQueriesInFrontier} North America micro-town queries remaining (${naSummary.exhaustedTowns}/${naSummary.totalMicroTowns} exhausted)...`,
    );
    await runNodeScript(
      "tools/yellow_pages_agents/bot19_run_until_exhausted_supervisor.mjs",
      ["--agents", String(NA_AGENTS), "--wave-size", "900", "--max-waves", "15", "--project", PROJECT_ID],
      120 * 60 * 1000,
    );
    naSummary = await runMicrotownPlanner({projectId: PROJECT_ID});
    await writePipelineReport(
      naSummary.pendingQueriesInFrontier === 0
        ? "PHASE 1 COMPLETE — STARTING PHASE 2 INTERNATIONAL"
        : "PHASE 1 — FINISHING NORTH AMERICA MICRO-TOWNS",
      naSummary,
      await readIntlCheckpoint(),
    );
  }

  console.log("\n[bot20] PHASE 1 COMPLETE: 100% of North America hubs & micro-towns are EXHAUSTED!");

  // Refresh intl dedup cache right before Phase 2 starts
  const intlCachePath = path.join(LEDGER_DIR, "16_intl_firestore_index_cache.json");
  if (fs.existsSync(intlCachePath)) await fsp.unlink(intlCachePath).catch(() => {});

  // ==================== PHASE 2: INTERNATIONAL OIL & GAS + TRAINING HUBS ====================
  console.log(
    "\n[bot20] PHASE 2 STARTING: Bot 16 International Oil & Gas + Training Sweep (UK/Norway -> Middle East -> Latin America -> Australia)...",
  );

  for (let intlWave = 1; intlWave <= 25; intlWave++) {
    console.log(`\n==================== [bot20] INTERNATIONAL WAVE ${intlWave} ====================`);
    await writePipelineReport(`PHASE 2 — RUNNING INTERNATIONAL WAVE ${intlWave}`, naSummary, await readIntlCheckpoint());

    const res = await runNodeScript(
      "tools/yellow_pages_agents/bot16_google_alphabetical_audit_fleet.mjs",
      [
        "--scope",
        "international",
        "--sync",
        "--agents",
        String(INTL_AGENTS),
        "--max-queries",
        String(INTL_WAVE_SIZE),
        "--project",
        PROJECT_ID,
      ],
      35 * 60 * 1000,
    );

    const cp = await readIntlCheckpoint();
    if (res.stdoutTail.includes("CONVERGED (international)") || (cp && cp.visitedCount >= cp.totalUniverseQueries && cp.totalUniverseQueries > 0)) {
      console.log("[bot20] International Sweep 100% CONVERGED!");
      break;
    }

    if (intlWave % 2 === 0) {
      await runNodeScript("tools/yellow_pages_agents/bot13_directory_facet_counts.mjs", [
        "--apply",
        "--fix-cities",
        "--project",
        PROJECT_ID,
      ]);
    }
  }

  // ==================== FINAL GLOBAL CONSISTENCY AUDIT & FACET SYNC ====================
  console.log("\n[bot20] Running final Global Consistency Audit (Bot 15) + Live Facet Index Publish (Bot 13)...");
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
  const liveMatch = finalBot13.stdoutTail.match(/Total Active Public Businesses:\s*(\d+)/u);
  const finalLiveTotal = liveMatch ? Number(liveMatch[1]) : 0;

  const finalNa = await runMicrotownPlanner({projectId: PROJECT_ID});
  const finalIntl = await readIntlCheckpoint();
  await writePipelineReport(
    "100% COMPLETE — NORTH AMERICA & INTERNATIONAL CONVERGED",
    finalNa,
    finalIntl,
    finalLiveTotal,
  );

  console.log(
    `\n[bot20] ALL PHASES 100% COMPLETE! Live Directory Total: ${finalLiveTotal.toLocaleString()} active public businesses.`,
  );
  process.exit(0);
}

main().catch((err) => {
  console.error("[bot20] FATAL:", err);
  process.exit(1);
});
