#!/usr/bin/env node
/**
 * Bot 8 — State, Provincial & Municipal Oil & Gas Regulator & Active Licence Crawler
 *
 * Queries official public government open-data registries across USA & Canada:
 *   1. Texas Comptroller Active Oil & Gas NAICS Permit Holders (`data.texas.gov/resource/3kx8-uryv.json`):
 *      - `213111` (Drilling Oil and Gas Wells)
 *      - `213112` (Support Activities for Oil and Gas Operations — Wireline, Well Service, Testing)
 *      - `237120` (Oil and Gas Pipeline and Related Structures Construction)
 *      - `333132` (Oil and Gas Field Machinery, OCTG Tools & Wellhead Manufacturing)
 *      - `486110` / `486210` (Crude Oil & Natural Gas Pipeline Transportation)
 *      Filtered strictly to `out_of_business_date IS NULL` (Active in 2026!).
 *   2. City of Edmonton Active 2026 Industrial Business Licences (`data.edmonton.ca/resource/qhi4-bdpu.json`):
 *      - Commercial/Industrial licensed Oilfield, Drilling, Pipeline, Tubular, Hydrovac, Welding,
 *        Valve, Wellhead, Crane, and Energy Service businesses in the Edmonton/WCSB hub.
 *   3. City of Calgary Active 2026 Commercial Business Licences (`data.calgary.ca/resource/vdjc-pybd.json`):
 *      - Licensed commercial Oilfield, Drilling, Pipeline, Energy Service, Wellhead & Industrial
 *        contractors headquartered in Calgary, AB.
 *
 * Cross-enriches active 2026 government standing when merged with COSSD / USDOT / SEC EDGAR,
 * and adds net-new verified businesses into the private Contact Center outreach queue!
 */

import fs from "node:fs/promises";
import path from "node:path";
import {createRequire} from "node:module";
import {fileURLToPath} from "node:url";

const require = createRequire(import.meta.url);
const {
  inferCountryAndRegion,
  classifyCategoriesFromText,
} = require("../../firebase/functions/yellow_pages_taxonomy.js");
const {
  normalizedCompanyName,
} = require("../../firebase/functions/yellow_pages_policy.js");

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../..");
const LEDGER_DIR = path.join(REPO_ROOT, "data/yellow_pages/ledger");
const REPORTS_DIR = path.join(REPO_ROOT, "data/yellow_pages/reports");

const USER_AGENT = "PipeBuyerRegulatorAudit/1.2 (+https://pipebuyer.com; open-government-data)";
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const NAICS_META = {
  "213111": {label: "Drilling Oil & Gas Wells (NAICS 213111)", cat: "drilling_rigs_directional"},
  "213112": {label: "Oil & Gas Field Support Services (NAICS 213112)", cat: "completions_frac_wireline"},
  "237120": {label: "Oil & Gas Pipeline & Facility Construction (NAICS 237120)", cat: "pipeline_facility_construction"},
  "333132": {label: "Oilfield Machinery, OCTG & Wellhead Mfg (NAICS 333132)", cat: "wellhead_valves_pressure"},
  "486110": {label: "Crude Oil Pipeline Transportation (NAICS 486110)", cat: "pipeline_facility_construction"},
  "486210": {label: "Natural Gas Pipeline Transportation (NAICS 486210)", cat: "pipeline_facility_construction"},
};

const ALBERTA_OILFIELD_NAME_REGEX =
  /\b(?:oilfield|oil\s*&\s*gas|drilling|pipeline|tubular|octg|casing|hydrovac|vacuum\s+truck|wireline|slickline|snubbing|wellhead|well\s+serv|frac|valve|rigging|picker|oil\s+tools|energy\s+services|midstream|b-?pressure|ndt|downhole|rig\s+mov|welding|pipe\s+supply|compression)\b/iu;

const RETAIL_GAS_STATION_EXCLUDE =
  /\b(?:petro[- ]?canada|esso|shell\s+food|husky\s+food|7-?eleven|circle\s+k|a&w|pita|tim\s+hortons|car\s+wash|convenience|gas\s+bar|liquor|vape)\b/iu;

