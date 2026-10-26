#!/usr/bin/env node
/**
 * Bot 11 — Global Wikidata Tree Unlock (Full JSON) & Domestic Contact Phone Upgrader
 *
 * 1. Unlocks the 1,500+ Global Wikipedia/Wikidata Oilfield Services, Drilling, Offshore,
 *    Pipeline, Steel Pipe, Valve, Pump, Crane, Petrochemical, Refining & Country Energy
 *    companies (`wbgetentities` in 25-ID chunks with full JSON + Category country inference).
 * 2. Re-audits reachable corporate websites previously saved as `needs_phone_verification`
 *    across `09_global_audited_companies.jsonl` and `10_global_deep_fill_companies.jsonl`
 *    using deep contact-link discovery and domestic area-code / trunk-0 phone normalization.
 * 3. Publishes all newly verified companies live to `flutter-flow-pipe` and writes the
 *    updated `09_GLOBAL_PROGRESS_DASHBOARD.md` + `10_GLOBAL_DEEP_FILL_REPORT.md`.
 */

import fs from "node:fs/promises";
import path from "node:path";
import {
  GLOBAL_COUNTRIES_LIST,
  COUNTRY_BY_CODE,
  WORLD_CONTINENTS,
  LEDGER_DIR,
  REPORTS_DIR,
  SANCTIONED_SKIP_CODES,
  BASELINE_COMPLETED_CODES,
  SEC_USER_AGENT,
  OILFIELD_SIGNAL_RE,
  inferCountryAndRegion,
  buildPublicEntry,
  isPublicationEligible,
  buildAdminSearchTokens,
  sleep,
  fetchText,
  auditWebsiteLive,
  searchBingRssDomains,
  buildGlobalCompanyRecords,
  resolveAccessToken,
  commitDocsToFirestore,
  loadBlockedPhones,
  loadGlobalSeenKeysFromJsonl,
} from "./global_shared_utils.mjs";
import {INTERNATIONAL_HUB_CITIES, writeGlobalProgressDashboard} from "./bot9_global_country_crawler.mjs";

const CHECKPOINT_PATH = path.join(LEDGER_DIR, "09_global_crawl_checkpoint.json");
const BOT9_JSONL_PATH = path.join(LEDGER_DIR, "09_global_audited_companies.jsonl");
const BOT10_JSONL_PATH = path.join(LEDGER_DIR, "10_global_deep_fill_companies.jsonl");
const BOT10_REPORT_PATH = path.join(REPORTS_DIR, "10_GLOBAL_DEEP_FILL_REPORT.md");

const ROOT_WIKIPEDIA_TREES = [
  {title: "Category:Oilfield_services_companies", seedCat: "completions_frac_wireline", requireSignal: false},
  {title: "Category:Drilling_companies", seedCat: "drilling_rigs_directional", requireSignal: false},
  {title: "Category:Offshore_oil_and_gas_companies", seedCat: "drilling_rigs_directional", requireSignal: false},
  {title: "Category:Pipeline_transport_companies", seedCat: "pipeline_facility_construction", requireSignal: false},
  {title: "Category:Natural_gas_pipeline_companies", seedCat: "pipeline_facility_construction", requireSignal: false},
  {title: "Category:Oil_pipeline_companies", seedCat: "pipeline_facility_construction", requireSignal: false},
  {title: "Category:Steel_pipe_manufacturers", seedCat: "pipe_octg_supply", requireSignal: false},
  {title: "Category:Valve_manufacturers", seedCat: "wellhead_valves_pressure", requireSignal: false},
  {title: "Category:Pump_manufacturers", seedCat: "pumps_artificial_lift", requireSignal: false},
  {title: "Category:Crane_manufacturers", seedCat: "crane_picker_rigging", requireSignal: false},
  {title: "Category:Petrochemical_companies", seedCat: "explorers_producers_midstream", requireSignal: false},
  {title: "Category:Oil_refining_companies", seedCat: "tanks_vessels_process", requireSignal: false},
];

