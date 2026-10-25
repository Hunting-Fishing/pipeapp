#!/usr/bin/env node
/**
 * PipeBuyer Yellow Pages — Continuous Full-Scale Overnight Master Crawler Daemon
 *
 * Continuously executes the complete 8-Bot North America (Canada + USA) Oil & Gas
 * discovery, federal/provincial registry ingestion, live 2026 website/DNS/phone audit,
 * and Firestore bundle preparation until 100% of the target universe is complete:
 *
 *   Phase 1 — Multi-Channel Authoritative Open-Internet & Government Ingestion:
 *     - Bot 1: Firestore Staging & Production baseline check
 *     - Bot 7: Federal USDOT / FMCSA Active 2023–2026 Oilfield Equipment, Pipe & Tank Fleets
 *     - Bot 8: Texas Comptroller Active Oil & Gas NAICS + Edmonton & Calgary Commercial Licences
 *     - Bot 6: Expanded US & Canadian SEC EDGAR (8 Oilfield/Pipe/Valve/Pipeline SICs) + Direct Web
 *
 *   Phase 2 — Continuous Self-Healing Wave Crawl Across 100% of `www.cossd.com`:
 *     - Loops in polite, concurrent waves (`--wave-size 1000`, `concurrency: 18`) across all
 *       `17,471` Oil & Gas / B2B candidates on `cossd.com` until `remainingInUniverse === 0`.
 *     - Atomically checkpoints progress on every wave (`02_cossd_checkpoint.json`) and updates
 *       `data/yellow_pages/reports/00_OVERNIGHT_PROGRESS_DASHBOARD.md`.
 *     - Periodically runs incremental Bot 3 (Domain-Cached Live DNS/HTTP/Phone Audit) + Bot 5.
 *
 *   Phase 3 — Final 100% North America Live Operations Audit & Firestore Bundle Generation:
 *     - Runs final Bot 3 + Bot 4 + Bot 5 pass across 100% of discovered records and writes
 *       `05_private_companies.jsonl`, `05_public_entries.jsonl`, and final executive reports.
 */

import fs from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";

import {runFirestoreInventory} from "./bot1_firestore_inventory.mjs";
import {runNorthAmericaDiscovery} from "./bot2_cossd_north_america_discovery.mjs";
import {runLiveOperationsAudit} from "./bot3_live_operations_phone_auditor.mjs";
import {runBookDrivePageAuditor} from "./bot4_book_drive_page_auditor.mjs";
import {runFirestorePublisherSync} from "./bot5_firestore_publisher_sync.mjs";
import {runOpenWebOilGasCrawler} from "./bot6_open_web_oil_gas_crawler.mjs";
import {runUsdotFmcsaOilfieldCrawler} from "./bot7_usdot_fmcsa_oilfield_carriers.mjs";
import {runEnergyRegulatorRegistries} from "./bot8_energy_regulator_registries.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function writeAtomic(targetPath, content) {
  const tmp = `${targetPath}.tmp-${process.pid}`;
  await fs.writeFile(tmp, content, "utf8");
  await fs.rename(tmp, targetPath);
}

function formatDuration(ms) {
  const sec = Math.round(ms / 1000);
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m > 0 ? `${m}m ${s}s` : `${s}s`;
}

