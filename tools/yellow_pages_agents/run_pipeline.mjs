#!/usr/bin/env node
/**
 * Unified Single-Batch Orchestrator for the 8-Bot PipeBuyer Yellow Pages Suite:
 *   1. Bot 1 — Read-Only Firestore Database Inventory (`flutter-flow-pipe` & `pipebuyer-5c77f`)
 *   2. Bot 2 — COSSD Full Universe Analyzer + Scaled North America Batch Crawler (`cossd.com`)
 *   3. Bot 6 — Multi-Channel Open-Internet Oil & Gas Crawler (SEC EDGAR 8 SICs + OpenStreetMap + Corporate Web)
 *   4. Bot 7 — Federal USDOT / FMCSA Active Oilfield Equipment, Pipe & Fluid Carrier Census Crawler
 *   5. Bot 8 — State & Provincial Oil & Gas Regulator / Active Licence Crawler (Texas NAICS + Alberta Licences)
 *   6. Bot 3 — 4-Ledger Deduplicator + Domain-Cached Live 2026 Operations & Old->New Phone Auditor
 *   7. Bot 4 — 2015/2016 Physical Yellow Book & Google Drive Page Photo Tracker
 *   8. Bot 5 — Large-Scale JSONL & Firestore Reconciler (`--dry-run` default)
 *
 * For continuous 100% full-universe execution, run `overnight_master_crawler.mjs`!
 */

import {runFirestoreInventory} from "./bot1_firestore_inventory.mjs";
import {runNorthAmericaDiscovery} from "./bot2_cossd_north_america_discovery.mjs";
import {runOpenWebOilGasCrawler} from "./bot6_open_web_oil_gas_crawler.mjs";
import {runUsdotFmcsaOilfieldCrawler} from "./bot7_usdot_fmcsa_oilfield_carriers.mjs";
import {runEnergyRegulatorRegistries} from "./bot8_energy_regulator_registries.mjs";
import {runLiveOperationsAudit} from "./bot3_live_operations_phone_auditor.mjs";
import {runBookDrivePageAuditor} from "./bot4_book_drive_page_auditor.mjs";
import {runFirestorePublisherSync} from "./bot5_firestore_publisher_sync.mjs";

async function main() {
  const limitIdx = process.argv.indexOf("--limit");
  const limit = limitIdx !== -1 ? Number(process.argv[limitIdx + 1] || 500) : 500;
  const apply = process.argv.includes("--apply");
  const projIdx = process.argv.indexOf("--project");
  const projectId = projIdx !== -1 ? process.argv[projIdx + 1] : "pipebuyer-5c77f";

  console.log("=== PipeBuyer Yellow Pages 8-Bot North America Discovery & Audit Pipeline ===");
  await runFirestoreInventory();
  await Promise.all([
    runNorthAmericaDiscovery({limit, concurrency: 14, resume: true}),
    runOpenWebOilGasCrawler(),
    runUsdotFmcsaOilfieldCrawler({maxUsPages: 18, maxCaPages: 4}),
    runEnergyRegulatorRegistries({maxTxPages: 6}),
  ]);
  await runLiveOperationsAudit({domainConcurrency: 36});
  await runBookDrivePageAuditor();
  await runFirestorePublisherSync({apply, projectId});
  console.log("=== 8-Bot Pipeline Completed Successfully ===");
}

main().catch((err) => {
  console.error("[Pipeline Fatal]", err);
  process.exitCode = 1;
});