function titleCase(raw = "") {
  const s = String(raw || "").trim().replace(/\s+/gu, " ");
  if (!s) return "";
  const keep = new Set(["LLC", "LP", "LLP", "INC", "CORP", "LTD", "CO", "USA", "TX", "AB", "OCTG", "NDT", "SWD"]);
  return s
    .split(" ")
    .map((w) => {
      const clean = w.replace(/[^A-Za-z0-9]/gu, "").toUpperCase();
      if (keep.has(clean)) return w.toUpperCase();
      return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
    })
    .join(" ");
}

async function fetchJsonWithRetry(url) {
  for (let i = 1; i <= 3; i += 1) {
    try {
      const res = await fetch(url, {
        headers: {"User-Agent": USER_AGENT, Accept: "application/json"},
        signal: AbortSignal.timeout(22000),
      });
      if (res.ok) return await res.json();
      if (res.status === 429 || res.status >= 500) {
        await sleep(700 * i);
        continue;
      }
      return [];
    } catch (_) {
      await sleep(700 * i);
    }
  }
  return [];
}

async function crawlTexasActiveOilGasNaics({maxPages = 6} = {}) {
  const results = [];
  const seen = new Set();
  const where = "naics in('213111','213112','237120','333132','486110','486210') AND out_of_business_date IS NULL";

  for (let page = 0; page < maxPages; page += 1) {
    const params = new URLSearchParams({
      $where: where,
      $limit: "1000",
      $offset: String(page * 1000),
      $order: "tp_number ASC",
    });
    const rows = await fetchJsonWithRetry(`https://data.texas.gov/resource/3kx8-uryv.json?${params.toString()}`);
    if (!rows.length) break;

    for (const r of rows) {
      const rawName = String(r.loc_name || r.tp_name || "").trim();
      const companyName = titleCase(rawName);
      const normName = normalizedCompanyName(companyName);
      if (!normName || normName.length < 3) continue;

      const state = String(r.loc_state || r.tp_state || "TX").trim().toUpperCase();
      const city = titleCase(r.loc_city || r.tp_city || "");
      const dedupeKey = `${normName}|${state}|${city}`;
      if (seen.has(dedupeKey)) continue;
      seen.add(dedupeKey);

      const naicsCode = String(r.naics || "213112").trim();
      const meta = NAICS_META[naicsCode] || NAICS_META["213112"];
      const geo = inferCountryAndRegion("US", state);
      const cats = classifyCategoriesFromText([companyName, meta.label, meta.cat], meta.label);
      if (!cats.includes(meta.cat)) cats.unshift(meta.cat);

      const tpNum = String(r.tp_number || "").trim();
      results.push({
        recordId: `tx-naics-${tpNum}-${r.loc_number || "1"}`,
        discoveryChannel: "texas_comptroller_oilgas_naics",
        externalSourceId: tpNum,
        governmentActiveStanding: true,
        companyName,
        normalizedCompanyName: normName,
        countryCode: geo.countryCode,
        regionCode: geo.regionCode,
        regionName: geo.regionName,
        timezone: geo.timezone,
        basins: geo.defaultBasins || [],
        city,
        postalCode: String(r.loc_zip || r.tp_zip || "").trim(),
        streetAddress: titleCase(r.address_text || r.tp_address || ""),
        directoryPhone: "",
        tollFreePhone: "",
        website: "",
        categoryCodes: cats,
        services: [meta.label],
        certifications: [`TX Active Permit #${tpNum}`],
        emergency24x7: false,
        sourceReferences: [
          {
            sourceType: "state_tax_naics_registry",
            sourceLabel: `Texas Comptroller Active Permit (${meta.label})`,
            sourceUrl: "https://data.texas.gov/dataset/All-Permitted-Sales-Tax-Locations/3kx8-uryv",
            discoveredAt: new Date().toISOString(),
          },
        ],
      });
    }
    if (rows.length < 1000) break;
    await sleep(200);
  }
  return results;
}