async function writeLiveDashboard(state) {
  await writeAtomic(
    path.join(LEDGER_DIR, "00_overnight_status.json"),
    JSON.stringify(state, null, 2),
  );

  const pct =
    state.cossdTargetUniverse > 0
      ? Math.min(100, ((state.cossdVisited / state.cossdTargetUniverse) * 100)).toFixed(1)
      : "0.0";

  const md = [
    "# PipeBuyer Yellow Pages — Full-Scale Continuous Overnight Crawl Dashboard",
    "",
    `- **Status**: **\`${state.status}\`**`,
    `- **Started At**: \`${state.startedAt}\``,
    `- **Last Checkpoint**: \`${new Date().toISOString()}\` *(Elapsed: ${formatDuration(Date.now() - state.startEpochMs)})*`,
    `- **Memory RSS**: \`${Math.round(process.memoryUsage().rss / 1024 / 1024)} MB\``,
    "",
    "## 1. Multi-Channel Discovery Progress",
    "",
    "| Channel / Bot | Status | Discovered Records | Notes |",
    "| :--- | :---: | ---: | :--- |",
    `| **Bot 2 — \`www.cossd.com\` Full Sitemap** | \`${state.cossdRemaining === 0 ? "100% COMPLETE" : `Wave ${state.wave}`}\` | **${state.cossdImported.toLocaleString()}** | Visited **${state.cossdVisited.toLocaleString()} / ${state.cossdTargetUniverse.toLocaleString()}** (**${pct}%**) • Remaining: **${state.cossdRemaining.toLocaleString()}** |`,
    `| **Bot 7 — USDOT / FMCSA Oilfield Fleets** | \`COMPLETE\` | **${state.usdotCount.toLocaleString()}** | Active 2023–2026 CA + US Oilfield, Pipe & Tank Fleets |`,
    `| **Bot 8 — State & Provincial Licences/NAICS** | \`COMPLETE\` | **${state.regulatorCount.toLocaleString()}** | Active Texas Oil & Gas NAICS + Edmonton & Calgary Licences |`,
    `| **Bot 6 — SEC EDGAR (8 SICs) & Direct Web** | \`COMPLETE\` | **${state.openWebCount.toLocaleString()}** | Active SEC Oilfield/OCTG/Valve Filers + Corporate Sites |`,
    "",
    "## 2. Latest Cross-Deduplicated Live 2026 Audit & Publication Bundle",
    "",
    `- **Total Unique North American Companies Audited**: **${(state.auditStats?.totalAudited || 0).toLocaleString()}** (Canada: **${(state.auditStats?.byCountry?.CA || 0).toLocaleString()}**, USA: **${(state.auditStats?.byCountry?.US || 0).toLocaleString()}**)`,
    `- **Unique Corporate Domains DNS/HTTP Probed**: **${(state.auditStats?.uniqueDomainsCached || 0).toLocaleString()}**`,
    `- **Confirmed Active in Operation (2026)**: **${((state.auditStats?.activeInOperation || 0) + (state.auditStats?.activeNumberUpdated || 0)).toLocaleString()}**`,
    `- **\`Old Number -> New Number\` Updates Caught**: **${(state.auditStats?.activeNumberUpdated || 0).toLocaleString()}**`,
    `- **Closed / Liquidated / Dead Domains Blocked**: **${(state.auditStats?.closedOrDomainInactive || 0).toLocaleString()}**`,
    `- **Public Website Eligible Entries (\`05_public_entries.jsonl\`)**: **${(state.syncCounts?.publicWebsiteEntriesEligible || 0).toLocaleString()}**`,
    `- **Private Admin / Contact Center Records (\`05_private_companies.jsonl\`)**: **${(state.syncCounts?.privateCompanyRecordsPrepared || 0).toLocaleString()}**`,
    "",
  ];

  await writeAtomic(path.join(REPORTS_DIR, "00_OVERNIGHT_PROGRESS_DASHBOARD.md"), md.join("\n"));
}

async function runWithRetry(label, fn, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      return await fn();
    } catch (err) {
      console.error(`[Master Retry ${attempt}/${retries}] ${label}: ${err.message}`);
      if (attempt === retries) throw err;
      await sleep(1500 * attempt);
    }
  }
  return null;
}