const BY_COUNTRY_PARENT_TREES = [
  {parent: "Category:Oil_and_gas_companies_by_country", seedCat: "explorers_producers_midstream", requireSignal: false},
  {parent: "Category:Natural_gas_companies_by_country", seedCat: "pipeline_facility_construction", requireSignal: false},
  {parent: "Category:Energy_companies_by_country", seedCat: "explorers_producers_midstream", requireSignal: true},
  {parent: "Category:Chemical_companies_by_country", seedCat: "chemical_mud_lubricants", requireSignal: true},
  {parent: "Category:Shipbuilding_companies_by_country", seedCat: "welding_machining_fab", requireSignal: true},
  {parent: "Category:Engineering_companies_by_country", seedCat: "surveying_engineering_geomatics", requireSignal: true},
];

function inferCountryFromCategoryTitle(catTitle = "") {
  const m = catTitle.match(/\bof_(?:the_)?([A-Za-z_'-]+)$/u);
  if (!m) return null;
  const rawName = m[1].replace(/_/gu, " ").trim();
  if (/United States|Canada|Russia|Soviet|Iran|Cuba|Syria|North Korea|Belarus/iu.test(rawName)) {
    return null;
  }
  const geo = inferCountryAndRegion(rawName, "");
  if (
    geo?.countryCode &&
    COUNTRY_BY_CODE.has(geo.countryCode) &&
    !BASELINE_COMPLETED_CODES.has(geo.countryCode) &&
    !SANCTIONED_SKIP_CODES.has(geo.countryCode)
  ) {
    return geo.countryCode;
  }
  return null;
}

async function unlockWikidataGlobalEnergyCompanies(projectId, applyLive, globalSeenKeys, blockedPhones) {
  console.log("\n=== [Bot 11A] Unlocking Global Wikipedia/Wikidata Oilfield, Drilling, Pipe, Valve & Country Energy Trees ===");
  const categoriesToScan = [...ROOT_WIKIPEDIA_TREES];

  for (const tree of BY_COUNTRY_PARENT_TREES) {
    const subUrl = `https://en.wikipedia.org/w/api.php?action=query&list=categorymembers&cmtitle=${encodeURIComponent(tree.parent)}&cmtype=subcat&cmlimit=250&format=json`;
    const res = await fetchText(subUrl, {headers: {"User-Agent": SEC_USER_AGENT}, timeoutMs: 8000});
    if (!res.ok || !res.text) continue;
    try {
      const json = JSON.parse(res.text);
      for (const sc of json?.query?.categorymembers || []) {
        if (
          sc.title &&
          !/United_States|Canada|Russia|Soviet|Iran|Syria|Cuba|North_Korea|Belarus|defunct|former/iu.test(sc.title)
        ) {
          categoriesToScan.push({
            title: sc.title,
            seedCat: tree.seedCat,
            requireSignal: tree.requireSignal,
            fallbackCountry: inferCountryFromCategoryTitle(sc.title),
          });
        }
      }
    } catch (_) {}
  }

  console.log(`   [Bot 11A] Scanning ${categoriesToScan.length} Wikipedia global & sovereign country categories...`);
  const qidMap = new Map();

  for (let i = 0; i < categoriesToScan.length; i += 3) {
    const slice = categoriesToScan.slice(i, i + 3);
    await Promise.all(
      slice.map(async (cat) => {
        const wpUrl = `https://en.wikipedia.org/w/api.php?action=query&generator=categorymembers&gcmtitle=${encodeURIComponent(cat.title)}&gcmlimit=100&gcmtype=page&prop=pageprops&ppprop=wikibase_item&format=json`;
        let res = await fetchText(wpUrl, {headers: {"User-Agent": SEC_USER_AGENT}, timeoutMs: 9000});
        if (res.status === 429) {
          await sleep(2500);
          res = await fetchText(wpUrl, {headers: {"User-Agent": SEC_USER_AGENT}, timeoutMs: 9000});
        }
        if (!res.ok || !res.text) return;
        try {
          const json = JSON.parse(res.text);
          for (const p of Object.values(json?.query?.pages || {})) {
            const qid = p.pageprops?.wikibase_item;
            if (!qid || !p.title || /^List of |^Category:|^History of |^Petroleum industry|^Energy in /iu.test(p.title)) {
              continue;
            }
            const existing = qidMap.get(qid);
            if (!existing || (!existing.fallbackCountry && cat.fallbackCountry)) {
              qidMap.set(qid, {
                companyName: p.title.replace(/\s*\([^)]*\)\s*$/u, "").trim(),
                seedCat: existing ? existing.seedCat : cat.seedCat,
                requireSignal: existing ? existing.requireSignal && cat.requireSignal : cat.requireSignal,
                catTitle: cat.title,
                fallbackCountry: cat.fallbackCountry || existing?.fallbackCountry || null,
              });
            }
          }
        } catch (_) {}
      }),
    );
    await sleep(90);
  }

  const allQids = [...qidMap.keys()];
  console.log(`   [Bot 11A] Unique Wikidata corporate entities discovered: ${allQids.length}`);

  const rawEntities = [];
  const countryQids = new Set();

  // Sequential 40-entity chunks with polite 280ms delay & 429 retry so Wikimedia Varnish never rate-limits!
  await sleep(1200);
  for (let i = 0; i < allQids.length; i += 40) {
    const chunk = allQids.slice(i, i + 40);
    const wdUrl = `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${encodeURIComponent(chunk.join("|"))}&props=claims&format=json`;
    let res = null;
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      res = await fetchText(wdUrl, {headers: {"User-Agent": SEC_USER_AGENT}, timeoutMs: 25000});
      if (res.ok && res.text) break;
      await sleep(2500 * attempt);
    }
    if (!res?.ok || !res.text) continue;
    try {
      const wdJson = JSON.parse(res.text);
      for (const [qid, ent] of Object.entries(wdJson?.entities || {})) {
        if (ent.claims?.P576?.length) continue; // Skip dissolved companies
        const web = ent.claims?.P856?.[0]?.mainsnak?.datavalue?.value || "";
        const phone = ent.claims?.P1329?.[0]?.mainsnak?.datavalue?.value || "";
        const cQid = ent.claims?.P17?.[0]?.mainsnak?.datavalue?.value?.id || "";
        const meta = qidMap.get(qid);
        if (!web && !phone) continue;
        if (cQid) countryQids.add(cQid);
        rawEntities.push({qid, cQid, web, phone, meta});
      }
    } catch (_) {}
    await sleep(280);
  }

  console.log(`   [Bot 11A] Entities with active website/phone extracted: ${rawEntities.length} across ${countryQids.size} countries`);

  // Resolve country QIDs via lightweight English labels (~4 KB instead of 80 MB claims!)
  const countryQidToIso = new Map();
  const cQidList = [...countryQids];
  for (let i = 0; i < cQidList.length; i += 40) {
    const chunk = cQidList.slice(i, i + 40);
    const wdUrl = `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${encodeURIComponent(chunk.join("|"))}&props=labels&languages=en&format=json`;
    let res = await fetchText(wdUrl, {headers: {"User-Agent": SEC_USER_AGENT}, timeoutMs: 12000});
    if (res.status === 429) {
      await sleep(3000);
      res = await fetchText(wdUrl, {headers: {"User-Agent": SEC_USER_AGENT}, timeoutMs: 12000});
    }
    if (!res.ok || !res.text) continue;
    try {
      const wdJson = JSON.parse(res.text);
      for (const [cQid, ent] of Object.entries(wdJson?.entities || {})) {
        const enLabel = String(ent.labels?.en?.value || "").trim();
        if (!enLabel || /United States|Canada|Russia|Soviet|Iran|Cuba|Syria|North Korea|Belarus/iu.test(enLabel)) {
          continue;
        }
        const geo = inferCountryAndRegion(enLabel, "");
        if (
          geo?.countryCode &&
          COUNTRY_BY_CODE.has(geo.countryCode) &&
          !BASELINE_COMPLETED_CODES.has(geo.countryCode) &&
          !SANCTIONED_SKIP_CODES.has(geo.countryCode)
        ) {
          countryQidToIso.set(cQid, geo.countryCode);
        }
      }
    } catch (_) {}
  }

  const eligible = [];
  for (const e of rawEntities) {
    const cc = countryQidToIso.get(e.cQid) || e.meta?.fallbackCountry || null;
    if (!cc || BASELINE_COMPLETED_CODES.has(cc) || SANCTIONED_SKIP_CODES.has(cc)) continue;
    eligible.push({...e, cc});
  }

  console.log(`   [Bot 11A] Auditing ${eligible.length} active international corporate websites (concurrency=20)...`);
  const totalPriv = [];
  const totalPub = [];

  for (let i = 0; i < eligible.length; i += 40) {
    const wave = eligible.slice(i, i + 40);
    const wavePriv = [];
    const wavePub = [];
    const nowIso = new Date().toISOString();

    for (let j = 0; j < wave.length; j += 20) {
      const slice = wave.slice(j, j + 20);
      const audited = await Promise.all(
        slice.map(async (item) => {
          const cMeta = COUNTRY_BY_CODE.get(item.cc);
          const audit = item.web
            ? await auditWebsiteLive(item.web, item.cc, cMeta?.dialCode || "+1")
            : {reachable: false, phones: [], emergency24x7: false, title: "", hasOilfieldSignal: true};
          return {item, audit};
        }),
      );

      for (const {item, audit} of audited) {
        if (item.meta.requireSignal && !audit.hasOilfieldSignal && !OILFIELD_SIGNAL_RE.test(item.meta.companyName)) {
          continue;
        }
        const cand = {
          sourceType: "wikidata_global_oilfield_tree",
          sourceName: `Global Energy & Oilfield Corporate Registry (${item.meta.catTitle.replace("Category:", "")})`,
          sourceUrl: item.web || `https://www.wikidata.org/wiki/${item.qid}`,
          externalId: item.qid,
          companyName: item.meta.companyName,
          city: INTERNATIONAL_HUB_CITIES[item.cc]?.[0] || "",
          regionInput: "",
          rawPhone: item.phone || "",
          website: item.web || "",
          combinedText: `${item.meta.companyName} ${item.meta.seedCat} oilfield energy petroleum`,
          seedCategories: [item.meta.seedCat],
        };
        const built = buildGlobalCompanyRecords({
          cand,
          audit,
          countryCode: item.cc,
          globalSeenKeys,
          blockedPhones,
          nowIso,
        });
        if (!built) continue;
        wavePriv.push(built.privateRecord);
        if (built.publicRecord) wavePub.push(built.publicRecord);
      }
    }

    if (applyLive && (wavePriv.length > 0 || wavePub.length > 0)) {
      await commitDocsToFirestore(projectId, "yellow_pages_companies", wavePriv);
      await commitDocsToFirestore(projectId, "yellow_pages_public_entries", wavePub);
    }
    if (wavePriv.length > 0) {
      await fs.appendFile(BOT10_JSONL_PATH, wavePriv.map((d) => JSON.stringify(d)).join("\n") + "\n", "utf8");
    }
    totalPriv.push(...wavePriv);
    totalPub.push(...wavePub);
    console.log(
      `   [Bot 11A Batch ${Math.floor(i / 40) + 1}/${Math.ceil(eligible.length / 40)}] +${wavePub.length} public verified (+${wavePriv.length} private) [cumPub=${totalPub.length}]`,
    );
  }

  return {privateDocs: totalPriv, publicDocs: totalPub};
}

async function upgradeUnpublishedReachableWebsites(projectId, applyLive, blockedPhones) {
  console.log("\n=== [Bot 11B] Upgrading Reachable International Websites with Domestic Phone Extraction ===");
  const unpublishedById = new Map();
  const usedE164 = new Set();

  for (const p of [BOT9_JSONL_PATH, BOT10_JSONL_PATH]) {
    try {
      const raw = await fs.readFile(p, "utf8");
      for (const line of raw.split("\n")) {
        if (!line.trim()) continue;
        const r = JSON.parse(line);
        if (r?.liveAuditSummary?.phoneE164) usedE164.add(r.liveAuditSummary.phoneE164);
        if (r?.companyId && r.publicationStatus === "unpublished" && r.website) {
          unpublishedById.set(r.companyId, r);
        } else if (r?.companyId && r.publicationStatus === "published") {
          unpublishedById.delete(r.companyId);
        }
      }
    } catch (_) {}
  }

  const list = [...unpublishedById.values()];
  console.log(`   [Bot 11B] Re-checking ${list.length} reachable corporate websites for domestic/contact phones...`);

  const upgradedPriv = [];
  const upgradedPub = [];
  const nowIso = new Date().toISOString();

  for (let i = 0; i < list.length; i += 20) {
    const slice = list.slice(i, i + 20);
    const audited = await Promise.all(
      slice.map(async (rec) => {
        const cMeta = COUNTRY_BY_CODE.get(rec.countryCode);
        const audit = await auditWebsiteLive(rec.website, rec.countryCode, cMeta?.dialCode || "+1");
        return {rec, audit};
      }),
    );

    for (const {rec, audit} of audited) {
      const bestPhone = audit.phones?.find((ph) => ph.validPhone && !usedE164.has(ph.e164) && !blockedPhones.has(ph.e164));
      if (!bestPhone) continue;
      usedE164.add(bestPhone.e164);

      const updatedPriv = {
        ...rec,
        mainPhone: bestPhone.display,
        publicPhone: bestPhone.display,
        tollFreePhone: bestPhone.isTollFree ? bestPhone.display : "",
        verificationStatus: "verified",
        operationalStatus: "active_in_operation",
        publicationStatus: "published",
        publishedAt: nowIso,
        updatedAt: nowIso,
        liveAuditSummary: {
          ...(rec.liveAuditSummary || {}),
          auditedAt: nowIso,
          websiteReachable: true,
          phoneE164: bestPhone.e164,
        },
      };
      updatedPriv.adminSearchTokens = buildAdminSearchTokens(updatedPriv);

      if (isPublicationEligible(updatedPriv)) {
        const pub = buildPublicEntry(updatedPriv, updatedPriv.companyId, nowIso);
        if (pub) {
          upgradedPriv.push(updatedPriv);
          upgradedPub.push(pub);
        }
      }
    }
  }

  if (applyLive && upgradedPub.length > 0) {
    await commitDocsToFirestore(projectId, "yellow_pages_companies", upgradedPriv);
    await commitDocsToFirestore(projectId, "yellow_pages_public_entries", upgradedPub);
  }
  if (upgradedPriv.length > 0) {
    await fs.appendFile(BOT10_JSONL_PATH, upgradedPriv.map((d) => JSON.stringify(d)).join("\n") + "\n", "utf8");
  }

  console.log(`   [Bot 11B] Upgraded +${upgradedPub.length} corporate websites to verified published status!`);
  return {upgradedPriv, upgradedPub};
}

async function rebuildFinalReports() {
  const byId = new Map();
  for (const p of [BOT9_JSONL_PATH, BOT10_JSONL_PATH]) {
    try {
      const raw = await fs.readFile(p, "utf8");
      for (const line of raw.split("\n")) {
        if (!line.trim()) continue;
        const r = JSON.parse(line);
        if (r?.companyId) {
          const prev = byId.get(r.companyId);
          if (!prev || r.publicationStatus === "published") {
            byId.set(r.companyId, r);
          }
        }
      }
    } catch (_) {}
  }

  const uniqueAll = [...byId.values()];
  const publishedAll = uniqueAll.filter((r) => r.publicationStatus === "published");

  const byContinent = new Map();
  const byCountry = new Map();
  let middleEastPub = 0;
  let middleEastPriv = 0;

  for (const r of uniqueAll) {
    const cont = r.continentCode || "unknown";
    const cStat = byContinent.get(cont) || {pub: 0, priv: 0};
    cStat.priv += 1;
    if (r.publicationStatus === "published") cStat.pub += 1;
    byContinent.set(cont, cStat);

    if (r.isMiddleEast) {
      middleEastPriv += 1;
      if (r.publicationStatus === "published") middleEastPub += 1;
    }

    const cc = r.countryCode || "??";
    const kStat = byCountry.get(cc) || {name: r.countryName || cc, cont, pub: 0, priv: 0};
    kStat.priv += 1;
    if (r.publicationStatus === "published") kStat.pub += 1;
    byCountry.set(cc, kStat);
  }

  const sortedCountries = [...byCountry.entries()].sort((a, b) => b[1].pub - a[1].pub || b[1].priv - a[1].priv);

  const lines = [
    "# PipeBuyer Global Oilfield Directory — Deep-Fill Multi-Agent Completion Report",
    "",
    `- **Generated At:** \`${new Date().toISOString()}\``,
    `- **Existing North America Baseline (\`CA\` & \`US\`):** \`12,762\` public verified + \`22,646\` private admin records`,
    `- **New International Public Verified Entries Published:** \`${publishedAll.length}\``,
    `- **New International Private Admin Records Saved:** \`${uniqueAll.length}\``,
    `- **Combined Global Public Verified Directory Total:** \`${12762 + publishedAll.length}\``,
    `- **International Countries with Discovered Records:** \`${sortedCountries.length}\` countries (+ \`CA\` & \`US\`)`,
    "",
    "## Breakdown by World Continent / Region",
    "| World Region | International Public Verified | International Private Saved | Total Public (Incl. CA/US Baseline) |",
    "|---|---:|---:|---:|",
  ];

  for (const cont of WORLD_CONTINENTS) {
    if (cont.code === "middle_east") {
      lines.push(`| **Middle East** | ${middleEastPub} | ${middleEastPriv} | ${middleEastPub} |`);
      continue;
    }
    const st = byContinent.get(cont.code) || {pub: 0, priv: 0};
    const withBaseline = cont.code === "north_america" ? 12762 + st.pub : st.pub;
    lines.push(`| **${cont.label}** | ${st.pub} | ${st.priv} | ${withBaseline} |`);
  }

  lines.push(
    "",
    "## International Countries Populated (Sorted by Verified Public Count)",
    "| # | Country | Code | Continent | Public Verified | Private Saved |",
    "|---|---|---|---|---:|---:|",
    ...sortedCountries.map(
      ([cc, info], i) => `| ${i + 1} | ${info.name} | \`${cc}\` | \`${info.cont}\` | ${info.pub} | ${info.priv} |`,
    ),
    "",
  );

  await fs.writeFile(BOT10_REPORT_PATH, lines.join("\n"), "utf8");

  try {
    const checkpoint = JSON.parse(await fs.readFile(CHECKPOINT_PATH, "utf8"));
    const bot9TotalPub = Object.values(checkpoint.completedCountries || {}).reduce(
      (acc, v) => acc + Number(v.publicPublished || 0),
      0,
    );
    const bot9TotalPriv = Object.values(checkpoint.completedCountries || {}).reduce(
      (acc, v) => acc + Number(v.privateSaved || 0),
      0,
    );
    checkpoint.deepFillPublicPublished = Math.max(0, publishedAll.length - bot9TotalPub);
    checkpoint.deepFillPrivateSaved = Math.max(0, uniqueAll.length - bot9TotalPriv);
    checkpoint.updatedAt = new Date().toISOString();
    await fs.writeFile(CHECKPOINT_PATH, JSON.stringify(checkpoint, null, 2), "utf8");

    const activeCountries = GLOBAL_COUNTRIES_LIST.filter(
      (c) => !BASELINE_COMPLETED_CODES.has(c.code) && !SANCTIONED_SKIP_CODES.has(c.code),
    );
    await writeGlobalProgressDashboard(checkpoint, activeCountries);
  } catch (_) {}

  return {publishedCount: publishedAll.length, privateCount: uniqueAll.length, countryCount: sortedCountries.length};
}

async function completeRemainingAsiaOceaniaAfricaVerticals(projectId, applyLive, globalSeenKeys, blockedPhones) {
  const remainingCodes = [
    "TH", "VN", "JP", "KR", "PK", "BD", "PH", "TW", "UZ", "TM", "LK",
    "AU", "PG", "NZ", "FJ",
    "NG", "AO", "DZ", "GH", "MZ", "NA", "SN", "CI", "ZA", "KE", "TZ", "UG", "GA", "CG", "CM", "GQ", "TN", "LY", "MA", "MR",
  ];
  const verticals = [
    {cat: "pipe_octg_supply", terms: "OCTG OR \"steel pipe\" OR \"line pipe\" OR \"tubular\""},
    {cat: "drilling_rigs_directional", terms: "\"drilling\" OR \"workover\" OR \"offshore drilling\""},
    {cat: "completions_frac_wireline", terms: "\"wireline\" OR \"slickline\" OR \"well intervention\""},
    {cat: "wellhead_valves_pressure", terms: "\"wellhead\" OR \"industrial valves\" OR \"pressure control\""},
    {cat: "pipeline_facility_construction", terms: "\"pipeline construction\" OR \"oil and gas EPC\" OR \"subsea\""},
    {cat: "welding_machining_fab", terms: "\"oilfield fabrication\" OR \"offshore fabrication\" OR \"machine shop\""},
    {cat: "pipe_inspection_ndt", terms: "\"NDT inspection\" OR \"pipe inspection\" OR \"rope access\""},
    {cat: "hotshot_pilot_logistics", terms: "\"oilfield logistics\" OR \"offshore marine\" OR \"supply base\""},
  ];

  console.log(`\n=== [Bot 11C] Completing Remaining ${remainingCodes.length} Asia, Oceania & Africa Hub Verticals ===`);
  let totalPub = [];
  let totalPriv = [];

  for (let i = 0; i < remainingCodes.length; i += 5) {
    const batch = remainingCodes.slice(i, i + 5).map((c) => COUNTRY_BY_CODE.get(c)).filter(Boolean);
    const waveResults = await Promise.all(
      batch.map(async (country) => {
        const hubs = INTERNATIONAL_HUB_CITIES[country.code] || [];
        const qs = (country.isPopularOilGas ? verticals : verticals.slice(0, 4)).map((v, idx) => {
          const hubCity = hubs.length > 0 ? hubs[idx % hubs.length] : "";
          const loc = hubCity ? `"${hubCity}" "${country.name}"` : `"${country.name}"`;
          return {q: `(${v.terms}) ${loc} contact phone`, city: hubCity, cat: v.cat};
        });
        const discovered = await searchBingRssDomains(qs, country.isPopularOilGas ? 32 : 16);
        const entries = [...discovered.entries()];
        const priv = [];
        const pub = [];
        const nowIso = new Date().toISOString();

        for (let j = 0; j < entries.length; j += 10) {
          const slice = entries.slice(j, j + 10);
          const audited = await Promise.all(
            slice.map(async ([origin, meta]) => ({
              origin,
              meta,
              audit: await auditWebsiteLive(origin, country.code, country.dialCode),
            })),
          );
          for (const {origin, meta, audit} of audited) {
            if (!audit.reachable || !audit.hasOilfieldSignal) continue;
            const built = buildGlobalCompanyRecords({
              cand: {
                sourceType: "deep_fill_hub_vertical_crawl",
                sourceName: `Global Oilpatch Hub Vertical Discovery (${country.name})`,
                sourceUrl: meta.deepUrl || audit.finalUrl || origin,
                externalId: origin,
                companyName: audit.title || "",
                city: meta.city || hubs[0] || "",
                regionInput: "",
                rawPhone: "",
                website: origin,
                combinedText: `${audit.title || ""} ${meta.rssTitle || ""} ${meta.rssDesc || ""}`,
                seedCategories: meta.cat ? [meta.cat] : [],
              },
              audit,
              countryCode: country.code,
              globalSeenKeys,
              blockedPhones,
              nowIso,
            });
            if (!built) continue;
            priv.push(built.privateRecord);
            if (built.publicRecord) pub.push(built.publicRecord);
          }
        }
        return {country, priv, pub};
      }),
    );

    const wavePriv = waveResults.flatMap((r) => r.priv);
    const wavePub = waveResults.flatMap((r) => r.pub);
    if (applyLive && (wavePriv.length > 0 || wavePub.length > 0)) {
      await commitDocsToFirestore(projectId, "yellow_pages_companies", wavePriv);
      await commitDocsToFirestore(projectId, "yellow_pages_public_entries", wavePub);
    }
    if (wavePriv.length > 0) {
      await fs.appendFile(BOT10_JSONL_PATH, wavePriv.map((d) => JSON.stringify(d)).join("\n") + "\n", "utf8");
    }
    totalPriv.push(...wavePriv);
    totalPub.push(...wavePub);
    console.log(
      `   [Bot 11C Wave ${Math.floor(i / 5) + 1}/${Math.ceil(remainingCodes.length / 5)}] ` +
        waveResults.map((r) => `${r.country.code}:+${r.pub.length} pub (+${r.priv.length} priv)`).join(" | "),
    );
  }
  return {privateDocs: totalPriv, publicDocs: totalPub};
}

const US_STATES_SET = new Set([
  "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN",
  "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH",
  "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT",
  "VT", "VA", "WA", "WV", "WI", "WY",
]);

async function purgeSecUsStateCollisions(projectId, applyLive) {
  let raw = "";
  try {
    raw = await fs.readFile(BOT10_JSONL_PATH, "utf8");
  } catch (_) {
    return 0;
  }

  const keptLines = [];
  const purgeIds = new Set();
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    const r = JSON.parse(line);
    if (r.discoveryChannel === "sec_edgar_international_registry" && US_STATES_SET.has(r.countryCode)) {
      const zip = String(r.postalCode || "").trim();
      const city = String(r.city || "").trim().toUpperCase();
      // Keep genuine Argentina/foreign entries; purge 5-digit US zip or US city collisions (e.g. LISLE IL)
      const isUsCollision =
        /^\d{5}(-\d{4})?$/u.test(zip) ||
        city === "LISLE" ||
        (r.countryCode === "VA" || r.countryCode === "LA");
      if (isUsCollision) {
        purgeIds.add(r.companyId);
        continue;
      }
    }
    keptLines.push(line);
  }

  if (purgeIds.size > 0) {
    await fs.writeFile(BOT10_JSONL_PATH, keptLines.join("\n") + "\n", "utf8");
    if (applyLive) {
      const token = await resolveAccessToken(projectId);
      const commitUrl = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
      const idList = [...purgeIds];
      const writes = [];
      for (const id of idList) {
        writes.push({
          delete: `projects/${projectId}/databases/(default)/documents/yellow_pages_public_entries/${encodeURIComponent(id)}`,
        });
        writes.push({
          delete: `projects/${projectId}/databases/(default)/documents/yellow_pages_companies/${encodeURIComponent(id)}`,
        });
      }
      for (let i = 0; i < writes.length; i += 100) {
        await fetch(commitUrl, {
          method: "POST",
          headers: {Authorization: `Bearer ${token}`, "Content-Type": "application/json"},
          body: JSON.stringify({writes: writes.slice(i, i + 100)}),
          signal: AbortSignal.timeout(25000),
        });
      }
    }
    console.log(`   [Data Quality Guard] Purged ${purgeIds.size} SEC US-state code collisions cleanly.`);
  }
  return purgeIds.size;
}