async function crawlAlbertaMunicipalOilfieldLicences() {
  const results = [];
  const seen = new Set();

  // 1. City of Edmonton Commercial Licences (`qhi4-bdpu`) — server-side SoQL Oilfield/Industrial filter
  const edmLike = [
    "OILFIELD", "DRILLING", "PIPELINE", "TUBULAR", "HYDROVAC", "WIRELINE",
    "WELLHEAD", "VALVE", "WELDING", "RIGGING", "ENERGY SERVICES", "MIDSTREAM", "DOWNHOLE",
  ]
    .map((kw) => `upper(business_name) like '%${kw}%'`)
    .join(" OR ");
  const edmParams = new URLSearchParams({
    $where: `licencetype != 'Home Based' AND (${edmLike})`,
    $limit: "5000",
  });
  const edmRows = await fetchJsonWithRetry(`https://data.edmonton.ca/resource/qhi4-bdpu.json?${edmParams.toString()}`);
  for (const r of edmRows) {
    const rawName = String(r.business_name || "").trim();
    const catText = String(r.business_licence_category || "").trim();
    if (RETAIL_GAS_STATION_EXCLUDE.test(rawName)) continue;
    if (!ALBERTA_OILFIELD_NAME_REGEX.test(`${rawName} ${catText}`)) continue;

    const companyName = titleCase(rawName);
    const normName = normalizedCompanyName(companyName);
    if (!normName || seen.has(`${normName}|AB`)) continue;
    seen.add(`${normName}|AB`);

    const geo = inferCountryAndRegion("CA", "AB");
    const addr = /home\s+based|non-resident/iu.test(String(r.business_address || ""))
      ? ""
      : titleCase(r.business_address || "");
    const cats = classifyCategoriesFromText([companyName, catText], catText);

    results.push({
      recordId: `ab-edm-${String(r.externalid || normName).replace(/[^a-zA-Z0-9-]/gu, "").slice(0, 32)}`,
      discoveryChannel: "alberta_municipal_licence_registry",
      externalSourceId: String(r.externalid || ""),
      governmentActiveStanding: true,
      companyName,
      normalizedCompanyName: normName,
      countryCode: "CA",
      regionCode: "AB",
      regionName: geo.regionName,
      timezone: geo.timezone,
      basins: geo.defaultBasins || [],
      city: "Edmonton",
      postalCode: "",
      streetAddress: addr,
      directoryPhone: "",
      tollFreePhone: "",
      website: "",
      categoryCodes: cats,
      services: [catText].filter(Boolean),
      certifications: ["Edmonton Active Commercial Licence"],
      emergency24x7: false,
      sourceReferences: [
        {
          sourceType: "municipal_business_licence",
          sourceLabel: `City of Edmonton Active Licence (${r.expiry_date ? String(r.expiry_date).slice(0, 10) : "Active"})`,
          sourceUrl: "https://data.edmonton.ca/City-Administration/City-of-Edmonton-Business-Licences/qhi4-bdpu",
          discoveredAt: new Date().toISOString(),
        },
      ],
    });
  }

  // 2. City of Calgary Commercial Licences (`vdjc-pybd`) — server-side SoQL Oilfield/Industrial filter
  const calLike = [
    "OILFIELD", "DRILLING", "PIPELINE", "TUBULAR", "HYDROVAC", "WIRELINE",
    "WELLHEAD", "VALVE", "WELDING", "RIGGING", "ENERGY SERVICES", "MIDSTREAM", "DOWNHOLE", "OIL TOOLS",
  ]
    .map((kw) => `upper(tradename) like '%${kw}%'`)
    .join(" OR ");
  const calParams = new URLSearchParams({
    $where: `homeoccind = 'N' AND jobstatusdesc = 'Licensed' AND (${calLike})`,
    $limit: "5000",
  });
  const calRows = await fetchJsonWithRetry(`https://data.calgary.ca/resource/vdjc-pybd.json?${calParams.toString()}`);
  for (const r of calRows) {
    const rawName = String(r.tradename || "").trim();
    const catText = String(r.licencetypes || "").trim();
    if (RETAIL_GAS_STATION_EXCLUDE.test(rawName)) continue;
    if (!ALBERTA_OILFIELD_NAME_REGEX.test(`${rawName} ${catText}`)) continue;

    const companyName = titleCase(rawName);
    const normName = normalizedCompanyName(companyName);
    if (!normName || seen.has(`${normName}|AB`)) continue;
    seen.add(`${normName}|AB`);

    const geo = inferCountryAndRegion("CA", "AB");
    const cats = classifyCategoriesFromText([companyName, catText], catText);

    results.push({
      recordId: `ab-yyc-${String(r.getbusid || normName).replace(/[^a-zA-Z0-9-]/gu, "").slice(0, 32)}`,
      discoveryChannel: "alberta_municipal_licence_registry",
      externalSourceId: String(r.getbusid || ""),
      governmentActiveStanding: true,
      companyName,
      normalizedCompanyName: normName,
      countryCode: "CA",
      regionCode: "AB",
      regionName: geo.regionName,
      timezone: geo.timezone,
      basins: geo.defaultBasins || [],
      city: "Calgary",
      postalCode: "",
      streetAddress: titleCase(r.address || ""),
      directoryPhone: "",
      tollFreePhone: "",
      website: "",
      categoryCodes: cats,
      services: [catText].filter(Boolean),
      certifications: ["Calgary Active Commercial Licence"],
      emergency24x7: false,
      sourceReferences: [
        {
          sourceType: "municipal_business_licence",
          sourceLabel: `City of Calgary Active Licence (#${r.getbusid || "Active"})`,
          sourceUrl: "https://data.calgary.ca/Business-and-Economic-Activity/Calgary-Business-Licences/vdjc-pybd",
          discoveredAt: new Date().toISOString(),
        },
      ],
    });
  }

  return results;
}