async function main() {
  const args = process.argv.slice(2);
  const waveSizeIdx = args.indexOf("--wave-size");
  const maxWavesIdx = args.indexOf("--max-waves");
  const waveSize = waveSizeIdx !== -1 ? Number(args[waveSizeIdx + 1] || 1000) : 1000;
  const maxWaves = maxWavesIdx !== -1 ? Number(args[maxWavesIdx + 1] || 999) : 999;

  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  const state = {
    status: "STARTING_PHASE_1_REGISTRIES",
    startedAt: new Date().toISOString(),
    startEpochMs: Date.now(),
    wave: 0,
    cossdVisited: 0,
    cossdTargetUniverse: 17471,
    cossdRemaining: 17471,
    cossdImported: 0,
    usdotCount: 0,
    regulatorCount: 0,
    openWebCount: 0,
    auditStats: null,
    syncCounts: null,
  };

  console.log("=== PipeBuyer Yellow Pages Continuous Full-Universe Master Crawler ===");
  await writeLiveDashboard(state);

  // -------------------------------------------------------------------------
  // PHASE 1: Firestore Baseline + Federal USDOT + State/Provincial Regulators + SEC/Open Web
  // -------------------------------------------------------------------------
  await runWithRetry("Bot 1 Firestore Inventory", () => runFirestoreInventory());

  const isFresh = (iso) => {
    const age = Date.now() - Date.parse(iso || 0);
    return age >= 0 && age < 6 * 3600 * 1000;
  };

  let u7Cached = null;
  let r8Cached = null;
  let o6Cached = null;
  if (!args.includes("--force-phase1")) {
    try {
      const u7 = JSON.parse(await fs.readFile(path.join(LEDGER_DIR, "07_usdot_oilfield_carriers.json"), "utf8"));
      if (isFresh(u7.generatedAt) && u7.totalHighSignalOilfieldCarriers > 0) u7Cached = u7;
    } catch (_) {}
    try {
      const r8 = JSON.parse(await fs.readFile(path.join(LEDGER_DIR, "08_regulator_registries.json"), "utf8"));
      if (isFresh(r8.generatedAt) && r8.totalRegulatorVerifiedCompanies > 0) r8Cached = r8;
    } catch (_) {}
    try {
      const o6 = JSON.parse(await fs.readFile(path.join(LEDGER_DIR, "06_open_web_discovered.json"), "utf8"));
      if (isFresh(o6.generatedAt) && (o6.byChannel?.directOilpatchCorporateVerify || 0) >= 60) o6Cached = o6;
    } catch (_) {}
  }

  const [usdotOut, regOut, openWebOut] = await Promise.all([
    u7Cached
      ? Promise.resolve(u7Cached)
      : runWithRetry("Bot 7 USDOT/FMCSA Census", () =>
          runUsdotFmcsaOilfieldCrawler({maxUsPages: 18, maxCaPages: 4}),
        ),
    r8Cached
      ? Promise.resolve(r8Cached)
      : runWithRetry("Bot 8 Regulator Registries", () =>
          runEnergyRegulatorRegistries({maxTxPages: 6}),
        ),
    o6Cached
      ? Promise.resolve(o6Cached)
      : runWithRetry("Bot 6 SEC EDGAR & Open Web", () => runOpenWebOilGasCrawler()),
  ]);

  state.usdotCount = usdotOut?.totalHighSignalOilfieldCarriers || 0;
  state.regulatorCount = regOut?.totalRegulatorVerifiedCompanies || 0;
  state.openWebCount = openWebOut?.totalUniqueNonCossdDiscovered || 0;
  state.status = "RUNNING_PHASE_2_COSSD_FULL_UNIVERSE";
  await writeLiveDashboard(state);

  // -------------------------------------------------------------------------
  // PHASE 2: Continuous Self-Healing Wave Loop Across 100% of `www.cossd.com`
  // -------------------------------------------------------------------------
  while (state.wave < maxWaves) {
    state.wave += 1;
    const waveStart = Date.now();
    const cossdOut = await runWithRetry(`Bot 2 Wave ${state.wave}`, () =>
      runNorthAmericaDiscovery({
        limit: waveSize,
        concurrency: 18,
        resume: true,
        skipRobotsIfResuming: state.wave > 1,
      }),
    );

    state.cossdVisited = cossdOut.cossdUniverseSummary.visitedSoFar;
    state.cossdTargetUniverse = cossdOut.cossdUniverseSummary.importableOilAndGasUniverse;
    state.cossdRemaining = cossdOut.cossdUniverseSummary.remainingInUniverse;
    state.cossdImported = cossdOut.totalDiscovered;

    console.log(
      `[Wave ${state.wave}] Crawled ${cossdOut.crawledUrlsInThisWave} URLs in ${formatDuration(Date.now() - waveStart)} | Imported: ${state.cossdImported} | Remaining in COSSD Universe: ${state.cossdRemaining}`,
    );

    // Run incremental live domain audit & sync on Wave 1 and every 5th wave (plus final wave in Phase 3)
    if (state.wave === 1 || state.wave % 5 === 0) {
      state.status = `AUDITING_CHECKPOINT_WAVE_${state.wave}`;
      const auditOut = await runWithRetry(`Bot 3 Incremental Audit Wave ${state.wave}`, () =>
        runLiveOperationsAudit({domainConcurrency: 40}),
      );
      const syncOut = await runWithRetry(`Bot 5 Incremental Sync Wave ${state.wave}`, () =>
        runFirestorePublisherSync({apply: false}),
      );
      state.auditStats = auditOut.stats;
      state.syncCounts = syncOut.counts;
      state.status = "RUNNING_PHASE_2_COSSD_FULL_UNIVERSE";
    }

    await writeLiveDashboard(state);

    if (state.cossdRemaining === 0 || cossdOut.crawledUrlsInThisWave === 0) {
      console.log(`[Phase 2 Complete] 100% of COSSD Oil & Gas universe visited (${state.cossdVisited} URLs)!`);
      break;
    }
  }

  // -------------------------------------------------------------------------
  // PHASE 3: Final Complete Live 2026 Domain/Phone Audit + Book Manifest + Firestore Bundle
  // -------------------------------------------------------------------------
  state.status = "RUNNING_PHASE_3_FINAL_AUDIT_AND_SYNC";
  await writeLiveDashboard(state);

  const finalAudit = await runWithRetry("Bot 3 Final Complete Audit", () =>
    runLiveOperationsAudit({domainConcurrency: 40}),
  );
  await runWithRetry("Bot 4 Book Manifest Check", () => runBookDrivePageAuditor({}));
  const finalSync = await runWithRetry("Bot 5 Final Firestore Bundle", () =>
    runFirestorePublisherSync({apply: false}),
  );

  state.auditStats = finalAudit.stats;
  state.syncCounts = finalSync.counts;
  state.status =
    state.cossdRemaining === 0 ? "COMPLETED_100_PERCENT" : `PAUSED_AT_WAVE_${state.wave}`;
  await writeLiveDashboard(state);

  console.log(
    `=== FULL-SCALE CRAWL ${state.status} in ${formatDuration(Date.now() - state.startEpochMs)} | Audited: ${state.auditStats.totalAudited} | Public Ready: ${state.syncCounts.publicWebsiteEntriesEligible} ===`,
  );
}

main().catch((err) => {
  console.error("[Overnight Master Fatal Error]", err);
  process.exitCode = 1;
});