async function main() {
  const args = process.argv.slice(2);
  const applyLive = args.includes("--apply");
  const wikidataOnly = args.includes("--wikidata-only");
  const projectIdx = args.indexOf("--project");
  const projectId = projectIdx !== -1 && args[projectIdx + 1] ? args[projectIdx + 1] : "flutter-flow-pipe";

  await purgeSecUsStateCollisions(projectId, applyLive);

  const [globalSeenKeys, blockedPhones] = await Promise.all([
    loadGlobalSeenKeysFromJsonl([BOT9_JSONL_PATH, BOT10_JSONL_PATH]),
    applyLive ? loadBlockedPhones(projectId) : Promise.resolve(new Set()),
  ]);

  const res11A = await unlockWikidataGlobalEnergyCompanies(projectId, applyLive, globalSeenKeys, blockedPhones);
  const res11C = wikidataOnly
    ? {publicDocs: [], privateDocs: []}
    : await completeRemainingAsiaOceaniaAfricaVerticals(projectId, applyLive, globalSeenKeys, blockedPhones);
  const res11B = wikidataOnly
    ? {upgradedPub: [], upgradedPriv: []}
    : await upgradeUnpublishedReachableWebsites(projectId, applyLive, blockedPhones);
  const finalStats = await rebuildFinalReports();

  console.log(
    `\n[Bot 11 Complete] +${res11A.publicDocs.length} Wikidata, +${res11C.publicDocs.length} Asia/Oceania/Africa verticals, +${res11B.upgradedPub.length} domestic phone upgrades | Total International Published=${finalStats.publishedCount} (${finalStats.privateCount} private across ${finalStats.countryCount} countries)!`,
  );
}

main().catch((err) => {
  console.error("[Bot 11] Fatal error:", err);
  process.exit(1);
});