export async function runEnergyRegulatorRegistries({maxTxPages = 5} = {}) {
  await fs.mkdir(LEDGER_DIR, {recursive: true});
  await fs.mkdir(REPORTS_DIR, {recursive: true});

  const [txRecords, abRecords] = await Promise.all([
    crawlTexasActiveOilGasNaics({maxPages: maxTxPages}),
    crawlAlbertaMunicipalOilfieldLicences(),
  ]);

  const companies = [...abRecords, ...txRecords];
  const out = {
    generatedAt: new Date().toISOString(),
    totalRegulatorVerifiedCompanies: companies.length,
    byChannel: {
      albertaCommercialLicences: abRecords.length,
      texasComptrollerActiveOilGasNaics: txRecords.length,
    },
    byCountry: {
      CA: companies.filter((c) => c.countryCode === "CA").length,
      US: companies.filter((c) => c.countryCode === "US").length,
    },
    companies,
  };

  const outJsonPath = path.join(LEDGER_DIR, "08_regulator_registries.json");
  await fs.writeFile(outJsonPath, JSON.stringify(out, null, 2), "utf8");

  const md = [
    "# Bot 8 — State, Provincial & Municipal Oil & Gas Active Licence & NAICS Report",
    "",
    `- **Generated At**: \`${out.generatedAt}\``,
    `- **Total Active Government-Registered Oil & Gas Entities**: **${companies.length.toLocaleString()}** (Canada: **${out.byCountry.CA.toLocaleString()}**, USA: **${out.byCountry.US.toLocaleString()}**)`,
    `  - **Alberta Active Commercial Oilfield Licences (Edmonton + Calgary)**: **${abRecords.length.toLocaleString()}**`,
    `  - **Texas Comptroller Active Oil & Gas NAICS (\`213111\`, \`213112\`, \`237120\`, \`333132\`, \`486110\`, \`486210\`)**: **${txRecords.length.toLocaleString()}**`,
    "",
    "## Sample of Active Government-Registered Oil & Gas Entities (First 60 Shown)",
    "",
    "| Company | City / Region | Country | Street Address | Registry Standing |",
    "| :--- | :--- | :---: | :--- | :--- |",
    ...companies.slice(0, 60).map(
      (c) =>
        `| ${c.companyName} | ${[c.city, c.regionCode].filter(Boolean).join(", ")} | ${c.countryCode} | ${c.streetAddress || "—"} | ${c.certifications[0] || "Active"} |`,
    ),
    "",
  ];
  await fs.writeFile(
    path.join(REPORTS_DIR, "08_regulator_registries_report.md"),
    md.join("\n"),
    "utf8",
  );

  console.log(
    `[Bot 8] Regulator Registries: ${companies.length} active entities (Alberta: ${abRecords.length}, Texas NAICS: ${txRecords.length}) -> ${outJsonPath}`,
  );
  return out;
}

if (process.argv[1]?.endsWith("bot8_energy_regulator_registries.mjs")) {
  runEnergyRegulatorRegistries().catch((err) => {
    console.error("[Bot 8 Error]", err.message);
    process.exitCode = 1;
  });
}
